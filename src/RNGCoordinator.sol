// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract CommitRevealRandom {
    address public dealer;
    uint256 public gameId;
    uint256 public commitDeadline;
    uint256 public revealDeadline;

    enum CRRPhase {
        Setup,
        Commit,
        Reveal,
        Finished
    }
    CRRPhase public phase;

    struct Commitment {
        bytes32 commitHash;
        uint256 randomNumber;
        uint256 secret;
        bool committed;
        bool revealed;
    }

    mapping(uint256 => mapping(address => Commitment)) public commitments;
    mapping(uint256 => address[]) public gamePlayers;
    mapping(uint256 => uint256) public finalRandom;

    event Started(
        uint256 indexed gameId,
        uint256 commitDeadline,
        uint256 revealDeadline
    );
    event Committed(uint256 indexed gameId, address indexed player);
    event Revealed(
        uint256 indexed gameId,
        address indexed player,
        uint256 randomNumber
    );
    event RandomGenerated(uint256 indexed gameId, uint256 randomNumber);

    modifier onlyDealer() {
        require(msg.sender == dealer, "Only dealer can call");
        _;
    }

    modifier inPhase(CRRPhase _phase) {
        require(phase == _phase, "Invalid phase");
        _;
    }

    constructor() {
        dealer = msg.sender;
    }

    /// @notice Start a new game round
    /// @param _commitDuration Time allowed for commits (in seconds)
    /// @param _revealDuration Time allowed for reveals (in seconds)
    function start(
        uint256 _commitDuration,
        uint256 _revealDuration
    ) external onlyDealer inPhase(CRRPhase.Setup) {
        gameId++;
        commitDeadline = block.timestamp + _commitDuration;
        revealDeadline = commitDeadline + _revealDuration;
        phase = CRRPhase.Commit;

        emit Started(gameId, commitDeadline, revealDeadline);
    }

    /// @notice Commit a hash of your random number
    /// @param _commitHash keccak256(abi.encodePacked(randomNumber, secret))
    function commit(
        bytes32 _commitHash,
        uint256 randomNumber
    ) external inPhase(CRRPhase.Commit) {
        require(block.timestamp < commitDeadline, "Commit deadline passed");
        require(
            !commitments[gameId][msg.sender].committed,
            "Already committed"
        );

        commitments[gameId][msg.sender] = Commitment({
            commitHash: _commitHash,
            randomNumber: randomNumber,
            secret: 0,
            committed: true,
            revealed: false
        });

        gamePlayers[gameId].push(msg.sender);

        emit Committed(gameId, msg.sender);
    }

    /// @notice Transition to reveal phase
    function startRevealPhase() external {
        require(block.timestamp >= commitDeadline, "Commit phase not ended");
        require(phase == CRRPhase.Commit, "Not in commit phase");

        phase = CRRPhase.Reveal;
    }

    /// @notice Reveal your committed random number
    /// @param _secret The secret you used in the commit
    function reveal(bytes32 _secret) external inPhase(CRRPhase.Reveal) {
        require(block.timestamp < revealDeadline, "Reveal deadline passed");

        Commitment storage commitment = commitments[gameId][msg.sender];
        require(commitment.committed, "No commitment found");
        require(!commitment.revealed, "Already revealed");

        bytes32 hash = keccak256(
            abi.encodePacked(commitment.randomNumber, _secret)
        );
        require(hash == commitment.commitHash, "Invalid reveal");

        commitment.revealed = true;
        commitment.secret = _secret;

        emit Revealed(gameId, msg.sender, commitment.secret);
    }

    /// @notice Generate final random number from all reveals
    function generateFinalRandom() external inPhase(CRRPhase.Reveal) {
        require(block.timestamp >= revealDeadline, "Reveal phase not ended");

        address[] memory players = gamePlayers[gameId];
        require(players.length > 0, "No players");

        uint256 combinedRandom = 0;
        uint256 revealedCount = 0;

        for (uint256 i = 0; i < players.length; i++) {
            Commitment memory commitment = commitments[gameId][players[i]];
            if (commitment.revealed) {
                combinedRandom ^= commitment.randomNumber;
                revealedCount++;
            }
        }

        require(revealedCount > 0, "No reveals");

        // Add block hash for additional entropy
        combinedRandom ^= uint256(blockhash(block.number - 1));

        finalRandom[gameId] = combinedRandom;
        phase = CRRPhase.Finished;

        emit RandomGenerated(gameId, combinedRandom);
    }

    /// @notice Reset for a new game
    function resetGame() external onlyDealer inPhase(CRRPhase.Finished) {
        phase = CRRPhase.Setup;
    }

    /// @notice Check if an address has revealed for current game
    function hasRevealed(address _player) external view returns (bool) {
        return commitments[gameId][_player].revealed;
    }

    /// @notice Get commitment details for a player
    function getCommitment(
        uint256 _gameId,
        address _player
    )
        external
        view
        returns (
            bytes32 commitHash,
            uint256 randomNumber,
            bool committed,
            bool revealed
        )
    {
        Commitment memory c = commitments[_gameId][_player];
        return (c.commitHash, c.randomNumber, c.committed, c.revealed);
    }
}
