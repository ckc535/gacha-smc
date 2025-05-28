// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "ERC721A/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract InvestmentNFT is ERC721A, Ownable {
    // Tier information
    struct Tier {
        uint256 level; // Tier level (1-5)
        uint256 roi; // ROI per day in basis points (e.g., 100 = 1%)
        string baseURI;
    }

    struct UserNFT {
        uint256 tokenId;
        uint256 amount;
        uint256 level;
    }

    // State variables
    mapping(uint256 => Tier) public tiers;
    
    mapping(uint256 => uint256) public tokenIdToTier; // Maps token ID to its tier
    mapping(uint256 => uint256[]) public tierToTokenIds; // Maps tier to array of token IDs
    mapping(address => mapping(uint256 => uint256[])) public userTierToTokenIds; // Maps user and tier to their token IDs

    // Constants
    uint256 public constant MAX_TIER = 5;

    // Events
    event TierAdded(uint256 indexed tierId, uint256 level, uint256 roi);
    event NFTMinted(address indexed user, uint256 indexed tokenId, uint256 tier, uint256 amount);

    constructor(
        string memory _name,
        string memory _symbol,
        uint256[5] memory _tierLevels,
        uint256[5] memory _tierRois,
        string[5] memory _tierBaseURIs
    ) ERC721A(_name, _symbol) Ownable(msg.sender) {
        require(_tierLevels.length == MAX_TIER, "Invalid tier levels length");
        require(_tierRois.length == MAX_TIER, "Invalid tier ROIs length");
        require(_tierBaseURIs.length == MAX_TIER, "Invalid tier URIs length");

        // Initialize tiers
        for (uint256 i = 0; i < MAX_TIER; i++) {
            uint256 tierId = i + 1;
            tiers[tierId] = Tier({
                level: _tierLevels[i],
                roi: _tierRois[i],
                baseURI: _tierBaseURIs[i]
            });
            emit TierAdded(tierId, _tierLevels[i], _tierRois[i]);
        }
    }

    function mintNFT(address user, uint256 tier, uint256 amount) external onlyOwner returns (uint256) {
        require(tier > 0 && tier <= MAX_TIER, "Invalid tier");
        
        uint256 startTokenId = _nextTokenId();
        _mint(user, amount);

        // Store tier information for each token
        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = startTokenId + i;
            tokenIdToTier[tokenId] = tier;

            tierToTokenIds[tier].push(tokenId);
            userTierToTokenIds[user][tier].push(tokenId);
        }

        emit NFTMinted(user, startTokenId, tier, amount);
        return startTokenId;
    }

    function batchMintNFTWithRandomTiers(
        address user,
        uint256[] calldata randomTiers
    ) external onlyOwner returns (uint256[] memory tokenIds) {
        require(randomTiers.length > 0, "Empty array");
        
        uint256 numberOfNFTs = randomTiers.length;
        tokenIds = new uint256[](numberOfNFTs);

        // Validate all tiers
        for (uint256 i = 0; i < numberOfNFTs; i++) {
            require(randomTiers[i] > 0 && randomTiers[i] <= MAX_TIER, "Invalid tier");
        }

        // Mint all NFTs in one batch (1 NFT per tier)
        uint256 startTokenId = _nextTokenId();
        _mint(user, numberOfNFTs);

        // Store tier information for each token
        for (uint256 i = 0; i < numberOfNFTs; i++) {
            uint256 tokenId = startTokenId + i;
            tokenIds[i] = tokenId;
            
            tokenIdToTier[tokenId] = randomTiers[i];
            tierToTokenIds[randomTiers[i]].push(tokenId);
            userTierToTokenIds[user][randomTiers[i]].push(tokenId);
            
            emit NFTMinted(user, tokenId, randomTiers[i], 1);
        }

        return tokenIds;
    }

    function getTierInfo(uint256 tier) external view returns (Tier memory) {
        require(tier > 0 && tier <= MAX_TIER, "Invalid tier");
        return tiers[tier];
    }

    function getNFTInfo(uint256 tokenId) external view returns (
        uint256 level,
        uint256 roi,
        string memory baseURI
    ) {
        uint256 tier = tokenIdToTier[tokenId];
        require(tier > 0 && tier <= MAX_TIER, "Invalid token ID");
        
        Tier memory tierInfo = tiers[tier];
        return (tierInfo.level, tierInfo.roi, tierInfo.baseURI);
    }

    function getTokenIdsByTier(uint256 tier) external view returns (uint256[] memory) {
        require(tier > 0 && tier <= MAX_TIER, "Invalid tier");
        return tierToTokenIds[tier];
    }

    function getUserTokenIdsByTier(address user, uint256 tier) external view returns (uint256[] memory) {
        require(tier > 0 && tier <= MAX_TIER, "Invalid tier");
        return userTierToTokenIds[user][tier];
    }

    function getUserTierCounts(address user) external view returns (uint256[] memory) {
        uint256[] memory counts = new uint256[](MAX_TIER);
        for (uint256 i = 1; i <= MAX_TIER; i++) {
            counts[i-1] = userTierToTokenIds[user][i].length;
        }
        return counts;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        uint256 tier = tokenIdToTier[tokenId];
        require(tier > 0 && tier <= MAX_TIER, "Invalid token ID");
        return string(abi.encodePacked(tiers[tier].baseURI, _toString(tokenId)));
    }

    function setTierBaseURI(uint256 tier, string memory _baseURI) external onlyOwner {
        require(tier > 0 && tier <= MAX_TIER, "Invalid tier");
        tiers[tier].baseURI = _baseURI;
    }

    function setTierROI(uint256 tier, uint256 _roi) external onlyOwner {
        require(tier > 0 && tier <= MAX_TIER, "Invalid tier");
        tiers[tier].roi = _roi;
    }

    // Helper function to convert uint256 to string
} 