// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract RandomCommittee {
    address public immutable OWNER;
    uint256 public maxRoundId;
    uint256 public commitDeadline;
    uint256 public revealDeadline;

    enum MemberStatus {
        None,
        Active,
        Slashed
    }
    enum Phase {
        Commit,
        Reveal
    }

    event MemberJoined(address indexed member);
    event MemberLeft(address indexed member);
    event MemberSlashed(address indexed member);
    event RoundStarted(uint256 indexed round);
    event RoundFinalized(uint256 indexed round, uint256 participants, bytes32 beaconValue);

    struct Round {
        // mapping(member => commitment_hash)
        mapping(address => bytes32) commitments;
        // mapping(member => revealed_value)
        mapping(address => bytes32) revealedValues;
        // mapping(member => has_committed)
        mapping(address => uint256) memberIndices;
        mapping(address => bool) hasCommitted;
        // mapping(member => has_revealed)
        mapping(address => bool) hasRevealed;
        mapping(address => MemberStatus) memberStatus;
        // The final computed random value for the round
        bytes32 finalRandomValue;
        // The number of members who successfully contributed
        uint256 numParticipants;
        // Flag to prevent double-finalizing
        bool isFinalized;
        // list of allowed participants
        mapping(address => bool) isCommitteeMember;
        address[] committeeMembers;
        // amount of members
        uint256 activeMemberCount;
        //start time of current phase
        uint256 currentPhaseStartTime;
        //phase of round
        Phase currentPhase;
    }

    // ===  Duration and Delays
    uint256 public immutable COMMIT_DURATION;
    uint256 public immutable REVEAL_DURATION;
    uint256 public immutable REVEAL_DELAY;

    //Mapping Round Number to Round Struct
    mapping(uint256 => Round) public rounds;

    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    function _onlyOwner() internal view {
        require(msg.sender == OWNER, "Only dealer can call");
    }

    modifier onlyCommittee(uint256 _roundId) {
        _onlyCommittee(_roundId);
        _;
    }

    function _onlyCommittee(uint256 _roundId) internal view {
        require(rounds[_roundId].isCommitteeMember[msg.sender], "has to be in committee");
    }

    modifier inPhase(uint256 _roundId, Phase _phase) {
        _inPhase(_roundId, _phase);
        _;
    }

    function _inPhase(uint256 _roundId, Phase _phase) internal view {
        require(rounds[_roundId].currentPhase == _phase, "Invalid phase");
    }

    constructor() {
        OWNER = msg.sender;
        COMMIT_DURATION = 10;
        REVEAL_DURATION = 10;
        REVEAL_DELAY = 10;
    }

    function createRound(address[] calldata committee) external onlyOwner returns (uint256 roundId) {
        maxRoundId++;
        Round storage round = rounds[maxRoundId];

        round.currentPhase = Phase.Commit;
        round.currentPhaseStartTime = block.timestamp;

        for (uint256 i = 0; i < committee.length; i++) {
            round.committeeMembers.push(committee[i]);
            round.isCommitteeMember[committee[i]] = true;
            round.memberStatus[committee[i]] = MemberStatus.None;
        }
        round.activeMemberCount = committee.length;

        return maxRoundId;
    }

    function join(uint256 _roundId) external inPhase(_roundId, Phase.Commit) onlyCommittee(_roundId) {
        Round storage round = rounds[_roundId];
        require(round.memberStatus[msg.sender] == MemberStatus.None, "member can only join once");

        // Make sure there is time left too post the commitment in this round
        require(
            block.timestamp <= round.currentPhaseStartTime + (COMMIT_DURATION / 2), "Too late for joining this round"
        );

        // Add member
        round.memberStatus[msg.sender] = MemberStatus.Active;
        round.activeMemberCount++;
        if (round.activeMemberCount == round.committeeMembers.length) {
            round.currentPhase = Phase.Commit;
            round.currentPhaseStartTime = block.timestamp;
            emit RoundStarted(_roundId);
        }
    }

    // --- Committing a value by an active member ---
    function commit(uint256 _roundId, bytes32 _commitment)
        external
        inPhase(_roundId, Phase.Commit)
        onlyCommittee(_roundId)
    {
        Round storage round = rounds[_roundId];
        require(block.timestamp <= round.currentPhaseStartTime + COMMIT_DURATION, "Time to Commit is over");
        require(_commitment != 0, "Commitment cannot be empty");
        require(!round.hasCommitted[msg.sender], "Member has already committed");

        round.commitments[msg.sender] = _commitment;
        round.hasCommitted[msg.sender] = true;
    }

    // --- Reveal Phase ---
    function startRevealPhase(uint256 _roundId) external inPhase(_roundId, Phase.Commit) onlyOwner {
        Round storage round = rounds[_roundId];
        require(
            block.timestamp > round.currentPhaseStartTime + COMMIT_DURATION + REVEAL_DELAY,
            "We can't start revealing yet"
        );

        round.currentPhase = Phase.Reveal;
        round.currentPhaseStartTime = block.timestamp;
    }

    // --- Reveal value ---
    function reveal(uint256 _roundId, bytes32 _value, bytes32 _salt)
        external
        inPhase(_roundId, Phase.Reveal)
        onlyCommittee(_roundId)
    {
        Round storage round = rounds[_roundId];
        require(block.timestamp <= round.currentPhaseStartTime + REVEAL_DURATION, "Reveal phase is over");

        require(round.hasCommitted[msg.sender], "Member did not commit");
        require(!round.hasRevealed[msg.sender], "Member has already revealed");

        bytes32 commitment = round.commitments[msg.sender];
        //bytes32 calculatedHash = keccak256(abi.encodePacked(_value, _salt));
        bytes32 calculatedHash = optimizedHash(_value, _salt);

        require(calculatedHash == commitment, "Invalid reveal, hash mismatch");

        round.revealedValues[msg.sender] = _value;
        round.hasRevealed[msg.sender] = true;
    }

    function finalizeRound(uint256 _roundId) external inPhase(_roundId, Phase.Reveal) onlyOwner {
        Round storage round = rounds[_roundId];
        require(block.timestamp > round.currentPhaseStartTime + REVEAL_DURATION, "Reveal phase not yet over");

        require(!round.isFinalized, "Round already finalized");

        bytes32 combinedValue = 0;
        uint256 participants = 0;

        for (uint256 i = round.committeeMembers.length; i > 0; i--) {
            uint256 index = i - 1;
            address member = round.committeeMembers[index];

            // 1. Active member did not commit
            if (!round.hasCommitted[member]) {
                _slash(_roundId, member);
            }
            // 2. Active member did not reveal
            else if (!round.hasRevealed[member]) {
                _slash(_roundId, member);
            }
            // 3. Member participated correctly
            else {
                // combinedValue = keccak256(abi.encodePacked(combinedValue, round.revealedValues[member]));
                // Assuming optimizedHash is defined elsewhere in your contract
                combinedValue = optimizedHash(combinedValue, round.revealedValues[member]);
                participants++;
            }
        }

        // Save round results
        round.finalRandomValue = combinedValue;
        round.numParticipants = participants;
        round.isFinalized = true;

        emit RoundFinalized(_roundId, participants, combinedValue);
    }

    function _slash(uint256 _roundId, address _member) internal {
        Round storage round = rounds[_roundId];
        if (round.memberStatus[_member] != MemberStatus.Active) {
            return;
        }

        // 1. Update status and clear deposit
        round.memberStatus[_member] = MemberStatus.Slashed;
        round.activeMemberCount--;

        // 2. Remove from committeeMembers array in O(1)
        _removeMemberFromCommitteeArray(_roundId, _member);

        emit MemberSlashed(_member);
    }

    // --- A Gas-Efficient Way of removing someone from an arry ---
    function _removeMemberFromCommitteeArray(uint256 _roundId, address _member) internal {
        Round storage round = rounds[_roundId];
        uint256 indexToClear = round.memberIndices[_member];
        address lastMember = round.committeeMembers[round.committeeMembers.length - 1];

        // Move the last member into the leaving member's slot
        round.committeeMembers[indexToClear] = lastMember;
        // Update the index of the moved member
        round.memberIndices[lastMember] = indexToClear;

        // Shrink the array
        round.committeeMembers.pop();
        delete round.memberIndices[_member]; // Clear the index of the leaving member
    }

    // Start round with the commit phase
    function _startCommitPhase(uint256 _roundId) external onlyOwner {
        Round storage round = rounds[_roundId];
        round.currentPhase = Phase.Commit;
        round.currentPhaseStartTime = block.timestamp;
        emit RoundStarted(_roundId);
    }

    function finalRandomValue(uint256 roundId) external view returns (bytes32) {
        return rounds[roundId].finalRandomValue;
    }

    function isRoundFinalized(uint256 roundId) external view returns (bool) {
        return rounds[roundId].isFinalized;
    }

    function optimizedHash(bytes32 a, bytes32 b) internal pure returns (bytes32 hashedVal) {
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            hashedVal := keccak256(0x00, 0x40)
        }
    }
}
