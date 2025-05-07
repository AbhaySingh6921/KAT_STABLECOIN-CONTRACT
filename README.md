#catorgaized of stable coin
```Our stablecoin is going to be:

1. Relative Stability: Anchored or Pegged to the US Dollar
   1. Chainlink Pricefeed
   2. Function to convert ETH & BTC to USD
2. Stability Mechanism (Minting/Burning): Algorithmicly Decentralized
   1. Users may only mint the stablecoin with enough collateral
3. Collateral: Exogenous (Crypto)
   1. wETH
   2. wBTC
```

//to deploy
forge script script/DeployKAT.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \

  
  --gas-price 10 \
  
