// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import { DeployKAT } from "../../script/DeployKAT.s.sol";
import { KATEngine } from "../../src/KATEngine.sol";
import { DecentralizedStableCoin } from "../../src/DecentralizedStablecoin.sol";
import { Test, console } from "forge-std/Test.sol";
import{ HelperConfig } from "../../script/HelperConfig.s.sol";
import{ERC20Mock} from"test/mock/ERCMocks.sol";
import {MockV3Aggregator} from "test/mock/Mockv3Aggegator.sol";


contract KATEngineTest is Test {
    DeployKAT deployer;
    DecentralizedStableCoin kat;
    KATEngine kate;

    HelperConfig config;
    address weth;
    address wEthUsdPriceFeed;
    address wBitUsdPriceFeed;

    uint256 AmountCollateral = 10 ether;
     uint256 AmountToMint = 100 ether;


    address public User = makeAddr("User");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    function setUp() public {
        deployer = new DeployKAT();
        (kat, kate,config) = deployer.run();
        (wEthUsdPriceFeed, , weth, , ) = config.activeNetworkConfig();

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

//revert if the User deposit the zero amount of collateral
function testRevertsIfCollateralZero() public {
    vm.startPrank(User);
    ERC20Mock(weth).approve(address(kate), AMOUNT_COLLATERAL);
    //after this it expect the revert for given reson
    vm.expectRevert(KATEngine.KATEngine_MustBeMoreThenZero.selector);
    kate.DepositCollateral(weth, 0);
    vm.stopPrank();
}
   ///////////////////////
    // Constructor Tests //
    ///////////////////////
    address[] public TokenAddresses;
    address[] public FeedAddresses;

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        TokenAddresses.push(weth);
        FeedAddresses.push(wEthUsdPriceFeed);
        FeedAddresses.push(wBitUsdPriceFeed);

   
        vm.expectRevert(KATEngine.KATEngine_TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new KATEngine(TokenAddresses, FeedAddresses, address(kat));
    }

     
    function testGetTokenAmountFromUsd() public {
        // If we want $100 of WETH @ $2000/WETH, that would be 0.05 WETH
        uint256 expectedWeth = 0.05 ether;
        uint256 amountWeth = kate.getTokenAmountFromUsd(weth, 100 ether);
        assertEq(amountWeth, expectedWeth);
    }
     /*✅ What Is This Test Ensuring?
     This test ensures that:
    Your smart contract correctly prevents unauthorized or unapproved tokens from being used as collateral.
    the error handling (custom error KATEngine_TokenNotAllowed) is working as expected.*/


    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock randToken = new ERC20Mock("RAN", "RAN", User, 100e18);
        vm.startPrank(User);
        //this encodeWithSelector is used when error take a argument
        vm.expectRevert(abi.encodeWithSelector(KATEngine.KATEngine_TokenNotAllowed.selector, address(randToken)));
        kate.DepositCollateral(address(randToken), AmountCollateral);
        vm.stopPrank();
    }
     modifier depositedCollateral() {
        vm.startPrank(User);
        ERC20Mock(weth).approve(address(kate), AmountCollateral);
        kate.DepositCollateral(weth, AmountCollateral);
        vm.stopPrank();
        _;
    }/*This test function is verifying that a User can deposit collateral without minting any DSC (your stablecoin) — and it checks that the User's DSC balance remains zero after depositing the collateral.*/
    // Why this is important=>In many DeFi protocols, collateralization and minting are two separate actions:
    function testCanDepositCollateralWithoutMinting() public depositedCollateral {
        uint256 userBalance = kat.balanceOf(User);//check the User balance must be 0
        // Check that the User has no DSC after depositing collateral
        assertEq(userBalance, 0);
    }

     function testCanDepositedCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 TotalKATMinted, uint256 CollateralValueInUsd) = kate._GetAccountInformation(User);
        uint256 expectedDepositedAmount = kate.getTokenAmountFromUsd(weth, CollateralValueInUsd);
        assertEq(TotalKATMinted, 0);
        assertEq(expectedDepositedAmount, AmountCollateral);
    }
     /*
     function testRevertsIfMintedDscBreaksHealthFactor() public {
        (, int256 price,,,) = MockV3Aggregator(wEthUsdPriceFeed).latestRoundData();
        AmountToMint = (AmountCollateral * (uint256(price) * kate.getAdditionalFeedPrecision())) / kate.getPrecision();
        vm.startPrank(User);
        ERC20Mock(weth).approve(address(kate), AmountCollateral);

        uint256 expectedHealthFactor =
            kate.calculateHealthFactor(AmountToMint, kate.getUsdValue(weth, AmountCollateral));
        vm.expectRevert(abi.encodeWithSelector(KATEngine.KATEngine_HealthFactorIsBroken.selector, expectedHealthFactor));
        kate.depositCollateralAndMintDsc(weth, AmountCollateral, AmountToMint);
        vm.stopPrank();
    }
    */
    function testRevertsIfMintAmountIsZero() public {
        vm.startPrank(User);
        ERC20Mock(weth).approve(address(kate), AmountCollateral);
        kate.DepositCollateralAndMintKAT(weth, AmountCollateral, AmountToMint);
        vm.expectRevert(KATEngine.KATEngine_MustBeMoreThenZero.selector);
        kate.MintKAT(0);
        vm.stopPrank();
    }
    function testRevertsIfBurnAmountIsZero() public {
        vm.startPrank(User);
        /*ERC20Mock(weth) creates an interface to interact with your mock WETH token.
        approve(address(kate), AmountCollateral) allows kate contract to take up to AmountCollateral WETH from User.*/
        ERC20Mock(weth).approve(address(kate), AmountCollateral);
        kate.DepositCollateralAndMintKAT(weth, AmountCollateral, AmountToMint);
        vm.expectRevert(KATEngine.KATEngine_MustBeMoreThenZero.selector);
        kate.BurnKAT(0);
        vm.stopPrank();
    }

    function testCantBurnMoreThanUserHas() public {
        vm.prank(User); // Make all following calls come from `User`
        vm.expectRevert(); // Expect any revert (not specific here)
        kate.BurnKAT(1); // Try to burn 1 KAT token
    }
    /*
    function testRevertsIfRedeemAmountIsZero() public {
        vm.startPrank(User);
        ERC20Mock(weth).approve(address(kate), AmountCollateral);
        kate.DepositCollateralAndMintKAT(weth, AmountCollateral, AmountToMint);
        vm.expectRevert(KATEngine.KATEngine_MustBeMoreThenZero.selector);
        kate.RedeemCollateral(weth, 0);
        vm.stopPrank();
    }
    

    function testCanRedeemDepositedCollateral() public {
        vm.startPrank(User);
        ERC20Mock(weth).approve(address(kate), AmountCollateral);
        kate.DepositCollateralAndMintKAT(weth, AmountCollateral, AmountToMint);
        kat.approve(address(kate), AmountToMint);
        kate.RedeemCollateralForKAT(weth, AmountCollateral, AmountToMint);
        vm.stopPrank();
        
        uint256 userBalance = kat.balanceOf(User);
        assertEq(userBalance, 0);
    }
    */




}