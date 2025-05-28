// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "../src/InvestmentGacha.sol";
import "../src/InvestmentNFT.sol";
import "../src/RewardToken.sol";

contract InvestmentGachaTest is Test {
    InvestmentNFT public nft;
    InvestmentGacha public gacha;
    RewardToken public rewardToken;
    address public owner;
    address public user;
    address public vrfCoordinator;
    bytes32 public keyHash;
    uint64 public subscriptionId;

    function setUp() public {
        user = address(0x1);
        vrfCoordinator = address(0x2);
        keyHash = bytes32(uint256(1));
        subscriptionId = 1;

        // Create reward token
        rewardToken = new RewardToken("Reward Token", "RWT", 1000000 * 10**18);

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
        
        gacha = new InvestmentGacha(
            vrfCoordinator,
            keyHash,
            subscriptionId,
            address(nft),
            address(rewardToken)
        );

        // Transfer NFT contract ownership to gacha contract
        nft.transferOwnership(address(gacha));

        // Transfer some reward tokens to gacha contract for rewards
        rewardToken.transfer(address(gacha), 100000 * 10**18);
    }

    function testInvest() public {
        vm.startPrank(user);
        vm.deal(user, 1 ether);
        uint256 requestId = gacha.invest{value: 1 ether}();
        assertEq(gacha.requestToSender(requestId), user);
        assertEq(gacha.requestToAmount(requestId), 1 ether);
        vm.stopPrank();
    }

    function testFulfillRandomWords() public {
        vm.startPrank(user);
        vm.deal(user, 1 ether);
        uint256 requestId = gacha.invest{value: 1 ether}();
        vm.stopPrank();

        // Simulate VRF response
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 42; // This will select a random level

        vm.startPrank(vrfCoordinator);
        gacha.fulfillRandomWordsTest(requestId, randomWords);
        vm.stopPrank();

        // Check that NFT was minted - user should own token ID 0
        assertEq(nft.ownerOf(0), user);
        assertEq(nft.balanceOf(user), 1);
        
        // Check the level mapping
        (uint256 level, uint256 roi,) = nft.getNFTInfo(0);
        assertGt(level, 0);
        assertLt(level, 6); // Level should be between 1 and 5
        assertGt(roi, 0);

        // Check investment was recorded
        (uint256 investedAmount, uint256 timestamp) = gacha.investments(0);
        assertEq(investedAmount, 1 ether);
        assertGt(timestamp, 0);
    }

    function testSequentialTokenIds() public {
        address user2 = address(0x3);
        
        // First investment
        vm.startPrank(user);
        vm.deal(user, 2 ether);
        uint256 requestId1 = gacha.invest{value: 1 ether}();
        vm.stopPrank();

        // Simulate VRF response for first NFT
        uint256[] memory randomWords1 = new uint256[](1);
        randomWords1[0] = 42;
        vm.startPrank(vrfCoordinator);
        gacha.fulfillRandomWordsTest(requestId1, randomWords1);
        vm.stopPrank();

        // Second investment with different user
        vm.startPrank(user2);
        vm.deal(user2, 1 ether);
        uint256 requestId2 = gacha.invest{value: 1 ether}();
        vm.stopPrank();

        // Simulate VRF response for second NFT
        uint256[] memory randomWords2 = new uint256[](1);
        randomWords2[0] = 43;
        vm.startPrank(vrfCoordinator);
        gacha.fulfillRandomWordsTest(requestId2, randomWords2);
        vm.stopPrank();

        // Check that NFTs were minted with sequential token IDs
        assertEq(nft.ownerOf(0), user);
        assertEq(nft.ownerOf(1), user2);
        assertEq(nft.balanceOf(user), 1);
        assertEq(nft.balanceOf(user2), 1);
    }

    function testGetNFTInfo() public {
        // Setup investment and NFT
        vm.startPrank(user);
        vm.deal(user, 1 ether);
        uint256 requestId = gacha.invest{value: 1 ether}();
        vm.stopPrank();

        // Simulate VRF response
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 42;
        vm.startPrank(vrfCoordinator);
        gacha.fulfillRandomWordsTest(requestId, randomWords);
        vm.stopPrank();

        // Get NFT info from gacha contract
        (uint256 investedAmount, uint256 lastClaimTime, uint256 level, uint256 roi, ) = gacha.getNFTRewardInfo(0);
        assertEq(investedAmount, 1 ether);
        assertGt(lastClaimTime, 0);
        assertGt(level, 0);
        assertLt(level, 6);
        assertGt(roi, 0);
    }

    function testGetTokenIdsByTier() public {
        address user2 = address(0x3);
        
        // Setup multiple investments
        vm.startPrank(user);
        vm.deal(user, 3 ether);
        
        // First investment
        uint256 requestId1 = gacha.invest{value: 1 ether}();
        vm.stopPrank();

        // Simulate VRF response for first NFT - use index 10 which is in tier 1 range (0-39)
        uint256[] memory randomWords1 = new uint256[](1);
        randomWords1[0] = 10; // This will select tier 1
        vm.startPrank(vrfCoordinator);
        gacha.fulfillRandomWordsTest(requestId1, randomWords1);
        vm.stopPrank();

        // Second investment with different user
        vm.startPrank(user2);
        vm.deal(user2, 1 ether);
        uint256 requestId2 = gacha.invest{value: 1 ether}();
        vm.stopPrank();

        // Simulate VRF response for second NFT - use index 20 which is also in tier 1 range
        uint256[] memory randomWords2 = new uint256[](1);
        randomWords2[0] = 20; // This will also select tier 1
        vm.startPrank(vrfCoordinator);
        gacha.fulfillRandomWordsTest(requestId2, randomWords2);
        vm.stopPrank();

        // Get all token IDs for tier 1 from NFT contract
        uint256[] memory tokenIds = nft.getTokenIdsByTier(1);
        assertEq(tokenIds.length, 2);
        assertEq(tokenIds[0], 0);
        assertEq(tokenIds[1], 1);
    }

    function testCalculateReward() public {
        // Setup investment and NFT
        vm.startPrank(user);
        vm.deal(user, 1 ether);
        uint256 requestId = gacha.invest{value: 1 ether}();
        vm.stopPrank();

        // Simulate VRF response
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 42;
        vm.startPrank(vrfCoordinator);
        gacha.fulfillRandomWordsTest(requestId, randomWords);
        vm.stopPrank();

        // Fast forward 30 minutes
        vm.warp(block.timestamp + 30 minutes);

        // Calculate reward
        uint256 reward = gacha.calculateReward(user, 0);
        assertGt(reward, 0);
    }

    function testClaimReward() public {
        // Setup investment and NFT
        vm.startPrank(user);
        vm.deal(user, 1 ether);
        uint256 requestId = gacha.invest{value: 1 ether}();
        vm.stopPrank();

        // Simulate VRF response
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 42;
        vm.startPrank(vrfCoordinator);
        gacha.fulfillRandomWordsTest(requestId, randomWords);
        vm.stopPrank();

        // Fast forward 30 minutes
        vm.warp(block.timestamp + 30 minutes);

        // Claim reward
        vm.startPrank(user);
        uint256 balanceBefore = rewardToken.balanceOf(user);
        gacha.claimReward(0);
        uint256 balanceAfter = rewardToken.balanceOf(user);
        assertGt(balanceAfter, balanceBefore);
        vm.stopPrank();
    }

    function testBatchInvest() public {
        vm.startPrank(user);
        vm.deal(user, 5 ether);
        uint256 requestId = gacha.batchInvest{value: 5 ether}(5);
        assertEq(gacha.requestToSender(requestId), user);
        assertEq(gacha.requestToAmount(requestId), 1 ether); // 5 ether / 5 = 1 ether per investment
        assertEq(gacha.requestToNumberOfInvestments(requestId), 5);
        vm.stopPrank();
    }

    function testBatchFulfillRandomWords() public {
        vm.startPrank(user);
        vm.deal(user, 3 ether);
        uint256 requestId = gacha.batchInvest{value: 3 ether}(3);
        vm.stopPrank();

        // Simulate VRF response with 3 random words
        uint256[] memory randomWords = new uint256[](3);
        randomWords[0] = 42;
        randomWords[1] = 43;
        randomWords[2] = 44;

        vm.startPrank(vrfCoordinator);
        gacha.fulfillRandomWordsTest(requestId, randomWords);
        vm.stopPrank();

        // Check that 3 NFTs were minted
        assertEq(nft.balanceOf(user), 3);
        assertEq(nft.ownerOf(0), user);
        assertEq(nft.ownerOf(1), user);
        assertEq(nft.ownerOf(2), user);

        // Check investments were recorded
        for (uint256 i = 0; i < 3; i++) {
            (uint256 investedAmount,) = gacha.investments(i);
            assertEq(investedAmount, 1 ether); // 3 ether / 3 = 1 ether per investment
        }
    }

    function testCannotClaimRewardBeforeInterval() public {
        // Setup investment and NFT
        vm.startPrank(user);
        vm.deal(user, 1 ether);
        uint256 requestId = gacha.invest{value: 1 ether}();
        vm.stopPrank();

        // Simulate VRF response
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 42;
        vm.startPrank(vrfCoordinator);
        gacha.fulfillRandomWordsTest(requestId, randomWords);
        vm.stopPrank();

        // Try to claim reward before 30 minutes
        vm.startPrank(user);
        vm.expectRevert("Must wait 30 minutes between claims");
        gacha.calculateReward(user, 0);
        vm.stopPrank();
    }

    function testGetNextClaimTime() public {
        // Setup investment and NFT
        vm.startPrank(user);
        vm.deal(user, 1 ether);
        uint256 requestId = gacha.invest{value: 1 ether}();
        vm.stopPrank();

        // Simulate VRF response
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 42;
        vm.startPrank(vrfCoordinator);
        gacha.fulfillRandomWordsTest(requestId, randomWords);
        vm.stopPrank();

        uint256 nextClaimTime = gacha.getNextClaimTime(0);
        assertGt(nextClaimTime, block.timestamp);
    }

    function testRewardTokenFunctionality() public {
        // Test getting reward token balance
        uint256 balance = gacha.getRewardTokenBalance();
        assertEq(balance, 100000 * 10**18);

        // Test depositing more reward tokens
        rewardToken.approve(address(gacha), 50000 * 10**18);
        gacha.depositRewardTokens(50000 * 10**18);
        
        uint256 newBalance = gacha.getRewardTokenBalance();
        assertEq(newBalance, 150000 * 10**18);

        // Test withdrawing reward tokens
        gacha.withdrawRewardTokens(25000 * 10**18);
        uint256 balanceAfterWithdraw = gacha.getRewardTokenBalance();
        assertEq(balanceAfterWithdraw, 125000 * 10**18);
    }

    function testSetRewardToken() public {
        // Create a new reward token
        RewardToken newRewardToken = new RewardToken("New Reward Token", "NRWT", 1000000 * 10**18);
        
        // Set the new reward token
        gacha.setRewardToken(address(newRewardToken));
        
        // Verify the reward token was updated
        assertEq(address(gacha.rewardToken()), address(newRewardToken));
    }

    function testWithdrawETH() public {
        // Setup investment to add funds to contract
        vm.startPrank(user);
        vm.deal(user, 1 ether);
        gacha.invest{value: 1 ether}();
        vm.stopPrank();

        // Check that the test contract is the owner and can withdraw ETH
        uint256 balanceBefore = address(this).balance;
        gacha.withdrawETH();
        uint256 balanceAfter = address(this).balance;
        assertEq(balanceAfter - balanceBefore, 1 ether);
    }

    function testSetNFTContract() public {
        // Create level data for new NFT contract
        uint256[5] memory tierLevels = [uint256(1), 2, 3, 4, 5];
        uint256[5] memory tierRois = [uint256(100), 200, 300, 400, 500];
        string[5] memory tierBaseURIs = [
            "ipfs://QmCommon/",
            "ipfs://QmUncommon/",
            "ipfs://QmRare/",
            "ipfs://QmEpic/",
            "ipfs://QmLegendary/"
        ];

        InvestmentNFT newNFT = new InvestmentNFT(
            "New Investment NFT",
            "NINFT",
            tierLevels,
            tierRois,
            tierBaseURIs
        );
        gacha.setNFTContract(address(newNFT));
        assertEq(address(gacha.nftContract()), address(newNFT));
    }

    // Add receive function to allow the test contract to receive ETH
    receive() external payable {}
} 