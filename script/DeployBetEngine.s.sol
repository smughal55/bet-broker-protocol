// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {BetEngine} from "../src/BetEngine.sol";
import {Vault} from "../src/Vault.sol";

contract DeployBetEngine is Script {
    address public tokenAddress;
    address public priceFeedAddress;

    function run() external returns (Vault, BetEngine, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();

        (, address wbtcUsdPriceFeed,,, address usdc, uint256 deployerKey) = helperConfig.activeNetworkConfig();
        tokenAddress = usdc;
        priceFeedAddress = wbtcUsdPriceFeed;

        vm.startBroadcast(deployerKey);
        Vault vault = new Vault(tokenAddress);
        BetEngine betEngine = new BetEngine(
            priceFeedAddress,
            address(vault)
        );
        vault.transferOwnership(address(betEngine));
        vm.stopBroadcast();
        return (vault, betEngine, helperConfig);
    }
}
