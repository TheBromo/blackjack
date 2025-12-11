// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;
//
// import "../lib/forge-std/src/Test.sol";
// import "../src/CRR2.sol";
//
// contract CommitReveal2Test is Test {
//     CommitReveal2 cr2;
//
//     address alice;
//     address bob;
//
//     // Test Durations
//     uint256 commitDuration = 1 hours;
//     uint256 reveal1Duration = 1 hours;
//
//     // Test Data storage
//     bytes32 sAlice; // Secret
//     bytes32 coAlice; // Inner Commit
//     bytes32 cvAlice; // Outer Commit
//
//     bytes32 sBob;
//     bytes32 coBob;
//     bytes32 cvBob;
//
//     function setUp() public {
//         // 1. Deploy Contract
//         cr2 = new CommitReveal2(commitDuration, reveal1Duration);
//
//         // 2. Setup Users
//         alice = makeAddr("alice");
//         bob = makeAddr("bob");
//
//         // 3. Register Users (onlyRegistrar is the test contract/deployer)
//         cr2.register(alice);
//         cr2.register(bob);
//
//         // 4. Fund Users
//         vm.deal(alice, 10 ether);
//         vm.deal(bob, 10 ether);
//
//         // 5. Generate Secrets and Commitments
//         // Alice Data
//         sAlice = keccak256(abi.encodePacked("Secret123"));
//         coAlice = keccak256(abi.encodePacked(sAlice));
//         cvAlice = keccak256(abi.encodePacked(coAlice));
//
//         // Bob Data
//         sBob = keccak256(abi.encodePacked("Secret456"));
//         coBob = keccak256(abi.encodePacked(sBob));
//         cvBob = keccak256(abi.encodePacked(coBob));
//     }
//
//     function testFullRoundFlow() public {
//         // ==========================================
//         // 1. Commit Phase
//         // ==========================================
//
//         vm.prank(alice);
//         cr2.commit{value: 0.1 ether}(cvAlice);
//
//         vm.prank(bob);
//         cr2.commit{value: 0.1 ether}(cvBob);
//
//         // Move past commit duration
//         vm.warp(block.timestamp + commitDuration + 1);
//
//         // ==========================================
//         // 2. Reveal 1 Phase (Inner Commitment)
//         // ==========================================
//
//         vm.prank(alice);
//         cr2.reveal1(coAlice);
//
//         vm.prank(bob);
//         cr2.reveal1(coBob);
//
//         // Move past reveal1 duration
//         vm.warp(block.timestamp + reveal1Duration + 1);
//
//         // ==========================================
//         // 3. Order Calculation Phase
//         // ==========================================
//
//         // We need to calculate the correct order off-chain (in test)
//         // to submit it to the contract.
//
//         // A. Calculate expected Omega_v
//         // Note: Contract loops through participantList. Alice pushed first, then Bob.
//         bytes32 expectedOmegaV = keccak256(abi.encodePacked(coAlice, coBob));
//
//         // B. Calculate dVals
//         uint256 omegaInt = uint256(expectedOmegaV);
//
//         // Alice dVal
//         uint256 cvIntA = uint256(cvAlice);
//         uint256 diffA = omegaInt > cvIntA ? omegaInt - cvIntA : cvIntA - omegaInt;
//         uint256 dValAlice = uint256(keccak256(abi.encodePacked(diffA)));
//
//         // Bob dVal
//         uint256 cvIntB = uint256(cvBob);
//         uint256 diffB = omegaInt > cvIntB ? omegaInt - cvIntB : cvIntB - omegaInt;
//         uint256 dValBob = uint256(keccak256(abi.encodePacked(diffB)));
//
//         // C. Create Sorted Array (Descending Order)
//         address[] memory sortedOrder = new address[](2);
//
//         if (dValAlice >= dValBob) {
//             sortedOrder[0] = alice;
//             sortedOrder[1] = bob;
//         } else {
//             sortedOrder[0] = bob;
//             sortedOrder[1] = alice;
//         }
//
//         // Submit the order (anyone can call this)
//         cr2.submitRevealOrder(sortedOrder);
//
//         // Verify state moved to Reveal2
//         assertTrue(uint256(cr2.getPhase()) == 3); // 3 corresponds to Phase.Reveal2
//
//         // ==========================================
//         // 4. Reveal 2 Phase (Secrets)
//         // ==========================================
//
//         // We must reveal in the specific order determined above
//         for (uint256 i = 0; i < sortedOrder.length; i++) {
//             address currentUser = sortedOrder[i];
//
//             if (currentUser == alice) {
//                 vm.prank(alice);
//                 cr2.reveal2(sAlice);
//             } else {
//                 vm.prank(bob);
//                 cr2.reveal2(sBob);
//             }
//         }
//
//         // ==========================================
//         // 5. Final Checks
//         // ==========================================
//
//         // Phase should be Finished (4)
//         assertTrue(uint256(cr2.getPhase()) == 4);
//
//         // Verify randomness was generated
//         bytes32 finalRandomness = cr2.omega_o();
//         assertTrue(finalRandomness != bytes32(0), "Final randomness should not be zero");
//
//         // Verify calculation logic for final randomness matches
//         // It should be the hash of concatenated secrets in the reveal order
//         bytes32 expectedFinal;
//         if (sortedOrder[0] == alice) {
//             expectedFinal = keccak256(abi.encodePacked(sAlice, sBob));
//         } else {
//             expectedFinal = keccak256(abi.encodePacked(sBob, sAlice));
//         }
//
//         assertEq(finalRandomness, expectedFinal, "On-chain randomness matches expectation");
//     }
// }
