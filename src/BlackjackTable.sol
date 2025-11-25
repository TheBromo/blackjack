// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./RNGCoordinator.sol";
import "./BankTreasury.sol";

/**
 * @title Blackjack
 * @notice On-chain blackjack game with commit-reveal randomness
 *         Max 5 players, standard blackjack rules
 */
contract Blackjack {
    CommitRevealRandom public immutable crRandom;
    BankTreasury public immutable bank;

    uint8 public constant MAX_PLAYERS = 5;
    uint256 public constant FEE_PERCENT = 5; // 5%
    uint256 public constant MIN_BET = 0.01 ether;
    uint256 public constant MAX_BET = 10 ether;

    enum GameState {
        BETTING,
        COMMITTED,
        DEALING,
        PLAYING,
        DEALER_TURN,
        RESOLVED
    }

    enum PlayerStatus {
        NONE,
        ACTIVE,
        STANDING,
        BUSTED,
        BLACKJACK
    }

    struct Card {
        uint8 value; // 1-13 (A, 2-10, J, Q, K)
        uint8 suit; // 0-3
    }

    struct Hand {
        Card[] cards;
        uint8 total;
        bool hasUsableAce;
    }

    struct PlayerState {
        address addr;
        uint256 bet;
        Hand hand;
        PlayerStatus status;
    }

    struct Game {
        uint256 rngRoundId;
        GameState state;
        PlayerState[] players;
        Hand dealerHand;
        uint256 cardCounter;
        uint8 currentPlayerIndex;
        mapping(address => bool) isPlayer;
    }

    mapping(uint256 => Game) public games;
    uint256 public currentGameId;
    address public house;

    event GameStarted(uint256 indexed gameId);
    event PlayerJoined(
        uint256 indexed gameId,
        address indexed player,
        uint256 bet
    );
    event CommitCountdownStart(uint256 indexed gameId);
    event CardDealt(
        uint256 indexed gameId,
        address indexed player,
        uint8 value,
        uint8 suit
    );
    event DealerCardDealt(
        uint256 indexed gameId,
        uint8 value,
        uint8 suit,
        bool hidden
    );
    event PlayerAction(
        uint256 indexed gameId,
        address indexed player,
        string action
    );
    event GameResolved(
        uint256 indexed gameId,
        address indexed player,
        bool won,
        uint256 payout
    );

    error OnlyHouse();
    error InvalidGameState();
    error GameFull();
    error InvalidBet();
    error AlreadyJoined();
    error NotYourTurn();
    error InvalidAction();
    error NoPlayers();

    modifier onlyHouse() {
        if (msg.sender != house) revert OnlyHouse();
        _;
    }

    modifier inState(GameState _state, uint256 _gameId) {
        require(games[_gameId].state == _state, "Invalid phase");
        _;
    }

    constructor(BankTreasury _bank, CommitRevealRandom _rng) {
        house = msg.sender;
        bank = _bank;
        crRandom = _rng;
        currentGameId = 0;
    }

    // ============================================================
    //  GAME SETUP
    // ============================================================

    function startGame() external onlyHouse returns (uint256 gameId) {
        //setup game
        gameId = ++currentGameId;
        games[gameId].state = GameState.BETTING;
        Game storage game = games[gameId];

        //setup up random gen
        game.rngRoundId = 0;
        crRandom.start(60, 60);

        emit GameStarted(gameId);
    }

    function joinGame(
        uint256 gameId,
        bytes32 playerHash
    ) external payable inState(GameState.BETTING, gameId) {
        Game storage game = games[gameId];

        if (game.players.length >= MAX_PLAYERS) revert GameFull();
        if (msg.value < MIN_BET || msg.value > MAX_BET) revert InvalidBet();
        if (game.isPlayer[msg.sender]) revert AlreadyJoined();

        //pay fee
        uint256 fee = (msg.value * FEE_PERCENT) / 100;
        uint256 betAmount = msg.value - fee;
        bank.lockExposure(betAmount);
        bank.depositFee{value: fee}();

        game.players.push();
        uint256 idx = game.players.length - 1;

        game.players[idx].addr = msg.sender;
        game.players[idx].bet = betAmount;
        game.players[idx].status = PlayerStatus.ACTIVE;
        game.isPlayer[msg.sender] = true;
        //add commit
        crRandom.commit(playerHash);

        emit PlayerJoined(gameId, msg.sender, msg.value);
    }

    function commitPlayer(
        uint256 gameId,
        bytes32 playerSecret
    ) external payable inState(GameState.COMMITTED, gameId) {
        Game storage game = games[gameId];
        if (game.state != GameState.COMMITTED) revert InvalidGameState();
        if (game.players.length == 0) revert NoPlayers();
    }

    // ============================================================
    //  RNG COMMIT & DEAL
    // ============================================================

    function commitAndStart(
        uint256 gameId,
        bytes32 dealerHash
    ) external onlyHouse inState(GameState.BETTING, gameId) {
        Game storage game = games[gameId];
        if (game.state != GameState.BETTING) revert InvalidGameState();
        if (game.players.length == 0) revert NoPlayers();

        game.state = GameState.COMMITTED;
        crRandom.commit(dealerHash);
        emit CommitCountdownStart(gameId);
    }

    function revealAndDeal(
        uint256 gameId,
        bytes32 dealerSecret
    ) external onlyHouse inState(GameState.COMMITTED, gameId) {
        Game storage game = games[gameId];
        if (game.state != GameState.COMMITTED) revert InvalidGameState();

        // Reveal to finalize entropy
        crRandom.reveal(gameId, dealerSecret);

        game.state = GameState.DEALING;

        // Deal 2 cards to each player
        for (uint256 i = 0; i < game.players.length; i++) {
            _dealCardToPlayer(gameId, i);
            _dealCardToPlayer(gameId, i);

            // Check for natural blackjack
            if (game.players[i].hand.total == 21) {
                game.players[i].status = PlayerStatus.BLACKJACK;
            }
        }

        // Deal 2 cards to dealer
        _dealCardToDealer(gameId, false); // visible
        _dealCardToDealer(gameId, true); // hidden initially

        game.state = GameState.PLAYING;
        _advanceToNextActivePlayer(gameId);
    }

    // ============================================================
    //  PLAYER ACTIONS
    // ============================================================

    function hit(uint256 gameId) external inState(GameState.PLAYING, gameId) {
        Game storage game = games[gameId];
        if (game.state != GameState.PLAYING) revert InvalidGameState();

        uint256 pIdx = _getPlayerIndex(gameId, msg.sender);
        if (pIdx != game.currentPlayerIndex) revert NotYourTurn();

        PlayerState storage player = game.players[pIdx];
        if (player.status != PlayerStatus.ACTIVE) revert InvalidAction();

        _dealCardToPlayer(gameId, pIdx);

        emit PlayerAction(gameId, msg.sender, "hit");

        // Check for bust
        if (player.hand.total > 21) {
            player.status = PlayerStatus.BUSTED;
            _advanceToNextActivePlayer(gameId);
        }
    }

    function stand(uint256 gameId) external inState(GameState.PLAYING, gameId) {
        Game storage game = games[gameId];
        if (game.state != GameState.PLAYING) revert InvalidGameState();

        uint256 pIdx = _getPlayerIndex(gameId, msg.sender);
        if (pIdx != game.currentPlayerIndex) revert NotYourTurn();

        PlayerState storage player = game.players[pIdx];
        if (player.status != PlayerStatus.ACTIVE) revert InvalidAction();

        player.status = PlayerStatus.STANDING;

        emit PlayerAction(gameId, msg.sender, "stand");

        _advanceToNextActivePlayer(gameId);
    }

    // ============================================================
    //  INTERNAL LOGIC
    // ============================================================

    function _dealCardToPlayer(uint256 gameId, uint256 playerIdx) internal {
        Game storage game = games[gameId];
        PlayerState storage player = game.players[playerIdx];

        Card memory card = _drawCard(gameId);
        player.hand.cards.push(card);
        _updateHandTotal(player.hand, card);

        emit CardDealt(gameId, player.addr, card.value, card.suit);
    }

    function _dealCardToDealer(uint256 gameId, bool hidden) internal {
        Game storage game = games[gameId];

        Card memory card = _drawCard(gameId);
        game.dealerHand.cards.push(card);
        _updateHandTotal(game.dealerHand, card);

        emit DealerCardDealt(gameId, card.value, card.suit, hidden);
    }

    function _drawCard(uint256 gameId) internal returns (Card memory) {
        Game storage game = games[gameId];

        uint256 seed = crRandom.generateFinalRandom();
        uint256 rand = uint(
            keccak256(abi.encodePacked(seed, ++game.rngRoundId))
        );

        uint8 value = uint8((rand % 13) + 1); // 1-13
        uint8 suit = uint8((rand / 13) % 4); // 0-3

        return Card(value, suit);
    }

    function _updateHandTotal(Hand storage hand, Card memory card) internal {
        uint8 cardValue;

        if (card.value == 1) {
            // Ace
            cardValue = 11;
            hand.hasUsableAce = true;
        } else if (card.value > 10) {
            // Face cards (J, Q, K)
            cardValue = 10;
        } else {
            cardValue = card.value;
        }

        hand.total += cardValue;

        // Adjust for ace if busted
        if (hand.total > 21 && hand.hasUsableAce) {
            hand.total -= 10;
            hand.hasUsableAce = false;
        }
    }

    function _advanceToNextActivePlayer(uint256 gameId) internal {
        //FIXME:
        Game storage game = games[gameId];

        game.currentPlayerIndex++;

        // Find next active player
        while (game.currentPlayerIndex < game.players.length) {
            if (
                game.players[game.currentPlayerIndex].status ==
                PlayerStatus.ACTIVE
            ) {
                return;
            }
            game.currentPlayerIndex++;
        }

        game.state = GameState.DEALER_TURN;
        _playDealerHand(gameId);
    }

    function _playDealerHand(uint256 gameId) internal {
        Game storage game = games[gameId];

        // Dealer must hit on 16 or less, stand on 17+
        while (game.dealerHand.total < 17) {
            _dealCardToDealer(gameId, false);
        }

        _resolveGame(gameId);
    }

    function _resolveGame(uint256 gameId) internal {
        Game storage game = games[gameId];
        game.state = GameState.RESOLVED;

        uint8 dealerTotal = game.dealerHand.total;
        bool dealerBusted = dealerTotal > 21;
        bool dealerBlackjack = dealerTotal == 21 &&
            game.dealerHand.cards.length == 2;

        uint256 totalPayoutNeeded = 0;

        // ---------------------------------------
        // 1. First pass: calculate total payouts
        // ---------------------------------------
        for (uint256 i = 0; i < game.players.length; i++) {
            PlayerState storage player = game.players[i];

            uint256 payout = 0;

            if (player.status == PlayerStatus.BUSTED) {
                payout = 0;
            } else if (player.status == PlayerStatus.BLACKJACK) {
                if (dealerBlackjack) {
                    payout = player.bet; // push
                } else {
                    payout = player.bet + (player.bet * 3) / 2; // 3:2
                }
            } else if (dealerBusted) {
                payout = player.bet * 2;
            } else if (player.hand.total > dealerTotal) {
                payout = player.bet * 2;
            } else if (player.hand.total == dealerTotal) {
                payout = player.bet; // push
            } else {
                payout = 0;
            }

            totalPayoutNeeded += payout;
        }

        // ---------------------------------------------------
        // 2. Request float from treasury if needed
        // ---------------------------------------------------
        uint256 tableBalance = address(this).balance;
        if (totalPayoutNeeded > tableBalance) {
            uint256 deficit = totalPayoutNeeded - tableBalance;

            // Pull ETH from treasury
            bank.requestFloat(deficit);
        }

        // -------------------------------
        // 3. Resolve each player & pay
        // -------------------------------
        for (uint256 i = 0; i < game.players.length; i++) {
            PlayerState storage player = game.players[i];

            uint256 payout = 0;
            bool won = false;

            if (player.status == PlayerStatus.BUSTED) {
                won = false;
            } else if (player.status == PlayerStatus.BLACKJACK) {
                if (dealerBlackjack) {
                    payout = player.bet;
                } else {
                    payout = player.bet + (player.bet * 3) / 2;
                    won = true;
                }
            } else if (dealerBusted) {
                payout = player.bet * 2;
                won = true;
            } else if (player.hand.total > dealerTotal) {
                payout = player.bet * 2;
                won = true;
            } else if (player.hand.total == dealerTotal) {
                payout = player.bet;
            }

            // ------------- Release exposure now that the player's round is over -------------
            bank.releaseExposure(player.bet);

            // ------------- Payout if needed -------------
            if (payout > 0) {
                payable(player.addr).transfer(payout);
            }

            emit GameResolved(gameId, player.addr, won, payout);
        }
    }

    function _getPlayerIndex(
        uint256 gameId,
        address player
    ) internal view returns (uint256) {
        Game storage game = games[gameId];
        for (uint256 i = 0; i < game.players.length; i++) {
            if (game.players[i].addr == player) {
                return i;
            }
        }
        revert NotYourTurn();
    }

    // ============================================================
    //  VIEW FUNCTIONS
    // ============================================================

    function getPlayerHand(
        uint256 gameId,
        address player
    ) external view returns (Card[] memory cards, uint8 total) {
        uint256 idx = _getPlayerIndex(gameId, player);
        Hand storage hand = games[gameId].players[idx].hand;
        return (hand.cards, hand.total);
    }

    function getDealerVisibleCard(
        uint256 gameId
    ) external view returns (Card memory) {
        Game storage game = games[gameId];
        require(game.dealerHand.cards.length > 0, "No cards dealt");
        return game.dealerHand.cards[0];
    }

    function getDealerHand(
        uint256 gameId
    ) external view returns (Card[] memory cards, uint8 total) {
        Game storage game = games[gameId];
        require(
            game.state == GameState.DEALER_TURN ||
                game.state == GameState.RESOLVED,
            "Dealer hand hidden"
        );
        return (game.dealerHand.cards, game.dealerHand.total);
    }

    function getGameInfo(
        uint256 gameId
    )
        external
        view
        returns (GameState state, uint256 playerCount, uint8 currentPlayer)
    {
        Game storage game = games[gameId];
        return (game.state, game.players.length, game.currentPlayerIndex);
    }

    function getPlayerStatus(
        uint256 gameId,
        address player
    ) external view returns (PlayerStatus status, uint256 bet) {
        uint256 idx = _getPlayerIndex(gameId, player);
        PlayerState storage p = games[gameId].players[idx];
        return (p.status, p.bet);
    }

    // ============================================================
    //  HOUSE FUNCTIONS
    // ============================================================

    function withdraw() external onlyHouse {
        payable(house).transfer(address(this).balance);
    }

    receive() external payable {}
}
