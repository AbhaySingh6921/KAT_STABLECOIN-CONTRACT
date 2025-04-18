// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import { DeployKAT } from "../../script/DeployKAT.s.sol";
import { KATEngine } from "../../src/KATEngine.sol";
import { DecentralizedStableCoin } from "../../src/DecentralizedStablecoin.sol";
import { Test, console } from "forge-std/Test.sol";
import{ HelperConfig } from "../../script/HelperConfig.s.sol";
import{ERC20Mock} from"test/mock/ERCMocks.sol";


contract KATEngineTest is Test {
    DeployKAT deployer;
    DecentralizedStableCoin kat;
    KATEngine kate;
    HelperConfig config;
    address weth;
    address wethUsdPriceFeed;


    address public User = makeAddr("User");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    function setUp() public {
        deployer = new DeployKAT();
        (kat, kate,config) = deployer.run();
        (wethUsdPriceFeed, , weth, , ) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(User, STARTING_ERC20_BALANCE);
    }
    /////////////////
// Price Tests //
/////////////////

function testGetUsdValue() public {
    // 15e18 * 2,000/ETH = 30,000e18
    uint256 ethAmount = 15e18;
    uint256 expectedUsd = 30000e18;
    uint256 actualUsd = kate.getUsdValue(weth, ethAmount);
    assertEq(expectedUsd, actualUsd);
 }

  /////////////////////////////
// depositCollateral Tests //
/////////////////////////////

//revert if the user deposit the zero amount of collateral
function testRevertsIfCollateralZero() public {
    vm.startPrank(User);
    ERC20Mock(weth).approve(address(kate), AMOUNT_COLLATERAL);
    //after this it expect the revert for given reson
    vm.expectRevert(KATEngine.KATEngine_MustBeMoreThenZero.selector);
    kate.DepositCollateral(weth, 0);
    vm.stopPrank();
}


}