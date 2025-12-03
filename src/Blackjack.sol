// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./CommitRevealRandom.sol" as CRR;
import "./BlackjackHelper.sol" as bh;

/**
 * @title Blackjack
 * @notice On-chain blackjack game with commit-reveal randomness
 *         Max 5 players, standard blackjack rules
 */
contract Blackjack {
    CRR.CommitRevealRandom public immutable RNG;
    address payable public immutable HOUSE;

    uint8 public constant MAX_PLAYERS = 7;
    uint256 public constant FEE_PERCENT = 5; // 5%
    uint256 public constant MIN_BET = 0.01 ether;
    uint256 public constant MAX_BET = 10 ether;

    uint256 public immutable BETTING_DURATION = 120 seconds;
    uint256 public immutable ROUND_DURATION = 60 seconds;
    uint256 public immutable SEEDING_DURATION = 60 seconds;
    error OnlyHouseAllowed();
    event GameCreated(uint256 gameId);

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
        uint256 phaseStartTime;
        uint256 playerCount;
        uint256 rngId;
        uint256 roundId;
        uint256 cardCount;
        Stages stage;
        mapping(address => bool) isPlayer;
        PlayerState[] players;
        Hand dealerHand;
        mapping(address => uint256) bet;
    }
    using bh.Helper for Game;
    mapping(uint256 => Game) public games;
    uint256 public gameId;

    enum Stages {
        BETTING,
        FIRST_SEED_GEN,
        DEAL_CARDS,
        SECOND_SEED_GEN,
        PLAYER_ROUND,
        THIRD_SEED_GEN,
        DEALER_ROUND,
        FINISHED
    }

    constructor() {
        HOUSE = payable(msg.sender);
        RNG = new CRR.CommitRevealRandom();
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
        require(games[gameId].isPlayer[msg.sender], "is a player");
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
        if (games[gameId].stage == Stages.BETTING && block.timestamp >= games[gameId].phaseStartTime + BETTING_DURATION)
        {
            nextStage();
        }
        if (
            games[gameId].stage == Stages.PLAYER_ROUND
                && block.timestamp >= games[gameId].phaseStartTime + ROUND_DURATION
        ) {
            nextStage();
        }

        if (
            (games[gameId].stage == Stages.FIRST_SEED_GEN
                    || games[gameId].stage == Stages.SECOND_SEED_GEN
                    || games[gameId].stage == Stages.THIRD_SEED_GEN)
                && block.timestamp >= games[gameId].phaseStartTime + SEEDING_DURATION + 10
        ) {
            RNG.finalizeRandomness(games[gameId].rngId);
            nextStage();
        }
        if (
            games[gameId].stage == Stages.DEALER_ROUND
                && block.timestamp >= games[gameId].phaseStartTime + ROUND_DURATION
        ) {
            nextStage();
        }
    }

    function nextStage() internal {
        games[gameId].stage = Stages(uint256(games[gameId].stage) + 1);
    }

    function createGame() external timedTransitions onlyHouse {
        gameId++;
        games[gameId].phaseStartTime = block.timestamp;
        games[gameId].stage = Stages.BETTING;
        emit GameCreated(gameId);
    }

    function bet() external payable timedTransitions atStage(Stages.BETTING) {
        Game storage game = games[gameId];
        require(game.playerCount <= MAX_PLAYERS, "Game full");
        require(!game.isPlayer[msg.sender], "Player has already joined");
        require(msg.value < MIN_BET || msg.value > MAX_BET, "Bet to high");
        game.players.push(); // add address to the array
        game.playerCount++;

        uint256 fee = (msg.value * FEE_PERCENT) / 100;
        uint256 betAmount = msg.value - fee;
        (bool success,) = HOUSE.call{value: fee}("");
        require(success, "Fee transfer failed");
        game.bet[msg.sender] = betAmount;
    }

    function generateSeed()
        external
        timedTransitions
        onlyHouse
        atStages(_stages(Stages.FIRST_SEED_GEN, Stages.SECOND_SEED_GEN, Stages.THIRD_SEED_GEN))
    {
        Game storage game = games[gameId];
        address[] memory committee = new address[](game.players.length + 1);

        // Fill it with player addresses
        for (uint256 i = 0; i < game.players.length; i++) {
            committee[i] = game.players[i].addr;
        }
        committee[game.players.length] = HOUSE;

        game.rngId = RNG.createRound(committee, SEEDING_DURATION / 2, SEEDING_DURATION / 2);
    }

    function deal() external timedTransitions onlyHouse atStage(Stages.DEAL_CARDS) transitionAfter {
        Game storage game = games[gameId];
        require(!RNG.isFinalized(game.rngId), "Seed generation not finished");
        uint256 seed = uint256(RNG.finalRandom(game.rngId));
        //dealing

        // Deal 2 cards to each player
        for (uint256 i = 0; i < game.players.length; i++) {
            game._dealCardToPlayer(seed, game.players[i]);
            game._dealCardToPlayer(seed, game.players[i]);

            // Check for natural blackjack
            if (game.players[i].hand.total == 21) {
                game.players[i].status = PlayerStatus.BLACKJACK;
            }
        }

        // Deal 2 cards to dealer
        game._dealCardToDealer(seed); // visible
        // game._dealCardToDealer(seed, true); // hidden initially
        // TODO: do later after player round
    }

    function hit() external atStage(Stages.PLAYER_ROUND) onlyPlayer {
        Game storage game = games[gameId];
        require(!RNG.isFinalized(game.rngId), "Seed generation not finished");

        PlayerState storage player = _getPlayer(msg.sender);
        require(player.status == PlayerStatus.ACTIVE, "player must be still active");
        game._dealCardToPlayer(gameId, player);
        if (player.hand.total > 21) {
            player.status = PlayerStatus.BUSTED;
        }
    }

    function stand() external atStage(Stages.PLAYER_ROUND) onlyPlayer {
        Game storage game = games[gameId];
        require(!RNG.isFinalized(game.rngId), "Seed generation not finished");
        PlayerState storage player = _getPlayer(msg.sender);
        require(player.status == PlayerStatus.ACTIVE, "player must be still active");

        player.status = PlayerStatus.STANDING;
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

    function _stages(Stages a, Stages b, Stages c) internal pure returns (Stages[] memory s) {
        s[0] = a;
        s[1] = b;
        s[3] = c;
    }
}
