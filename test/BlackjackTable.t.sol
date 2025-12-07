// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;
//
// import {console} from "forge-std/console.sol";
// import "forge-std/Test.sol";
// import "../src/Blackjack.sol";
// import "../src/CommitRevealRandom.sol";
//
// contract BlackjackTest is Test {
//     receive() external payable {}
//     address alice;
//     address bob;
//     Blackjack bj;
//     CommitRevealRandom crr;
//
//     function setUp() public {
//         bj = new Blackjack();
//         crr = bj.RNG();
//         alice = makeAddr("alice");
//         vm.deal(alice, 100 ether);
//         bob = makeAddr("bob");
//         vm.deal(bob, 200 ether);
//     }
//
//     function testFullRound() public {
//         bj.createGame();
//         uint256 id = bj.currentGame();
//
//         vm.prank(bob);
//         bj.bet{value: 100 ether}();
//
//         vm.prank(alice);
//         bj.bet{value: 10 ether}();
//
//         vm.warp(block.timestamp + bj.BETTING_DURATION());
//         bj.generateSeed();
//         rngRound();
//         bj.deal();
//
//         vm.prank(bob);
//         bj.stand();
//
//         vm.prank(alice);
//         bj.hit();
//         vm.warp(block.timestamp + bj.ROUND_DURATION());
//
//         bj.generateSeed();
//         rngRound();
//         bj.dealActions();
//     }
//
//     function testFeeTransfer() public {
//         bj.createGame();
//         uint256 id = bj.currentGame();
//
//         address house = bj.HOUSE();
//         uint256 before = house.balance;
//         vm.prank(bob);
//         bj.bet{value: 100 ether}();
//
//         uint256 expectedFee = (100 ether * bj.FEE_PERCENT()) / 100;
//
//         assertEq(house.balance - before, expectedFee);
//     }
//
//     function rngRound() internal {
//         // Prepare commit/reveal values
//         bytes32 aliceSalt = keccak256("A");
//         console.logBytes32(aliceSalt);
//         bytes32 bobSalt = keccak256("B");
//         bytes32 houseSalt = keccak256("C");
//
//         bytes32 aliceValue = bytes32(uint256(111));
//         console.logBytes32(aliceValue);
//         bytes32 bobValue = bytes32(uint256(224));
//         bytes32 houseValue = bytes32(uint256(333));
//
//         bytes32 aliceCommit = keccak256(abi.encodePacked(aliceValue, aliceSalt));
//         console.logBytes32(aliceCommit);
//         bytes32 bobCommit = keccak256(abi.encodePacked(bobValue, bobSalt));
//         bytes32 houseCommit = keccak256(abi.encodePacked(houseValue, houseSalt));
//
//         uint256 roundId = bj.currentRNG();
//
//         vm.warp(block.timestamp + 1);
//
//         // — Commit —
//         vm.prank(alice);
//         crr.commit(roundId, aliceCommit);
//
//         vm.prank(bob);
//         crr.commit(roundId, bobCommit);
//
//         crr.commit(roundId, houseCommit);
//
//         // Advance past commit + delay
//         vm.warp(block.timestamp + bj.SEEDING_DURATION() - 10);
//
//         // — Reveal —
//         //TODO: not revealing correclty
//         vm.prank(alice);
//         crr.reveal(roundId, aliceValue, aliceSalt);
//
//         vm.prank(bob);
//         crr.reveal(roundId, bobValue, bobSalt);
//
//         crr.reveal(roundId, houseValue, houseSalt);
//
//         vm.warp(block.timestamp + bj.SEEDING_DURATION() / 4);
//
//         vm.warp(block.timestamp + bj.SEEDING_DURATION() / 2);
//     }
// }
