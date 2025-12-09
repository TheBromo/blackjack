// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;
// import "./EfficientHashLib.sol" as EH;
//
// contract CommitRevealRandom {
//     // --- Events ---
//     event RoundStarted(uint256 indexed roundId, address[] committee, uint256 commitDeadline, uint256 revealDeadline);
//     event CommitSubmitted(uint256 indexed roundId, address indexed participant, bytes32 commitHash);
//     event ChainCommitSubmitted(uint256 indexed roundId, address indexed participant, bytes32 commitHash);
//     event ValueRevealed(uint256 indexed roundId, address indexed participant, bytes32 value);
//     event RandomnessGenerated(uint256 indexed roundId, bytes32 randomNumber);
//
//     // --- State ---
//     address public immutable controllerContract;
//     uint256 public roundId;
//
//     struct Round {
//         uint256 chainCommitDeadline;
//         uint256 commitDeadline;
//         uint256 revealDeadline;
//         mapping(address => bool) isCommittee;
//         mapping(address => bytes32) commits;
//         mapping(address => bytes32) chainCommits;
//         bytes32 randomSeed;
//         bool isFinalized;
//     }
//
//     uint256 public immutable CHAIN_COMMIT_DURATION = 30 seconds;
//     uint256 public immutable COMMIT_DURATION = 30 seconds;
//     uint256 public immutable REVEAL_DURATION = 30 seconds;
//
//     mapping(uint256 => Round) public rounds;
//
//     // --- Modifiers ---
//     modifier onlyController() {
//         _onlyController();
//         _;
//     }
//
//     function _onlyController() internal view {
//         require(msg.sender == controllerContract, "Only controller");
//     }
//
//     modifier onlyCommittee() {
//         _onlyCommittee();
//         _;
//     }
//
//     function _onlyCommittee() internal view {
//         require(rounds[roundId].isCommittee[msg.sender], "Only Committee");
//     }
//
//     constructor() {
//         controllerContract = msg.sender;
//     }
//
//     function createRound(address[] calldata committee) external onlyController returns (uint256 _roundId) {
//         roundId = ++roundId;
//         Round storage r = rounds[roundId];
//
//         r.chainCommitDeadline = block.timestamp + CHAIN_COMMIT_DURATION;
//         r.commitDeadline = block.timestamp + CHAIN_COMMIT_DURATION + COMMIT_DURATION;
//         r.revealDeadline = block.timestamp + CHAIN_COMMIT_DURATION + COMMIT_DURATION + REVEAL_DURATION;
//
//         for (uint256 i = 0; i < committee.length; i++) {
//             r.isCommittee[committee[i]] = true;
//         }
//
//         emit RoundStarted(roundId, committee, r.commitDeadline, r.revealDeadline);
//         return roundId;
//     }
//
//     function commitChain(bytes32 commitChainHash) external onlyCommittee {
//         Round storage r = rounds[roundId];
//         require(block.timestamp < r.commitDeadline, "Commit phase over");
//         require(r.isCommittee[msg.sender], "Not in committee");
//         require(r.chainCommits[msg.sender] == bytes32(0), "Already committed");
//
//         r.chainCommits[msg.sender] = commitChainHash;
//         emit ChainCommitSubmitted(roundId, msg.sender, commitChainHash);
//     }
//
//     //TODO: do not use user suplied round
//     function commit(bytes32 commitHash) external onlyCommittee {
//         Round storage r = rounds[roundId];
//         require(block.timestamp < r.chainCommitDeadline, "chain commit phase over");
//         require(r.isCommittee[msg.sender], "Not in committee");
//         require(r.commits[msg.sender] == bytes32(0), "Already committed");
//         require(keccak256(abi.encode(commitHash)) == r.chainCommits[msg.sender], "Commit does not match the chain");
//
//         r.commits[msg.sender] = commitHash;
//         emit CommitSubmitted(roundId, msg.sender, commitHash);
//     }
//
//     //TODO: do not use user suplied round
//     function reveal(bytes32 value) external onlyCommittee {
//         Round storage r = rounds[roundId];
//         require(block.timestamp >= r.commitDeadline, "Commit phase active");
//         require(block.timestamp < r.revealDeadline, "Reveal phase over");
//
//         // bytes32 derivedHash = EH.EfficientHashLib.hash(salt, value);
//         bytes32 derivedHash = keccak256(abi.encode(value));
//         require(r.commits[msg.sender] == derivedHash, "Invalid reveal");
//
//         delete r.commits[msg.sender];
//
//         // r.randomSeed ^= EH.EfficientHashLib.hash(r.randomSeed, value);
//         r.randomSeed = keccak256(abi.encode(r.randomSeed, value));
//
//         emit ValueRevealed(roundId, msg.sender, value);
//     }
//
//     function finalizeRandomness() external onlyController {
//         Round storage r = rounds[roundId];
//         require(block.timestamp >= r.revealDeadline, "Reveal phase active");
//         require(!r.isFinalized, "Already finalized");
//
//         r.isFinalized = true;
//         r.randomSeed = EH.EfficientHashLib.hash(r.randomSeed);
//
//         emit RandomnessGenerated(roundId, r.randomSeed);
//     }
//
//     function isFinalized() external view onlyController returns (bool finalized) {
//         Round storage r = rounds[roundId];
//         return r.isFinalized;
//     }
//
//     function finalRandom(uint256 _roundId) external view onlyController returns (bytes32 seed) {
//         Round storage r = rounds[_roundId];
//         return r.randomSeed;
//     }
// }
