🪙 KATEngine - Decentralized Stablecoin Engine
KATEngine is a smart contract-based engine that powers a decentralized over-collateralized stablecoin system using Ethereum-compatible assets like WETH and WBTC. It ensures users can deposit collateral, mint stablecoins (KAT), redeem collateral, and liquidate unhealthy positions—all while maintaining system solvency.

View on Sepolia Etherscan:::https://sepolia.etherscan.io/address/0xb416d5bf32b3662c791852faa0bf34c06189db57#code 

✨ Features
✅ Deposit ETH or BTC as collateral
🏦 Mint KAT stablecoins against deposited collateral
🔥 Burn KAT to redeem your collateral
🧯 Liquidate positions with low health factor
🔗 Chainlink Oracles for real-time price feeds
⛓️ Built using Solidity and OpenZeppelin
📈 Relative Stability: Pegged to the US Dollar 🔁 ETH & BTC to USD Conversion via on-chain logic.
✅ Users must maintain overcollateralization to mint.
✅ Chainlink Price Feeds for real-time data.
🔐 Collateral: Exogenous Crypto Assets
               wETH (Wrapped Ether)
                wBTC (Wrapped Bitcoin)

⚙️ System Design
Over-collateralized: Users must maintain at least 200% collateralization.
Health Factor: Prevents undercollateralized positions.
Liquidation Bonus: Liquidators get a 10% bonus on undercollateralized accounts.
Chainlink Oracles: Used for fetching USD value of ETH/WBTC.

📁 Contracts
KATEngine.sol
Main contract managing:
Collateral deposits
Minting and burning KAT tokens
Liquidations
Health factor calculations

DecentralizedStableCoin.sol
ERC20-compliant contract for the KAT stablecoin, with minting and burning functions restricted to KATEngine.

🔒 Security Features
✅ ReentrancyGuard from OpenZeppelin
❌ Reverts on invalid token or low health factor
⚠️ Emits events for critical state changes

🛠 Tech Stack
🧾 Solidity ^0.8.18
🏗️ OpenZeppelin
🧪 Foundry/Hardhat (choose your test framework)
🔗 Chainlink Price Feeds


📄 License
MIT




//to deploy
forge script script/DeployKAT.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \

  
  --gas-price 10 \
  
