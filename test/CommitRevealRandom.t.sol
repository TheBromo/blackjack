// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CommitRevealRandom.sol";

contract CommitRevealRandomTest is Test {
    CommitRevealRandom crr;

    address alice = address(0xA);
    address bob = address(0xB);
    uint256 commitduration = 30;
    uint256 revealduration = 30;

    function setUp() public {
        crr = new CommitRevealRandom(); // msg.sender is owner
        alice = address(0xA);
        bob = address(0xB);
    }

    function testFullRoundFlow() public {
        // CREATE COMMITTEE ARRAY **inside the function**
        address[] memory committee = new address[](2);
        committee[0] = alice;
        committee[1] = bob;
        // Owner creates round
        uint256 roundId = crr.createRound(committee, commitduration, revealduration);

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
        crr.commit(roundId, aliceCommit);

        vm.prank(bob);
        crr.commit(roundId, bobCommit);

        // Advance past commit + delay
        vm.warp(block.timestamp + commitduration);

        // — Reveal —
        vm.prank(alice);
        crr.reveal(roundId, aliceValue, aliceSalt);

        vm.prank(bob);
        crr.reveal(roundId, bobValue, bobSalt);

        vm.warp(block.timestamp + revealduration);
        crr.finalizeRandomness(roundId);

        assertTrue(crr.isFinalized(roundId));
    }
}
