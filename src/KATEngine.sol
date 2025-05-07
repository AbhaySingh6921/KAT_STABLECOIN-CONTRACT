pragma solidity ^0.8.18;
import {DecentralizedStableCoin} from "src/DecentralizedStablecoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { AggregatorV3Interface } from "lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";


contract KATEngine is ReentrancyGuard {
    //*******error******* */ */
    error KATEngine_MustBeMoreThenZero();//modifier
    error KATEngine_TokenAddressesAndPriceFeedAddressesMustBeSameLength();//modifier
    error KATEngine_TokenNotAllowed( address token);//modifier
    error KATEngine_TransferFailed();//depositCollateral function
    error KATEngine_HealthFactorIsBroken(uint256 healthFactor);//_revertIfHealthFactorIsBroken function in mint function
    error KATEngine_MintFailed();//mintKAT function
    error KATEngine_HealthFactorOk();//liquidate function
    error KATEngine_HealthFactorNotImproved();//liquidate function




     /********************statevarible************ **/
    mapping(address Token=>address pricefeed) private s_PriceFeeds;//this mapps with our token(eth,btc) and the pricefeed address(give real life price)
    DecentralizedStableCoin private immutable i_KAT;
    mapping(address User=>mapping(address Token=>uint256 Amount )) private s_CollateralDeposited; //this tracks the collateral desposited by the user
    mapping(address User=>uint256 AmountKATToMint) private s_KATMinted; //this tracks the amount of KAT minted by the user
    address[] private s_CollateralTokens;//arr of token(eth,bit) address
    


    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    /*set at `50`, will assure a user's position is `200%` `over-collateralized`.&#x20;
    `LIQUIDATION_PRECISION` constant for use in our calculation
    */
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR=1e18;
    uint256 private constant LIQUIDATION_BONUS = 10;




    /*****************events*************** */
    event CollateralDeposited(address indexed user, address indexed tokenCollateralAddress, uint256 amountCollateral);
    event CollateralRedeemed(address indexed RedeemedFrom, address indexed RedeemedTo, address indexed token, uint256  amount);



    //**********Modifier************ */
    modifier MoreThenZero(uint256 Amount) {
        if (Amount <= 0) {
            revert KATEngine_MustBeMoreThenZero();
        }
        _;
    }
    //this modifier checks if the token is allowed to be used as collateral since we use eth,bitcoin
    //so we need to use mapping 
    modifier IsAllowedToken(address Token){
        if (s_PriceFeeds[Token] == address(0)) {
            revert KATEngine_TokenNotAllowed(Token);
        }
        _;
    }



   
    
    
    
    
    /****************constructor****************** */
    //here tokenAddress=[weth,wbit] and pricefeedAddress=[weth pricefeed,wbtc pricefeed] and dscAddress=address of KAT
    //this all does for IsallowedToken modifier
    constructor(address[] memory TokenAddresses, address[] memory PriceFeedAddresses, address KATAddress){
        //
        if(TokenAddresses.length != PriceFeedAddresses.length){
            revert KATEngine_TokenAddressesAndPriceFeedAddressesMustBeSameLength();
        }
        //this mapp two list of address with each other(tokenAddress and pricefeedAddress)
        for(uint256 i=0; i < TokenAddresses.length; i++){
            s_PriceFeeds[TokenAddresses[i]] = PriceFeedAddresses[i];
            s_CollateralTokens.push(TokenAddresses[i]);
        }
         i_KAT = DecentralizedStableCoin(KATAddress);
    }
    //this functio deposits the collateral and mints the dsc
    //it will be called by the user
    /*
 * @param tokenCollateralAddress: the address of the token to deposit as collateral
 * @param amountCollateral: The amount of collateral to deposit
 * @param amountDscToMint: The amount of DecentralizedStableCoin to mint
 * @notice: This function will deposit your collateral and mint DSC in one transaction
 */
  
    function DepositCollateralAndMintKAT(address TokenCollateralAddress, uint256 AmountCollateral, uint256 AmountKATToMint) external {
         DepositCollateral(TokenCollateralAddress, AmountCollateral);
         MintKAT(AmountKATToMint);
    }
    /*
 * @param tokenCollateralAddress: The ERC20 token address of the collateral you're depositing
 * @param amountCollateral: The amount of collateral you're depositing
 */
    function 
    DepositCollateral(address TokenCollateralAddress, uint256 AmountCollateral) public MoreThenZero(AmountCollateral) IsAllowedToken(TokenCollateralAddress) nonReentrant(){
        s_CollateralDeposited[msg.sender][TokenCollateralAddress] += AmountCollateral;
        //if changing of balance happen so we use the events to take the data
        emit CollateralDeposited(msg.sender, TokenCollateralAddress, AmountCollateral);
        //IERC20 is use as interface or to interact the erc20 token we use IRC20
        //this transfer the token from user to this contract
       bool succes= IERC20(TokenCollateralAddress).transferFrom(msg.sender, address(this), AmountCollateral);
       if(!succes){
        revert KATEngine_TransferFailed();
       }
    }


   /*
 * @param tokenCollateralAddress: the collateral address to redeem
 * @param amountCollateral: amount of collateral to redeem
 * @param amountDscToBurn: amount of DSC to burn
 * This function burns DSC and redeems underlying collateral in one transaction
 */
function RedeemCollateralForKAT(address TokenCollateralAddress, uint256 AmountCollateral, uint256 AmountKATToBurn) external {
    _BurnKAT(AmountKATToBurn, msg.sender, msg.sender);
    RedeemCollateral(TokenCollateralAddress, AmountCollateral, msg.sender, msg.sender);
}
    //The user would first need to burn their `DSC` to release their collateral

    function RedeemCollateral(address TokenCollateralAddress,uint256 AmountCollateral,address from ,address to) public MoreThenZero(AmountCollateral) nonReentrant{
        s_CollateralDeposited[from][TokenCollateralAddress]-=AmountCollateral;
        emit CollateralRedeemed(from ,to, TokenCollateralAddress, AmountCollateral);
        bool success = IERC20(TokenCollateralAddress).transfer(to, AmountCollateral);
        //this transfer the token from this contract to user
        if(!success){
           revert KATEngine_TransferFailed();
        }
        _RevertIfHealthFactorIsBroken(msg.sender);

    }

    function _BurnKAT(uint256 AmountKATToBurn, address OnBehalfOf, address KATFrom) internal MoreThenZero(AmountKATToBurn) {
        s_KATMinted[OnBehalfOf]-= AmountKATToBurn;
       
        bool succes=i_KAT.transferFrom(KATFrom,address(this), AmountKATToBurn);
        if(!succes){
            revert KATEngine_TransferFailed();
        }
        //now burn the token
        i_KAT.burn( AmountKATToBurn);
    }
    function BurnKAT(uint256 Amount)  external MoreThenZero(Amount){
         _BurnKAT(Amount, msg.sender, msg.sender);
        _RevertIfHealthFactorIsBroken(msg.sender);
    }
    /*
    * @param amountKATToMint: The amount of KAT you want to mint
    * You can only mint DSC if you hav enough collateral
    */
    function MintKAT(uint256 AmountKATToMint) public MoreThenZero(AmountKATToMint) nonReentrant{
        s_KATMinted[msg.sender]+=AmountKATToMint;
        _RevertIfHealthFactorIsBroken(msg.sender);
        //if above function doen't revert then its time to mint
        bool minted=i_KAT.mint(msg.sender,AmountKATToMint);
        if(!minted){
            revert KATEngine_MintFailed();
        }
    }



                        ///////////////////////// //////////////////
                        //internal function for mintKAT function/////
                         /////////////////////////////////////////// 

    /*
    * Returns how close to liquidation a user is
    * If a user goes below 1, then they can be liquidated.
    */
   //health factor depend upon 1. Total DSC minted .2. Total Collateral value;
   //mathmatically exaple for the health factor;
   /*(150 * 50) / 100 = 75
    return (75 * 1e18) / 100e18
    return (0.75)
    */

   function _HealthFactor(address user) private view returns (uint256) {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _GetAccountInformation(user);
        return _calculateHealthFactor(totalDscMinted, collateralValueInUsd);
    }
    //if the health factor is less than 1 then the user is in liquidation
    function _RevertIfHealthFactorIsBroken(address User) internal view {
        uint256 healthFactor=_HealthFactor(User);
        if(healthFactor<MIN_HEALTH_FACTOR){
            revert KATEngine_HealthFactorIsBroken(healthFactor);
        }
    }
    function _GetAccountInformation(address User) public view returns(uint256 TotalKATMinted,uint256 CollateralValueInUsd) {
        TotalKATMinted = s_KATMinted[User];
        CollateralValueInUsd = GetAccountCollateralValue(User);
    }
    function GetAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        for(uint256 i = 0; i < s_CollateralTokens.length; i++){
           address token = s_CollateralTokens[i];
           uint256 amount = s_CollateralDeposited[user][token];
           totalCollateralValueInUsd += getUsdValue( token,  amount);
        }
        return totalCollateralValueInUsd;
    }
    function getUsdValue(address Token, uint256 Amount) public view returns(uint256){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_PriceFeeds[Token]);
        (,int256 price,,,) = priceFeed.latestRoundData();
          return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * Amount) / PRECISION;
    }
    function _calculateHealthFactor(
        uint256 totalKATMinted,
        uint256 collateralValueInUsd
    )
        internal
        pure
        returns (uint256)
    {
        if (totalKATMinted == 0) return type(uint256).max;
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalKATMinted;
    }

                ////////////////////////////// ////
                /////end of mintKat function///////// 
                ////////////////////////H///////////
    // this is the case when the user is in liquidation
    function liquidate(address Collateral, address User, uint256 DebtToCover) external MoreThenZero(DebtToCover) nonReentrant {
        uint256 StartingUserHealthFactor = _HealthFactor(User);
            if(StartingUserHealthFactor > MIN_HEALTH_FACTOR){
               revert KATEngine_HealthFactorOk();
            }
        //This line calculates how much of the collateral token the liquidator should receive in exchange for covering the user's debt.
         uint256 TokenAmountFromDebtCovered = getTokenAmountFromUsd(Collateral, DebtToCover);
        //Liquidators get a reward for liquidating — like 5% bonus.
         uint256 BonusCollateral = (TokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
         //This is the final amount of collateral the liquidator will receive.
         uint256 TotalCollateralRedeemed = TokenAmountFromDebtCovered + BonusCollateral;
         //This line updates the user's collateral balance by subtracting the amount of collateral being redeemed.in case of liquidation
         RedeemCollateral(Collateral, TotalCollateralRedeemed, User, msg.sender);
         //this line burns the user's KAT to cover the debt.
         _BurnKAT(DebtToCover, User, msg.sender);
         uint256 endingUserHealthFactor = _HealthFactor(User);
         //If the `liquidation` somehow doesn't result in the user's `Health Factor` improving, we should revert

        if(endingUserHealthFactor <= StartingUserHealthFactor){
             revert KATEngine_HealthFactorNotImproved();
}
    }   
    //////////////////////////////////////////
//   Public & liquidator Functions   //
//////////////////////////////////////////

function getTokenAmountFromUsd(address Token, uint256 UsdAmountInWei) public view returns (uint256) {
    AggregatorV3Interface priceFeed = AggregatorV3Interface(s_PriceFeeds[Token]);
    (, int256 price,,,) = priceFeed.latestRoundData();
    //Converts USD amount to token amount using the price feed.
    return (UsdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
}

    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }
    

    function getAdditionalFeedPrecision() external pure returns (uint256) {
        return ADDITIONAL_FEED_PRECISION;
    }

    function getLiquidationThreshold() external pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    function getLiquidationBonus() external pure returns (uint256) {
        return LIQUIDATION_BONUS;
    }

    function getLiquidationPrecision() external pure returns (uint256) {
        return LIQUIDATION_PRECISION;
    }

    function getMinHealthFactor() external pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return s_CollateralTokens;
    }

    function getKAT() external view returns (address) {
        return address(i_KAT);
    }

    function getCollateralTokenPriceFeed(address token) external view returns (address) {
        return s_PriceFeeds[token];
    }

    function getHealthFactor(address user) external view returns (uint256) {
        return _HealthFactor(user);
    }

     function getCollateralBalanceOfUser(address user, address token) external view returns (uint256) {
        return s_CollateralDeposited[user][token];
    }

    


}