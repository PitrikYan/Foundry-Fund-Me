// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {FundMe} from "../src/FundMe.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployFundMe is Script {
    function run() external returns (FundMe) {
        // Everything before startBroadcast => not "real" TX, just will simulate this on simulated environment and not deployed on real network..
        HelperConfig helperConfig = new HelperConfig();
        (address ethUsdPriceFeed/*, address anotherParameterOfStruct*/) = helperConfig.activeNetworkConfig();

        vm.startBroadcast(); // After startBroadcast => "real" TX, deployed on real network
        //vm.prank(makeAddr("anotherSender")); 
        FundMe fundMe = new FundMe(ethUsdPriceFeed);
        vm.stopBroadcast();
        return fundMe;
    }
}
