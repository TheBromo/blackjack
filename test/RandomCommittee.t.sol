// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/RandomCommittee.sol";

contract RandomCommitteeTest is Test {
    RandomCommittee rc;

    address alice = address(0xA);
    address bob = address(0xB);

    function setUp() public {
        rc = new RandomCommittee(); // msg.sender is owner
        alice = address(0xA);
        bob = address(0xB);
    }

    function testFullRoundFlow() public {
        // CREATE COMMITTEE ARRAY **inside the function**
        address[] memory committee = new address[](2);
        committee[0] = alice;
        committee[1] = bob;
        // Owner creates round
        uint256 roundId = rc.createRound(committee);

        // === JOIN ===
        vm.prank(alice);
        rc.join(roundId);

        vm.prank(bob);
        rc.join(roundId);

        // Prepare commit/reveal values
        bytes32 aliceSalt = keccak256("A");
        bytes32 bobSalt = keccak256("B");

        bytes32 aliceValue = bytes32(uint256(111));
        bytes32 bobValue = bytes32(uint256(222));

        bytes32 aliceCommit = keccak256(abi.encodePacked(aliceValue, aliceSalt));
        bytes32 bobCommit = keccak256(abi.encodePacked(bobValue, bobSalt));

        vm.warp(block.timestamp + 1);

        // — Commit —
        vm.prank(alice);
        rc.commit(roundId, aliceCommit);

        vm.prank(bob);
        rc.commit(roundId, bobCommit);

        // Advance past commit + delay
        vm.warp(block.timestamp + 20);
        rc.startRevealPhase(roundId);

        // — Reveal —
        vm.prank(alice);
        rc.reveal(roundId, aliceValue, aliceSalt);

        vm.prank(bob);
        rc.reveal(roundId, bobValue, bobSalt);

        vm.warp(block.timestamp + 20);
        rc.finalizeRound(roundId);

        assertTrue(rc.isRoundFinalized(roundId));
    }
}
