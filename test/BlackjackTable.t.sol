// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BlackjackTable.sol";
import "../src/RandomCommittee.sol";

contract BlackjackTest is Test {
    Blackjack bj;
    RandomCommittee rc;

    address house = address(this); // The test contract acts as the House
    address treasury = address(0x0);
    address alice;
    address bob;

    function setUp() public {
        // 1. Deploy contracts
        rc = new RandomCommittee();
        bj = new Blackjack(payable(treasury), rc);
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        // 2. Fund actors
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);

        // 3. Fund the Blackjack contract (the "Bank") so it can pay out winners
        vm.deal(treasury, 1000 ether);
        vm.deal(address(bj), 1000 ether);
    }

    function test_FullGameFlow_AliceVsDealer() public {
        // === 1. Setup & Join ===
        uint256 gameId = bj.createGame();

        vm.prank(alice);
        bj.joinGame{value: 1 ether}(gameId);

        // === 2. Client Side: Create RNG Round ===
        // The House (this test contract) or a bot usually orchestrates this
        address[] memory committee = bj.getPlayerList(gameId);

        // The TEST contract creates the round, so the TEST contract is the Owner of the round
        uint256 rngId = rc.createRound(committee);

        // Link the RNG round to the Blackjack game
        bj.startCommitPhase(gameId, rngId);

        // === 3. RNG Phase: Commit & Reveal ===
        _playRngFlow(rngId, alice);

        // === 4. Deal Cards ===
        // Now that RNG is finalized, we can deal
        bj.deal(gameId);

        // Check Alice's initial hand
        (Blackjack.Card[] memory cards, uint8 total) = bj.getPlayerHand(gameId, alice);
        console.log("Alice's Hand Total:", total);
        console.log("Card 1:", cards[0].value);
        console.log("Card 2:", cards[1].value);

        // === 5. Player Gameplay ===
        // To ensure the test finishes deterministically without knowing the random seed:
        // We will just STAND immediately.
        // (Hitting might bust depending on randomness).

        // Note: If Alice got a natural Blackjack, she is already marked as BLACKJACK status
        // and doesn't need to stand.
        (Blackjack.PlayerStatus status, uint256 bet) = bj.getPlayerStatus(gameId, alice);
        console.log("Active :", status == Blackjack.PlayerStatus.ACTIVE);

        if (status == Blackjack.PlayerStatus.ACTIVE) {
            vm.prank(alice);
            bj.hit(gameId); // Let's take one risk for the test coverage!

            // Check if she busted
            (status,) = bj.getPlayerStatus(gameId, alice);
            if (status == Blackjack.PlayerStatus.ACTIVE) {
                vm.prank(alice);
                bj.stand(gameId);
            }
        }

        // === 6. Verify Completion ===
        // Once the last player stands/busts, the Dealer plays automatically in the same tx
        (Blackjack.GameState state,,) = bj.getGameInfo(gameId);

        assertTrue(state == Blackjack.GameState.RESOLVED, "Game should be resolved");

        // === 7. Payout Check ===
        // Alice started with 100. Spent 1.
        // If won: > 99. If lost: 99.
        if (alice.balance > 99 ether) {
            console.log("Result: Alice Won! Balance:", alice.balance);
        } else {
            console.log("Result: Alice Lost. Balance:", alice.balance);
        }
    }

    function test_RevertIf_JoinFullGame() public {
        uint256 gameId = bj.createGame();

        // Fill up 7 spots
        for (uint160 i = 1; i <= 7; i++) {
            address p = address(i + 1000);
            vm.deal(p, 2 ether);
            vm.prank(p);
            bj.joinGame{value: 1 ether}(gameId);
        }

        // Try 8th
        vm.prank(alice);
        vm.expectRevert(Blackjack.GameFull.selector);
        bj.joinGame{value: 1 ether}(gameId);
    }

    // ==========================================
    // HELPER: Simulate the Off-Chain Committee behavior
    // ==========================================
    function _playRngFlow(uint256 rngId, address participant) internal {
        // 1. Join
        vm.prank(participant);
        rc.join(rngId);

        // 2. Prepare Commit
        bytes32 salt = keccak256("ALICE_SECRET");
        bytes32 val = bytes32(uint256(12345)); // Alice's random number
        bytes32 commitHash = keccak256(abi.encodePacked(val, salt));

        // Move time forward slightly inside commit phase
        vm.warp(block.timestamp + 10);

        // 3. Commit
        vm.prank(participant);
        rc.commit(rngId, commitHash);

        // 4. Start Reveal Phase
        // Move past commit duration (assuming ~20 seconds in RC)
        vm.warp(block.timestamp + 30);

        // Since "this" (the test) created the round, "this" is the owner and can start reveal
        rc.startRevealPhase(rngId);

        // 5. Reveal
        vm.prank(participant);
        rc.reveal(rngId, val, salt);

        // 6. Finalize
        // Move past reveal duration
        vm.warp(block.timestamp + 30);

        rc.finalizeRound(rngId);

        assertTrue(rc.isRoundFinalized(rngId), "RNG Round should be finalized");
    }
}
