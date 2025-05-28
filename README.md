# Investment NFT Gacha System

This project implements a gacha system for investment NFTs using Chainlink VRF for randomness. The system consists of two main contracts:

1. `InvestmentNFT`: An ERC1155 contract that manages the NFTs and their tiers
2. `InvestmentGacha`: A contract that handles the investment and random NFT distribution

## Features

- ERC1155 NFT implementation with 5 different tiers
- Chainlink VRF for provably random NFT distribution
- Weighted distribution of NFT tiers
- Investment tracking for each NFT
- Owner-only functions for contract management

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Node.js and npm (for development)

## Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd gacha-smc
```

2. Install dependencies:
```bash
forge install
```

## Testing

Run the tests:
```bash
forge test
```

## Deployment

1. Deploy the NFT contract first:
```solidity
InvestmentNFT nft = new InvestmentNFT("ipfs://<your-base-uri>");
```

2. Deploy the Gacha contract:
```solidity
InvestmentGacha gacha = new InvestmentGacha(
    vrfCoordinator,  // Chainlink VRF Coordinator address
    keyHash,         // Chainlink VRF key hash
    subscriptionId,  // Chainlink VRF subscription ID
    address(nft)     // NFT contract address
);
```

3. Transfer NFT contract ownership to the Gacha contract:
```solidity
nft.transferOwnership(address(gacha));
```

## Usage

1. Users can invest by calling `requestMint()` with ETH:
```solidity
gacha.requestMint{value: amount}();
```

2. The contract will request a random number from Chainlink VRF
3. When the random number is received, an NFT will be minted to the user based on the weighted distribution
4. The owner can withdraw collected ETH using `withdraw()`

## Contract Architecture

### InvestmentNFT
- Manages NFT tiers and metadata
- Tracks user investments
- Handles NFT minting and transfers

### InvestmentGacha
- Handles investment collection
- Manages Chainlink VRF integration
- Controls NFT distribution
- Manages contract funds

## License

MIT
