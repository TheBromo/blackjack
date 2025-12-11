// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;
//
// import "../lib/forge-std/src/Test.sol";
// import "../src/Setup.sol" as st;
//
// contract SetupTest is Test {
//     address alice;
//     address bob;
//     address house;
//     address verify;
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
//         alice = makeAddr("alice");
//         bob = makeAddr("bob");
//         house = makeAddr("house");
//         verify = makeAddr("verify");
//
//         st.Setup setup = new st.Setup(house, verify);
//     }
//
//     function testFullRoundFlow() public {}
// }
