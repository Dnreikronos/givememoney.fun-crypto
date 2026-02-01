// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {StreamerDonations} from "../src/StreamerDonation.sol";

contract DeployStreamerDonations is Script {
    function run() external returns (StreamerDonations) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        StreamerDonations donations = new StreamerDonations();

        vm.stopBroadcast();

        console.log("StreamerDonations deployed at:", address(donations));

        return donations;
    }
}
