// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./EfficientHashLib.sol" as EH;

contract CommitRevealRandom {
    uint256 public COMMIT_DURATION = 15;
    uint256 public immutable REVEAL_DURATION = 15;

    // --- Events ---
    event RoundStarted(uint256 indexed roundId, address[] committee, uint256 commitDeadline);
    event CommitSubmitted(uint256 indexed roundId, address indexed participant, bytes32 commitHash);
    event ValueRevealed(uint256 indexed roundId, address indexed participant, bytes32 value);
    event RandomnessGenerated(uint256 indexed roundId, bytes32 randomNumber);

    // --- State ---
    address public immutable controllerContract;
    uint256 public currentRoundId;

    struct Round {
        uint256 commitDeadline;
        uint256 revealDeadline;
        mapping(address => bool) isCommittee;
        mapping(address => bytes32) commits;
        bytes32 randomSeed;
        bool isFinalized;
    }

    mapping(uint256 => Round) public rounds;

    // --- Modifiers ---
    modifier onlyController() {
        _onlyController();
        _;
    }

    function _onlyController() internal view {
        require(msg.sender == controllerContract, "Only controller");
    }

    modifier onlyCommittee() {
        _onlyCommittee();
        _;
    }

    function _onlyCommittee() internal view {
        require(rounds[currentRoundId].isCommittee[msg.sender], "Only Committee");
    }

    constructor() {
        controllerContract = msg.sender;
    }

    function createRound(address[] calldata committee, uint256 commitDuration, uint256 revealDuration)
        external
        onlyController
        returns (uint256 roundId)
    {
        roundId = ++currentRoundId;
        Round storage r = rounds[roundId];

        r.commitDeadline = block.timestamp + commitDuration;
        r.revealDeadline = block.timestamp + commitDuration + revealDuration;

        for (uint256 i = 0; i < committee.length; i++) {
            r.isCommittee[committee[i]] = true;
        }

        emit RoundStarted(roundId, committee, r.commitDeadline);
        return roundId;
    }

    function commit(uint256 roundId, bytes32 commitHash) external onlyCommittee {
        Round storage r = rounds[roundId];
        require(block.timestamp < r.commitDeadline, "Commit phase over");
        require(r.isCommittee[msg.sender], "Not in committee");
        require(r.commits[msg.sender] == bytes32(0), "Already committed");

        r.commits[msg.sender] = commitHash;
        emit CommitSubmitted(roundId, msg.sender, commitHash);
    }

    function reveal(uint256 roundId, bytes32 salt, bytes32 value) external onlyCommittee {
        Round storage r = rounds[roundId];
        require(block.timestamp >= r.commitDeadline, "Commit phase active");
        require(block.timestamp < r.revealDeadline, "Reveal phase over");

        bytes32 derivedHash = EH.EfficientHashLib.hash(salt, value);
        require(r.commits[msg.sender] == derivedHash, "Invalid reveal");

        delete r.commits[msg.sender];

        r.randomSeed ^= EH.EfficientHashLib.hash(r.randomSeed, value);

        emit ValueRevealed(roundId, msg.sender, value);
    }

    function finalizeRandomness(uint256 roundId) external {
        Round storage r = rounds[roundId];
        require(block.timestamp >= r.revealDeadline, "Reveal phase active");
        require(!r.isFinalized, "Already finalized");

        r.isFinalized = true;
        r.randomSeed = EH.EfficientHashLib.hash(r.randomSeed, bytes32(block.timestamp), bytes32(block.prevrandao));

        emit RandomnessGenerated(roundId, r.randomSeed);
    }

    function optimizedHash(bytes32 a, bytes32 b) internal pure returns (bytes32 hashedVal) {
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            hashedVal := keccak256(0x00, 0x40)
        }
    }

    function isFinalized(uint256 roundId) external view onlyController returns (bool finalized) {
        Round storage r = rounds[roundId];
        return r.isFinalized;
    }

    function finalRandom(uint256 roundId) external view onlyController returns (bytes32 seed) {
        Round storage r = rounds[roundId];
        return r.randomSeed;
    }
}
