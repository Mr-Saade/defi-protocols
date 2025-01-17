# DeFi Protocol Interaction and Testing

This repository is a project dedicated to experimenting with and testing interactions with popular DeFi protocols such as **Uniswap V2**, **Uniswap V3**, **Curve V1**, and **Curve V2** using **mainnet forking**. The purpose of this project is to explore and understand the core functionalities of these protocols through custom smart contracts and testing scenarios.

---

## Features and Functionalities

### **Uniswap V2**

- **Arbitrage**: Implemented an arbitrage trade using Uniswap V2 pools.
- **Flash Swaps**: Tested flash swap mechanics and use cases.
- **Liquidity Interactions**:
  - Adding liquidity to pools.
  - Removing liquidity and analyzing the behavior of pool reserves.
- **TWAP (Time-Weighted Average Price)**:
  - Tested TWAP price oracles and price stability mechanisms.

### **Uniswap V3**

- **Precision Liquidity**:
  - Interacted with range-bound liquidity and custom tick spacing.
  - Added and removed liquidity within specific price ranges.
- **Multi-Hop Swaps**:
  - Tested path-based multi-hop swaps with different fee tiers.
- **Fee Tier Mechanics**:
  - Explored various fee tiers (e.g., 0.05%, 0.3%, 1%) and their impact on swaps and liquidity.
- **TWAP Testing**:
  - Experimented with TWAP implementation for price feeds and its integration with custom contracts.

### **Curve V1**

- **Liquidity Pools**:
  - Tested stablecoin swaps within Curve V1 pools.
  - Explored the impact of the Amplification (A) parameter on price stability and slippage.
-

### **Curve V2**

- **Volatile Asset Pools**:
  - Interacted with pools supporting volatile assets.
  - Analyzed the impact of dynamic pricing mechanisms on swaps.
- **Liquidity Management**:
  - Added and removed liquidity while testing slippage.

---
