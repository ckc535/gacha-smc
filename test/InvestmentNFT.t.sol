// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "../src/InvestmentNFT.sol";

contract InvestmentNFTTest is Test {
    InvestmentNFT public nft;
    address public owner;
    address public user;

    function setUp() public {
        owner = address(this);
        user = address(0x1);

        // Create level data for NFT contract
        uint256[5] memory tierLevels = [uint256(1), 2, 3, 4, 5];
        uint256[5] memory tierRois = [uint256(100), 200, 300, 400, 500]; // 1%, 2%, 3%, 4%, 5%
        string[5] memory tierBaseURIs = [
            "ipfs://QmCommon/",
            "ipfs://QmUncommon/",
            "ipfs://QmRare/",
            "ipfs://QmEpic/",
            "ipfs://QmLegendary/"
        ];

        nft = new InvestmentNFT(
            "Investment NFT",
            "INFT",
            tierLevels,
            tierRois,
            tierBaseURIs
        );
    }

    function testMintNFT() public {
        uint256 tokenId = nft.mintNFT(user, 1, 1);
        assertEq(tokenId, 0);
        assertEq(nft.ownerOf(0), user);
        assertEq(nft.balanceOf(user), 1);
        
        // Check tier mapping
        assertEq(nft.tokenIdToTier(0), 1);
    }

    function testBatchMintNFTWithRandomTiers() public {
        uint256[] memory randomTiers = new uint256[](3);
        randomTiers[0] = 1;
        randomTiers[1] = 3;
        randomTiers[2] = 5;

        uint256[] memory tokenIds = nft.batchMintNFTWithRandomTiers(user, randomTiers);
        
        assertEq(tokenIds.length, 3);
        assertEq(nft.balanceOf(user), 3);
        
        // Check each token has correct tier
        assertEq(nft.tokenIdToTier(tokenIds[0]), 1);
        assertEq(nft.tokenIdToTier(tokenIds[1]), 3);
        assertEq(nft.tokenIdToTier(tokenIds[2]), 5);
        
        // Check sequential token IDs
        assertEq(tokenIds[0], 0);
        assertEq(tokenIds[1], 1);
        assertEq(tokenIds[2], 2);
    }

    function testGetTierInfo() public {
        InvestmentNFT.Tier memory tier = nft.getTierInfo(1);
        assertEq(tier.level, 1);
        assertEq(tier.roi, 100);
        assertEq(keccak256(bytes(tier.baseURI)), keccak256(bytes("ipfs://QmCommon/")));
    }

    function testGetNFTInfo() public {
        nft.mintNFT(user, 2, 1);
        
        (uint256 level, uint256 roi, string memory baseURI) = nft.getNFTInfo(0);
        assertEq(level, 2);
        assertEq(roi, 200);
        assertEq(keccak256(bytes(baseURI)), keccak256(bytes("ipfs://QmUncommon/")));
    }

    function testGetTokenIdsByTier() public {
        nft.mintNFT(user, 1, 1);
        nft.mintNFT(user, 1, 1);
        nft.mintNFT(user, 2, 1);
        
        uint256[] memory tier1Tokens = nft.getTokenIdsByTier(1);
        uint256[] memory tier2Tokens = nft.getTokenIdsByTier(2);
        
        assertEq(tier1Tokens.length, 2);
        assertEq(tier2Tokens.length, 1);
        assertEq(tier1Tokens[0], 0);
        assertEq(tier1Tokens[1], 1);
        assertEq(tier2Tokens[0], 2);
    }

    function testGetUserTokenIdsByTier() public {
        address user2 = address(0x2);
        
        nft.mintNFT(user, 1, 1);
        nft.mintNFT(user2, 1, 1);
        nft.mintNFT(user, 2, 1);
        
        uint256[] memory userTier1Tokens = nft.getUserTokenIdsByTier(user, 1);
        uint256[] memory user2Tier1Tokens = nft.getUserTokenIdsByTier(user2, 1);
        uint256[] memory userTier2Tokens = nft.getUserTokenIdsByTier(user, 2);
        
        assertEq(userTier1Tokens.length, 1);
        assertEq(user2Tier1Tokens.length, 1);
        assertEq(userTier2Tokens.length, 1);
        assertEq(userTier1Tokens[0], 0);
        assertEq(user2Tier1Tokens[0], 1);
        assertEq(userTier2Tokens[0], 2);
    }

    function testGetUserTierCounts() public {
        nft.mintNFT(user, 1, 1);
        nft.mintNFT(user, 1, 1);
        nft.mintNFT(user, 3, 1);
        
        uint256[] memory counts = nft.getUserTierCounts(user);
        assertEq(counts.length, 5);
        assertEq(counts[0], 2); // Tier 1 count
        assertEq(counts[1], 0); // Tier 2 count
        assertEq(counts[2], 1); // Tier 3 count
        assertEq(counts[3], 0); // Tier 4 count
        assertEq(counts[4], 0); // Tier 5 count
    }

    function testTokenURI() public {
        nft.mintNFT(user, 1, 1);
        string memory uri = nft.tokenURI(0);
        assertEq(keccak256(bytes(uri)), keccak256(bytes("ipfs://QmCommon/0")));
    }

    function testSetTierBaseURI() public {
        nft.setTierBaseURI(1, "ipfs://NewCommon/");
        InvestmentNFT.Tier memory tier = nft.getTierInfo(1);
        assertEq(keccak256(bytes(tier.baseURI)), keccak256(bytes("ipfs://NewCommon/")));
    }

    function testSetTierROI() public {
        nft.setTierROI(1, 150);
        InvestmentNFT.Tier memory tier = nft.getTierInfo(1);
        assertEq(tier.roi, 150);
    }

    function testOnlyOwnerCanMint() public {
        vm.startPrank(user);
        vm.expectRevert();
        nft.mintNFT(user, 1, 1);
        vm.stopPrank();
    }

    function testOnlyOwnerCanBatchMint() public {
        uint256[] memory randomTiers = new uint256[](2);
        randomTiers[0] = 1;
        randomTiers[1] = 2;

        vm.startPrank(user);
        vm.expectRevert();
        nft.batchMintNFTWithRandomTiers(user, randomTiers);
        vm.stopPrank();
    }

    function testInvalidTierReverts() public {
        vm.expectRevert("Invalid tier");
        nft.mintNFT(user, 0, 1);
        
        vm.expectRevert("Invalid tier");
        nft.mintNFT(user, 6, 1);
    }

    function testInvalidTierInBatchMintReverts() public {
        uint256[] memory randomTiers = new uint256[](2);
        randomTiers[0] = 1;
        randomTiers[1] = 6; // Invalid tier

        vm.expectRevert("Invalid tier");
        nft.batchMintNFTWithRandomTiers(user, randomTiers);
    }

    function testEmptyArrayInBatchMintReverts() public {
        uint256[] memory randomTiers = new uint256[](0);

        vm.expectRevert("Empty array");
        nft.batchMintNFTWithRandomTiers(user, randomTiers);
    }
} 