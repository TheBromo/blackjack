// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// import {console} from "forge-std/console.sol";

/**
 * @title CommitReveal2
 * @dev Implementation of the Commit-Reveal^2 DRB Protocol
 * Paper reference: "Secure randomness generation... via Commit-Reveal^2"
 */
contract CommitReveal2 {
    // ==========================================
    // State Variables
    // ==========================================

    enum Phase {
        Commit,
        Reveal1,
        OrderCalculation,
        Reveal2,
        Finished
    }

    struct Participant {
        bool registered;
        bytes32 cv; // Outer commitment: H(co)
        bytes32 co; // Inner commitment: H(s)
        bytes32 s; // Secret
        uint256 dVal; // Scheduling value: H(|Omega_v - cv|)
        bool revealed1; // Flag for first reveal
        bool revealed2; // Flag for second reveal
        uint256 deposit; // Locked funds
    }

    uint256 public constant MIN_DEPOSIT = 0.1 ether;
    // Timeout to allow skipping a user who stalls Reveal2
    uint256 public constant TURN_TIMEOUT = 5 seconds;
    uint256 public immutable COMMIT_DURATION;
    uint256 public immutable REVEAL_DURATION;

    // Time Configuration
    uint256 public commitEndTime;
    uint256 public reveal1EndTime;
    uint256 public reveal2StartTime; // Set after order is submitted

    uint256 public id;
    mapping(uint256 => Round) rounds;

    struct Round {
        mapping(address => Participant) participants;
        mapping(address => bool) isPermitted;
        address[] participantList;
    }

    // Protocol State

    // Ordered list of addresses for Reveal Phase 2
    address[] public revealOrder;
    uint256 public currentRevealIndex;
    uint256 public lastTurnActionTime;

    bytes32 public omega_v; // Intermediate randomness
    bytes32 public omega_o; // Final randomness

    address public immutable registrar;

    // ==========================================
    // Events
    // ==========================================

    event CommitSubmitted(address indexed participant, bytes32 cv);
    event Reveal1Submitted(address indexed participant, bytes32 co);
    event Phase1Finalized(bytes32 omega_v);
    event RevealOrderEstablished(uint256 count);
    event SecretRevealed(address indexed participant, bytes32 s);
    event TurnSkipped(address indexed participant);
    event RandomnessGenerated(bytes32 finalRandomness);

    // ==========================================
    // Modifiers
    // ==========================================

    modifier inPhase(Phase _p) {
        require(getPhase() == _p, "Invalid Phase for this action");
        _;
    }

    modifier onlyRegistrar() {
        require(msg.sender == registrar, "only registrar");
        _;
    }
    // ==========================================
    // Constructor
    // ==========================================

    constructor(uint256 _commitDuration, uint256 _reveal1Duration, address controller) {
        registrar = controller;
        COMMIT_DURATION = _commitDuration;
        REVEAL_DURATION = _reveal1Duration;
    }

    function register(address participant) external onlyRegistrar {
        // console.log("registering address", participant);
        rounds[id].isPermitted[participant] = true;
    }

    function reset(uint256 start) external onlyRegistrar {
        id++;
        commitEndTime = start + COMMIT_DURATION;
        reveal1EndTime = commitEndTime + REVEAL_DURATION;
        //TODO: betting info missing

        currentRevealIndex = 0;
        lastTurnActionTime = 0;

        omega_v = 0; // Intermediate randomness
        omega_o = 0; // Final randomness
        delete revealOrder;
    }

    // ==========================================
    // Helper: Phase Logic
    // ==========================================

    function getPhase() public view returns (Phase) {
        if (block.timestamp < commitEndTime) {
            return Phase.Commit;
        }
        if (block.timestamp < reveal1EndTime) {
            return Phase.Reveal1;
        }
        if (revealOrder.length == 0) {
            // Time for reveal 1 is over, but order hasn't been submitted yet
            return Phase.OrderCalculation;
        }
        if (omega_o == bytes32(0)) {
            return Phase.Reveal2;
        }
        return Phase.Finished;
    }

    // ==========================================
    // 1. Commit Phase
    // ==========================================

    /**
     * @notice Submit outer commitment cv_i = H(co_i)
     */
    function commit(bytes32 _cv) external payable inPhase(Phase.Commit) {
        require(msg.value >= MIN_DEPOSIT, "Insufficient deposit");
        require(!rounds[id].participants[msg.sender].registered, "Already registered");
        require(rounds[id].isPermitted[msg.sender], "not added");
        require(_cv != 0, "cv cant be 0");
        // console.log("comitting,.... ", msg.sender);

        rounds[id].participants[msg.sender] = Participant({
            registered: true,
            cv: _cv,
            co: bytes32(0),
            s: bytes32(0),
            dVal: 0,
            revealed1: false,
            revealed2: false,
            deposit: msg.value
        });

        rounds[id].participantList.push(msg.sender);
        emit CommitSubmitted(msg.sender, _cv);
    }

    // ==========================================
    // 2. Reveal-1 Phase
    // ==========================================

    /**
     * @notice Reveal inner commitment co_i. Verified against cv_i.
     */
    function reveal1(bytes32 _co) external inPhase(Phase.Reveal1) {
        Participant storage p = rounds[id].participants[msg.sender];
        require(rounds[id].isPermitted[msg.sender], "not added");
        require(rounds[id].participants[msg.sender].registered, "not registered");
        require(!p.revealed1, "Already revealed phase 1");

        require(_co != 0, "co cant be 0");
        require(p.cv != 0, "cv cant be 0");
        // Verify: cv_i == H(co_i)
        require(keccak256(abi.encodePacked(_co)) == p.cv, "Invalid commitment reveal");

        p.co = _co;
        p.revealed1 = true;

        emit Reveal1Submitted(msg.sender, _co);
    }

    // ==========================================
    // 3. Intermediate Calculation & Ordering
    // ==========================================

    /**
     * @notice Anyone can call this after Reveal1 time ends.
     * Computes Omega_v and d_i values for valid participants.
     */
    function calculateIntermediateValues() public {
        bytes memory concatenatedCos;

        // 1. Calculate Omega_v from valid reveals only
        for (uint256 i = 0; i < rounds[id].participantList.length; i++) {
            Participant storage p = rounds[id].participants[rounds[id].participantList[i]];
            if (p.revealed1) {
                concatenatedCos = abi.encodePacked(concatenatedCos, p.co);
            }
        }

        // If no one revealed, we can't proceed (Project Failure case)
        require(concatenatedCos.length > 0, "No valid reveals in Phase 1");

        omega_v = keccak256(concatenatedCos);
        emit Phase1Finalized(omega_v);

        // 2. Calculate d_i for all participants
        // di = H(|Omega_v - cv_i|)
        uint256 omegaInt = uint256(omega_v);
        require(omegaInt != 0, "omegaInt cannot be null");

        for (uint256 i = 0; i < rounds[id].participantList.length; i++) {
            Participant storage p = rounds[id].participants[rounds[id].participantList[i]];
            if (p.revealed1) {
                uint256 cvInt = uint256(p.cv);
                require(cvInt != 0, "p.cv cannot be null");
                uint256 diff = omegaInt > cvInt ? omegaInt - cvInt : cvInt - omegaInt;
                p.dVal = uint256(keccak256(abi.encodePacked(diff)));
                require(p.dVal != 0, "p.cv cannot be null");
            }
        }
    }

    /**
     * @notice Submits the calculated reveal order.
     * Gas Optimization: Sorting is done off-chain. Contract only verifies the order.
     * @param _sortedAddresses Array of addresses sorted by d_val descending.
     */
    function submitRevealOrder(address[] calldata _sortedAddresses) external inPhase(Phase.OrderCalculation) {
        // Calculate d_vals first if not done
        if (omega_v == bytes32(0)) {
            calculateIntermediateValues();
        }

        uint256 count = 0;
        uint256 lastDVal = type(uint256).max;

        for (uint256 i = 0; i < _sortedAddresses.length; i++) {
            address addr = _sortedAddresses[i];
            Participant storage p = rounds[id].participants[addr];

            // Filter out those who didn't pass Reveal 1 or fake addresses
            require(p.revealed1, "Address in list did not reveal Phase 1");

            // Verify Descending Sort: d_{i-1} > d_i
            // Note: Ties are extremely rare with Keccak256, but >= allows them
            require(p.dVal <= lastDVal, "List not sorted by dVal descending");

            lastDVal = p.dVal;
            revealOrder.push(addr);
            count++;
        }

        // Ensure we included everyone who successfully revealed in Phase 1
        uint256 totalValidRevealers = 0;
        for (uint256 k = 0; k < rounds[id].participantList.length; k++) {
            if (rounds[id].participants[rounds[id].participantList[k]].revealed1) totalValidRevealers++;
        }
        require(revealOrder.length == totalValidRevealers, "Missing valid participants in order list");

        // Start Reveal 2
        lastTurnActionTime = block.timestamp;
        emit RevealOrderEstablished(count);
    }

    /**
     * @notice Reveal final secret s_i. Must be done in order.
     */
    function reveal2(bytes32 _s) external inPhase(Phase.Reveal2) {
        require(currentRevealIndex < revealOrder.length, "All reveals processed");

        if (block.timestamp >= lastTurnActionTime + TURN_TIMEOUT) {
            skipStalledUser();
        }

        address currentRevealer = revealOrder[currentRevealIndex];
        require(msg.sender == currentRevealer, "Not your turn");

        Participant storage p = rounds[id].participants[msg.sender];

        // Verify: co_i == H(s_i)
        require(keccak256(abi.encodePacked(_s)) == p.co, "Invalid secret reveal");

        p.s = _s;
        p.revealed2 = true;

        // Move to next
        currentRevealIndex++;
        lastTurnActionTime = block.timestamp;

        emit SecretRevealed(msg.sender, _s);

        // Check if finished
        if (currentRevealIndex == revealOrder.length) {
            finalizeProtocol();
        }
    }

    /**
     * @notice Liveness protection. If the current user sleeps, skip them.
     */
    function _skipStalledUser() internal inPhase(Phase.Reveal2) {
        // if (block.timestamp <= lastTurnActionTime + TURN_TIMEOUT) {
        //     return;
        // }
        //
        // address stalledUser = revealOrder[currentRevealIndex];
        //
        // // Slash logic could go here (burn deposit, etc)
        // // participants[stalledUser].deposit = 0;
        //
        // emit TurnSkipped(stalledUser);
        //
        // currentRevealIndex++;
        // lastTurnActionTime = block.timestamp;
        //
        // if (currentRevealIndex == revealOrder.length) {
        //     finalizeProtocol();
        // }
    }

    /**
     * @notice Liveness protection. If the current user sleeps, skip them.
     */
    function skipStalledUser() public inPhase(Phase.Reveal2) {
        require(currentRevealIndex < revealOrder.length, "Nothing to skip");
        require(block.timestamp > lastTurnActionTime + TURN_TIMEOUT, "Turn not timed out");

        address stalledUser = revealOrder[currentRevealIndex];

        // Slash logic could go here (burn deposit, etc)
        // participants[stalledUser].deposit = 0;

        emit TurnSkipped(stalledUser);

        currentRevealIndex++;
        lastTurnActionTime = block.timestamp;

        if (currentRevealIndex == revealOrder.length) {
            finalizeProtocol();
        }
    }

    // ==========================================
    // 5. Finalization
    // ==========================================

    function finalizeProtocol() internal {
        bytes memory concatenatedSecrets;

        // Concatenate only valid secrets
        for (uint256 i = 0; i < revealOrder.length; i++) {
            Participant storage p = rounds[id].participants[revealOrder[i]];
            // If they revealed2 successfully, add their secret
            if (p.revealed2) {
                concatenatedSecrets = abi.encodePacked(concatenatedSecrets, p.s);
            }
        }

        omega_o = keccak256(concatenatedSecrets);
        emit RandomnessGenerated(omega_o);
    }

    function getParticipant() external view returns (Participant memory) {
        return rounds[id].participants[msg.sender];
    }

    function getCurrentRevealer() external view returns (address current) {
        return revealOrder[currentRevealIndex];
    }

    function getParticipantsAndDVals() external view returns (address[] memory addrs, uint256[] memory dVals) {
        Round storage r = rounds[id];
        uint256 len = r.participantList.length;

        addrs = new address[](len);
        dVals = new uint256[](len);

        for (uint256 i = 0; i < len; i++) {
            address participantAddr = r.participantList[i];
            addrs[i] = participantAddr;
            dVals[i] = r.participants[participantAddr].dVal;
        }
    }
}
