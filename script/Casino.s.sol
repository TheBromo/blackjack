// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

import {Blackjack} from "../src/BlackjackTable.sol";
import {RandomCommittee} from "../src/RandomCommittee.sol";

contract CasinoScript is Script {
    RandomCommittee public rng;
    Blackjack public table;

    function setUp() public {}

    function run() public {
        // Retrieve private key from environment variables (standard Foundry practice)
        // You can also use vm.startBroadcast() without arguments if using default sender
        // uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        // vm.startBroadcast(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        rng = new RandomCommittee();
        console.log("RNG (CommitRevealRandom) deployed at:", address(rng));

        table = new Blackjack(payable(vm.addr(deployerPrivateKey)), rng);
        console.log("table deployed at:", address(table));

        vm.stopBroadcast();
    }
}
