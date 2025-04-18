// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Script } from "forge-std/Script.sol";
import { DecentralizedStableCoin } from "../src/DecentralizedStablecoin.sol";
import{KATEngine} from "../src/KATEngine.sol";
import{HelperConfig} from "./HelperConfig.s.sol";


contract DeployKAT is Script {

    address[] public TokenAddresses;
    address[]public PriceFeedAddresses;

    function run() external returns (DecentralizedStableCoin, KATEngine,HelperConfig) {
        HelperConfig config=new HelperConfig();
        (address wethUsdPriceFeed, address wbitUsdPriceFeed, address weth, address wbit, uint256 DeployerKey) = config.activeNetworkConfig();

        TokenAddresses=[weth,wbit];
        PriceFeedAddresses=[wethUsdPriceFeed,wbitUsdPriceFeed];
        vm.startBroadcast();
        DecentralizedStableCoin kat = new DecentralizedStableCoin();
        KATEngine engine = new KATEngine(TokenAddresses, PriceFeedAddresses, address(kat));
        kat.transferOwnership(address(engine));//by default ower of this is goes to caller of this funcrion so we transfer the owenrship to engine
        vm.stopBroadcast();   
        return (kat,engine,config);
    }
}