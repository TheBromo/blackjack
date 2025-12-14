// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./CRR2.sol" as CR;

contract Setup {
    address immutable FEE_RECEIVER;
    address immutable WINNING_DISTRIBUTOR;
    address immutable CONTROLLER;

    uint256 constant MAX_PARTICIPANTS = 5;
    //DURATION
    uint256 public constant BETTING_DURATION = 3 seconds;
    uint256 public constant CRR_DURATION = 12 seconds;
    uint256 public constant CHAIN_DURATION = 3 seconds;
    uint256 public constant CUT_DURATION = 6 seconds;
    uint256 public constant TOTAL_DURATION = CRR_DURATION + BETTING_DURATION + CHAIN_DURATION + CUT_DURATION;
    //BET
    uint256 public constant MAX_BET = 100 ether;
    uint256 public constant MIN_BET = 1 ether;
    uint256 public constant FEE_PERCENT = 5;

    CR.CommitReveal2 public immutable cr;

    enum SetupPhase {
        BETTING,
        RNG,
        CHAIN,
        CUT,
        CUTCHAIN
    }

    struct Participant {
        address addr;
        uint256 bet;
        bool isSlashed;
    }

    struct GameSetup {
        uint256 playerCount;
        uint256 startTime;
        Participant[] players;
        mapping(address => bool) isPlayer;
        mapping(address => bool) hasSubmitedCut;
        bytes32 anchor;
        uint256 cut;
        bool cutApplied;
        bytes32 random;
    }
    mapping(uint256 => GameSetup) public games;
    uint256 public id;

    constructor(address feeAddr, address winAddr, address controller) {
        FEE_RECEIVER = feeAddr;
        WINNING_DISTRIBUTOR = winAddr;
        CONTROLLER = controller;
        cr = new CR.CommitReveal2(CRR_DURATION / 2, CRR_DURATION / 2, address(this));
    }

    modifier onlyParticipant() {
        _onlyParticipant();
        _;
    }

    function _onlyParticipant() internal view {
        require(games[id].isPlayer[msg.sender], "only player allowed");
    }
    modifier onlyController() {
        _onlyController();
        _;
    }

    function _onlyController() internal view {
        require(msg.sender == CONTROLLER, "only controller allowed");
    }
    modifier onlyHouse() {
        _onlyHouse();
        _;
    }

    function _onlyHouse() internal view {
        require(msg.sender == FEE_RECEIVER, "only house allowed");
    }

    modifier atPhase(SetupPhase _phase) {
        _atPhase(_phase);
        _;
    }

    function _atPhase(SetupPhase _phase) internal view {
        // if (getPhase() == _phase) {
        //     // console.log("++++++++++++++++++++++++++++++ rejecting ++++++++++++++++++++++++++++++++++++");
        //     // console.log(msg.sender, uint256(games[id].anchor));
        // }
        require(getPhase() == _phase, "not at phase ");
    }

    function start(uint256 _id) external onlyController {
        // console.log("---------------------------------------------------------------");
        // console.log("starting setup", msg.sender);
        id = _id;
        games[id].startTime = block.timestamp;
        cr.reset(games[id].startTime + BETTING_DURATION);
        cr.register(FEE_RECEIVER);
    }

    function bet() external payable atPhase(SetupPhase.BETTING) {
        // console.log("---------------------------------------------------------------");
        // console.log("betting", msg.sender);
        GameSetup storage game = games[id];
        require(game.playerCount < MAX_PARTICIPANTS, "Game full");
        require(!game.isPlayer[msg.sender], "Player has already joined");
        require(msg.value >= MIN_BET && msg.value <= MAX_BET, "Bet to high");
        require(block.timestamp <= games[id].startTime + BETTING_DURATION, "Betting phase over");

        game.players.push();
        game.playerCount++;

        uint256 fee = (msg.value * FEE_PERCENT) / 100;
        uint256 betAmount = msg.value - fee;
        (bool success1,) = FEE_RECEIVER.call{value: fee}("");
        (bool success2,) = WINNING_DISTRIBUTOR.call{value: betAmount}("");
        require(success1 && success2, "Fee transfer failed");

        cr.register(msg.sender);
        game.players[game.players.length - 1].addr = msg.sender;
        game.players[game.players.length - 1].bet = betAmount;
        game.isPlayer[msg.sender] = true;
    }

    function submitChain(bytes32 _anchor) external onlyHouse atPhase(SetupPhase.CHAIN) {
        // console.log("---------------------------------------------------------------");
        require(_anchor != 0, "_anchor cannot be 0");
        // console.log("submitting chain", msg.sender);
        GameSetup storage game = games[id];
        game.random = cr.omega_o();

        // console.log("submitting chain", uint256(_anchor));

        for (uint256 i = 0; i < game.players.length; i++) {
            game.players[i].isSlashed = true;
        }
        games[id].anchor = _anchor;

        // console.log("new anchor", uint256(games[id].anchor));
        // console.log("id", id);
    }

    function submitCut(uint256 amount) external onlyParticipant atPhase(SetupPhase.CUT) {
        // console.log("---------------------------------------------------------------");
        // console.log("submitting cut", msg.sender);
        require(amount >= 0 && amount < 10, "cut to big or small");
        GameSetup storage game = games[id];

        for (uint256 i = 0; i < game.players.length; i++) {
            if (game.players[i].addr == msg.sender && game.players[i].isSlashed) {
                game.players[i].isSlashed = false;
                game.cut += amount;
            }
        }
        // console.log("anchor", uint256(games[id].anchor));
        // console.log("id", id);
    }

    function revealCutChain(bytes32 _newAnchor) external onlyHouse atPhase(SetupPhase.CUTCHAIN) {
        // console.log("---------------------------------------------------------------");
        // console.log("cutting chain", msg.sender);
        GameSetup storage game = games[id];
        // console.log("anchor", uint256(games[id].anchor));
        // console.log("id", id);
        require(!game.cutApplied, "already cut");

        bytes32 tempHash = _newAnchor;
        for (uint256 i = 0; i < games[id].cut; i++) {
            tempHash = keccak256(abi.encodePacked(tempHash));
        }

        require(tempHash == game.anchor, "Invalid Cut Proof");
        game.anchor = _newAnchor;
        game.cutApplied = true;
    }

    // function getParticipants() public view returns (address[] memory) {
    //     // console.log("---------------------------------------------------------------");
    //     // console.log("viewing participants", msg.sender);
    //     GameSetup storage game = games[id];
    //
    //     // First count how many are not slashed
    //     uint256 count = 0;
    //     for (uint256 i = 0; i < game.players.length; i++) {
    //         if (!game.players[i].isSlashed) {
    //             //&& game.players[i].addr != FEE_RECEIVER) {
    //             count++;
    //         }
    //     }
    //
    //     // Create memory array of correct size
    //     address[] memory _participant = new address[](count);
    //
    //     // Fill the array
    //     uint256 index = 0;
    //     for (uint256 i = 0; i < game.players.length; i++) {
    //         if (!game.players[i].isSlashed) {
    //             //&& game.players[i].addr != FEE_RECEIVER) {
    //             _participant[index] = game.players[i].addr;
    //             index++;
    //         }
    //     }
    //
    //     return _participant;
    // }

    function participants() public view returns (address[] memory) {
        // console.log("---------------------------------------------------------------");
        // console.log("viewing participants", msg.sender);
        GameSetup storage game = games[id];

        // First count how many are not slashed
        uint256 count = 0;
        for (uint256 i = 0; i < game.players.length; i++) {
            if (!game.players[i].isSlashed) {
                count++;
            }
        }

        // Create memory array of correct size
        address[] memory _participant = new address[](count);

        // Fill the array
        uint256 index = 0;
        for (uint256 i = 0; i < game.players.length; i++) {
            if (!game.players[i].isSlashed) {
                _participant[index] = game.players[i].addr;
                index++;
            }
        }

        return _participant;
    }

    function playerCount() public view returns (uint256) {
        return games[id].players.length;
    }

    function getCut() public view returns (uint256) {
        return games[id].cut;
    }

    function maxBet() public view returns (uint256) {
        return (uint256(payable(WINNING_DISTRIBUTOR).balance) * 9) / (10 * MAX_PARTICIPANTS);
    }

    function getPhase() public view returns (SetupPhase phase) {
        // console.log("---------------------------------------------------------------");
        // console.log(msg.sender, uint256(games[id].anchor));
        // console.log("timestamp", block.timestamp);
        if (block.timestamp < games[id].startTime + BETTING_DURATION) {
            return SetupPhase.BETTING;
        } else if (
            block.timestamp
                < games[id].startTime + BETTING_DURATION + CRR_DURATION + (cr.TURN_TIMEOUT() * playerCount())
        ) {
            // console.log("rng");
            return SetupPhase.RNG;
        } else if (
            block.timestamp
                < games[id].startTime + BETTING_DURATION + CRR_DURATION + CHAIN_DURATION
                    + (cr.TURN_TIMEOUT() * playerCount())
        ) {
            // console.log(
            //     games[id].startTime + BETTING_DURATION + CRR_DURATION + CHAIN_DURATION
            //         + (cr.TURN_TIMEOUT() * playerCount())
            // );
            // console.log("chain");
            return SetupPhase.CHAIN;
        } else if (
            block.timestamp
                < games[id].startTime + BETTING_DURATION + CRR_DURATION + CHAIN_DURATION + CUT_DURATION
                    + (cr.TURN_TIMEOUT() * playerCount())
        ) {
            // console.log(
            //     games[id].startTime + BETTING_DURATION + CRR_DURATION + CHAIN_DURATION + CUT_DURATION
            //         + (cr.TURN_TIMEOUT() * playerCount())
            // );
            // console.log("cut");
            return SetupPhase.CUT;
        } else {
            // console.log("cutchain");
            return SetupPhase.CUTCHAIN;
        }
    }

    function getHouse() public view returns (address) {
        return FEE_RECEIVER;
    }

    function evalHash(bytes32 _newAnchor) public view returns (bytes32) {
        // console.log("---------------------------------------------------------------");
        // console.log("eval hash", msg.sender);
        bytes32 tempHash = _newAnchor;
        for (uint256 i = 0; i < games[id].cut; i++) {
            tempHash = keccak256(abi.encodePacked(tempHash));
        }
        return tempHash;
    }

    function anchor() public view returns (bytes32) {
        // console.log("---------------------------------------------------------------");
        // console.log("getting anchor", msg.sender);
        GameSetup storage game = games[id];
        return game.anchor;
    }

    function getAnchor() public view returns (bytes32) {
        // console.log("---------------------------------------------------------------");
        // console.log("getting anchor", msg.sender);
        return games[id].anchor;
    }

    function getFinalRandom() external view returns (bytes32) {
        return games[id].random;
    }
}
