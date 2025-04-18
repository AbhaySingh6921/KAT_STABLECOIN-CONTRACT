/*so why we use this 
because in deplaoyment we need array of tokenaddress and pricefeedaddresses
so here we build the helper function so we can provide 
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;
import { Script } from "forge-std/Script.sol";
import{MockV3Aggregator} from"test/mock/Mockv3Aggegator.sol";//for fake pricefeed
 import {ERC20Mock} from "test/mock/ERCMocks.sol";//for fake token

contract HelperConfig is Script {
    //make a predifined data type which is used in the function
    struct NetworkConfig{
        address wethUsdPriceFeed;
        address wbitUsdPriceFeed;
        address weth;
        address wbit;
        uint256 DeployerKey;
    }
    NetworkConfig public activeNetworkConfig;

    ////////state variable//////////////// 
    uint8  public constant DECIMALS=8;
    uint256 public constant ETH_USD_PRICE=2000e8;
    uint256 public constant BIT_USD_PRICE=1000e8;
    uint256 public constant DEFAULT_ANVIL_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    constructor() {
    if(block.chainid == 11155111){
        activeNetworkConfig = _GetSepoliaEthConfig();
    } else{
        activeNetworkConfig = _GetOrCreateAnvilEthConfig();
    }
}


    //let write a function and palced the data in the function
    function _GetSepoliaEthConfig() public view returns (NetworkConfig memory SepoliaNetworkConfig) {
    SepoliaNetworkConfig = NetworkConfig({
        wethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306, // ETH / USD
        wbitUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
        weth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
        wbit: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            DeployerKey: vm.envUint("PRIVATE_KEY")
        });
    }



     /*
    Why It’s Needed
    To test your protocol locally, you need tokens and price feeds.
     This function mocks everything you'd normally 1=>get on-chain:Chainlink price feeds 2=>.ERC20 tokens like WETH/WBTC
    */
    function _GetOrCreateAnvilEthConfig() public returns (NetworkConfig memory anvilNetworkConfig) {
    // If activeNetworkConfig already has a WETH price feed, no need to create it again — just return the config.
    if (activeNetworkConfig.wethUsdPriceFeed != address(0)) {
        return activeNetworkConfig;
    }
    //if not then create everything using mocks

    vm.startBroadcast(); 
    //Mocks the ETH/USD price feed (e.g. $2000 ETH). You can test how your app reacts to this price.   
    MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(DECIMALS, int256(ETH_USD_PRICE));
    //Mints fake WETH  to your wallet, so you can simulate deposits/collateral in your local tests.
    ERC20Mock wethMock = new ERC20Mock("WETH", "WETH", msg.sender, 1000e8);

    MockV3Aggregator btcUsdPriceFeed = new MockV3Aggregator(DECIMALS, int256(BIT_USD_PRICE));
    ERC20Mock wbtcMock = new ERC20Mock("WBTC", "WBTC", msg.sender, 1000e8);
    vm.stopBroadcast();

    anvilNetworkConfig = NetworkConfig({
         wethUsdPriceFeed: address(ethUsdPriceFeed), // ETH / USD
        weth: address(wethMock),
        wbitUsdPriceFeed: address(btcUsdPriceFeed),
         wbit: address(wbtcMock),
        DeployerKey: DEFAULT_ANVIL_PRIVATE_KEY
    });
    }
}
