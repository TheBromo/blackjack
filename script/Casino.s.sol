// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

// Make sure these paths match your actual file structure in /src
import {BankTreasury} from "../src/BankTreasury.sol";
import {CommitRevealRandom} from "../src/RNGCoordinator.sol";
import {BlackjackTableFactory} from "../src/BlackjackTableFactory.sol";

// Assuming you still want to deploy the Counter, otherwise you can remove it

contract CasinoScript is Script {
    BankTreasury public bank;
    CommitRevealRandom public rng;
    BlackjackTableFactory public factory;

    function setUp() public {}

    function run() public {
        // Retrieve private key from environment variables (standard Foundry practice)
        // You can also use vm.startBroadcast() without arguments if using default sender
        // uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        // vm.startBroadcast(deployerPrivateKey);
        vm.startBroadcast();

        // 1. Deploy the Bank Treasury first (it has no dependencies)
        bank = new BankTreasury();
        console.log("BankTreasury deployed at:", address(bank));

        // 2. Deploy the RNG contract (it has no dependencies)
        rng = new CommitRevealRandom();
        console.log("RNG (CommitRevealRandom) deployed at:", address(rng));

        // 3. Deploy the Factory
        // The factory constructor requires: (address payable _bank, address _rng)
        factory = new BlackjackTableFactory(
            payable(address(bank)),
            address(rng)
        );
        console.log("BlackjackTableFactory deployed at:", address(factory));

        // ------------------------------------------------------------
        // OPTIONAL: SETUP CONFIGURATION
        // You can perform initial setup here while you are still broadcasting
        // ------------------------------------------------------------

        // Example: Create the first table via the factory
        // params: minBet, maxBet, maxExposure, floatLimit
        address newTable = factory.createTable(
            0.01 ether, // Min Bet
            1 ether, // Max Bet
            10 ether, // Max Exposure
            5 ether // Float Limit
        );
        console.log("Initial BlackjackTable deployed at:", newTable);

        vm.stopBroadcast();
    }
}
