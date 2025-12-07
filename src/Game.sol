// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BlackjackHelper.sol" as bh;

/**
 * @title Blackjack
 * @notice On-chain blackjack game with commit-reveal randomness
 *         Max 5 players, standard blackjack rules
 */
contract Blackjack {
    address payable public immutable HOUSE;

    uint256 public immutable ROUND_DURATION = 120 seconds;
    error OnlyHouseAllowed();
    event GameCreated(uint256 gameId);
    event PlayerAction(string action);

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

    //TODO: write
    struct Game {
        uint256 phaseStartTime;
        uint256 playerCount;
        uint256 roundId;
        uint256 cardCount;
        Stages stage;
        mapping(address => bool) isPlayer;
        PlayerState[] players;
        Hand dealerHand;
        bytes32 anchor;
    }
    using bh.Helper for Game;
    mapping(uint256 => Game) public games;
    uint256 public gameId;

    enum Stages {
        DEAL_CARDS,
        PLAYER_ROUND,
        DEALER_ROUND,
        FINISHED
    }

    constructor() {
        HOUSE = payable(msg.sender);
    }

    modifier onlyHouse() {
        _onlyHouse();
        _;
    }

    function _onlyHouse() internal view {
        if (msg.sender != HOUSE) revert OnlyHouseAllowed();
    }

    modifier onlyPlayer() {
        _onlyPlayer();
        _;
    }

    function _onlyPlayer() internal view {
        require(games[gameId].isPlayer[msg.sender], "is not a player");
    }

    modifier atStage(Stages _stage) {
        _atStage(_stage);
        _;
    }

    function _atStage(Stages _stage) internal view {
        require(games[gameId].stage == _stage);
    }

    modifier atStages(Stages[] memory stages) {
        _atStages(stages);
        _;
    }

    function _atStages(Stages[] memory stages) internal view {
        Stages current = games[gameId].stage;
        bool allowed = false;

        for (uint256 i = 0; i < stages.length; i++) {
            if (current == stages[i]) {
                allowed = true;
                break;
            }
        }

        require(allowed, "Not allowed at this stage");
    }
    modifier transitionAfter() {
        _;
        nextStage();
    }
    modifier timedTransitions() {
        _timedTransitions();
        _;
    }

    function _timedTransitions() internal {
        if (
            games[gameId].stage == Stages.PLAYER_ROUND
                && block.timestamp >= games[gameId].phaseStartTime + ROUND_DURATION
        ) {
            nextStage();
        }
    }

    function nextStage() internal {
        games[gameId].stage = Stages(uint256(games[gameId].stage) + 1);
        games[gameId].phaseStartTime = block.timestamp;
    }

    function createGame(address[] calldata players, bytes32 anchor) external timedTransitions onlyHouse {
        gameId++;
        Game storage game = games[gameId];
        game.phaseStartTime = block.timestamp;
        game.stage = Stages.DEAL_CARDS;
        game.anchor = anchor;

        for (uint256 i = 0; i < players.length; i++) {
            game.players.push();
            game.isPlayer[players[i]] = true;
            game.players[i].addr = msg.sender;
            game.players[i].status = PlayerStatus.ACTIVE;
        }

        emit GameCreated(gameId);
    }

    function deal(bytes32 _newAnchor) external timedTransitions onlyHouse atStage(Stages.DEAL_CARDS) transitionAfter {
        Game storage game = games[gameId];
        require(keccak256(abi.encodePacked(_newAnchor)) == game.anchor, "new anchor is not in chain");
        game.anchor = _newAnchor;
        //dealing

        // Deal 2 cards to each player
        for (uint256 i = 0; i < game.players.length; i++) {
            PlayerState storage player = game.players[i];
            game._dealCardToPlayer(game.anchor, player);
            game._dealCardToPlayer(game.anchor, player);

            // Check for natural blackjack
            if (game.players[i].hand.total == 21) {
                game.players[i].status = PlayerStatus.BLACKJACK;
            }
        }

        // Deal 2 cards to dealer
        game._dealCardToDealer(game.anchor); // visible
    }

    function hit() external atStage(Stages.PLAYER_ROUND) onlyPlayer {
        emit PlayerAction("hit");
    }

    function stand() external atStage(Stages.PLAYER_ROUND) onlyPlayer {
        // require(RNG.isFinalized(game.rngId), "Seed generation not finished");
        PlayerState storage player = _getPlayer(msg.sender);
        require(player.status == PlayerStatus.ACTIVE, "player must be still active");

        player.status = PlayerStatus.STANDING;
        emit PlayerAction("stand");
    }

    function dealActions(bytes32 _newAnchor) external timedTransitions onlyHouse atStage(Stages.DEALER_ROUND) {
        Game storage game = games[gameId];
        // require(RNG.isFinalized(game.rngId), "Seed generation not finished");
        // uint256 seed = uint256(RNG.finalRandom(game.rngId));
        //if all standing resolve
        require(keccak256(abi.encodePacked(_newAnchor)) == game.anchor, "new anchor is not in chain");
        game.anchor = _newAnchor;
        if (allFinished()) {
            // game._resolveGame(seed);
            // Dealer must hit on 16 or less, stand on 17+
            while (game.dealerHand.total < 17) {
                game._dealCardToDealer(game.anchor);
            }
            nextStage();
        } else {
            //deal to all players
            for (uint256 i = 0; i < game.players.length; i++) {
                PlayerState storage player = game.players[i];
                if (player.status == PlayerStatus.ACTIVE) {
                    game._dealCardToPlayer(game.anchor, player);
                }

                // Check for natural blackjack
                if (player.hand.total == 21) {
                    player.status = PlayerStatus.BLACKJACK;
                } else if (player.hand.total > 21) {
                    player.status = PlayerStatus.BUSTED;
                }
            }
            if (allFinished()) {
                //TODO: transition to next phase
                while (game.dealerHand.total < 17) {
                    game._dealCardToDealer(game.anchor);
                }
                nextStage();
            } else {
                game.stage = Stages.PLAYER_ROUND;
                games[gameId].phaseStartTime = block.timestamp;
            }
        }
    }

    function allFinished() public view returns (bool) {
        Game storage game = games[gameId];

        bool _allFinished = true;
        for (uint256 i = 0; i < game.players.length; i++) {
            PlayerState storage player = game.players[i];
            _allFinished = _allFinished && (player.status != PlayerStatus.ACTIVE);
        }
        return _allFinished;
    }

    function _getPlayer(address player) internal view returns (PlayerState storage) {
        Game storage game = games[gameId];
        for (uint256 i = 0; i < game.players.length; i++) {
            if (game.players[i].addr == player) {
                return game.players[i];
            }
        }
        revert("Player not found");
    }

    function _stages(Stages a, Stages b) internal pure returns (Stages[] memory s) {
        s = new Stages[](2);
        s[0] = a;
        s[1] = b;
    }

    function currentGame() external view returns (uint256) {
        return gameId;
    }

    function getGameInfo(uint256 id)
        external
        view
        returns (
            uint256 phaseStartTime,
            uint256 playerCount,
            uint256 roundId,
            uint256 cardCount,
            Stages stage,
            bytes32 anchor
        )
    {
        Game storage game = games[id];

        return (game.phaseStartTime, game.playerCount, game.roundId, game.cardCount, game.stage, game.anchor);
    }

    function getAllPlayerResolveViews(uint256 id)
        external
        view
        returns (address[] memory addrs, uint256[] memory bets, uint256[] memory totals, PlayerStatus[] memory statuses)
    {
        Game storage game = games[id];
        uint256 count = game.players.length;

        addrs = new address[](count);
        bets = new uint256[](count);
        totals = new uint256[](count);
        statuses = new PlayerStatus[](count);

        for (uint256 i = 0; i < count; i++) {
            PlayerState storage p = game.players[i];
            addrs[i] = p.addr;
            bets[i] = p.bet;
            totals[i] = p.hand.total;
            statuses[i] = p.status;
        }
    }

    function previewPayout(uint256 id, uint256 index) external view returns (uint256 payout, bool won) {
        Game storage game = games[id];
        PlayerState storage player = game.players[index];

        uint256 dealerTotal = game.dealerHand.total;
        bool dealerBusted = dealerTotal > 21;
        bool dealerBlackjack = dealerTotal == 21 && game.dealerHand.cards.length == 2;

        if (player.status == PlayerStatus.BUSTED) {
            return (0, false);
        }

        if (player.status == PlayerStatus.BLACKJACK) {
            if (dealerBlackjack) return (player.bet, false);
            return (player.bet + (player.bet * 3) / 2, true);
        }

        if (dealerBusted || player.hand.total > dealerTotal) {
            return (player.bet * 2, true);
        }

        if (player.hand.total == dealerTotal) {
            return (player.bet, false);
        }

        return (0, false);
    }

    function getPlayerResolveView(uint256 id, uint256 index)
        external
        view
        returns (address addr, uint256 bet, uint256 handTotal, PlayerStatus status)
    {
        PlayerState storage player = games[id].players[index];

        return (player.addr, player.bet, player.hand.total, player.status);
    }

    function getGamePlayerCount(uint256 id) external view returns (uint256) {
        return games[id].players.length;
    }

    function getDealerCardCount(uint256 id) external view returns (uint256) {
        return games[id].dealerHand.cards.length;
    }

    function getDealerTotal(uint256 id) external view returns (uint256) {
        return games[id].dealerHand.total;
    }

    function getPlayerCount(uint256 id) external view returns (uint256) {
        return games[id].players.length;
    }

    function getStage(uint256 id) external view returns (Stages) {
        return games[id].stage;
    }
}
