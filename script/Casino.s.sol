pragma solidity ^0.8.20;
import {Script, console} from "forge-std/Script.sol";
import {BlackjackController} from "../src/Controller.sol";

contract CasinoScript is Script {
    BlackjackController public ctl;

    function run() public {
        // DEFAULT ANVIL KEY (Account #0)
        // Only use this for local testing!
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

        vm.startBroadcast(deployerPrivateKey);

        ctl = new BlackjackController();
        console.log("table deployed at:", address(ctl));

        vm.stopBroadcast();
    }
}
