// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

// Make sure these paths match your actual file structure in /src
import {BankTreasury} from "../src/BankTreasury.sol";
import {Blackjack} from "../src/BlackjackTable.sol";
import {CommitRevealRandom} from "../src/RNGCoordinator.sol";

// Assuming you still want to deploy the Counter, otherwise you can remove it

contract CasinoScript is Script {
    BankTreasury public bank;
    CommitRevealRandom public rng;
    Blackjack public table;

    function setUp() public {}

    function run() public {
        // Retrieve private key from environment variables (standard Foundry practice)
        // You can also use vm.startBroadcast() without arguments if using default sender
        // uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 deplyerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        // vm.startBroadcast(deployerPrivateKey);
        vm.startBroadcast(deplyerPrivateKey);

        // 1. Deploy the Bank Treasury first (it has no dependencies)
        bank = new BankTreasury();
        console.log("BankTreasury deployed at:", address(bank));

        // 2. Deploy the RNG contract (it has no dependencies)
        rng = new CommitRevealRandom();
        console.log("RNG (CommitRevealRandom) deployed at:", address(rng));


        // ------------------------------------------------------------
        // OPTIONAL: SETUP CONFIGURATION
        // You can perform initial setup here while you are still broadcasting
        // ------------------------------------------------------------

        // Example: Create the first table via the factory
        // params: minBet, maxBet, maxExposure, floatLimit
        table = new Blackjack(
            bank,
            rng
        );

        // Register table in BankTreasury for controlled bankroll exposure
        bank.authorizeTable(address(table), 10 ether, 5 ether);
        console.log("table authorized",address(table));

        vm.stopBroadcast();
    }
}
