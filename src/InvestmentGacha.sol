// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import "./InvestmentNFT.sol";

contract InvestmentGacha is Ownable, VRFConsumerBaseV2 {
    InvestmentNFT public nftContract;
    IERC20 public rewardToken;

    // Chainlink VRF
    VRFCoordinatorV2Interface COORDINATOR;
    uint64 public subscriptionId;
    bytes32 public keyHash;
    uint32 public callbackGasLimit = 300000;
    uint16 public requestConfirmations = 3;
    uint32 public numWords = 1;

    // Chainlink requestId => user & amount
    mapping(uint256 => address) public requestToSender;
    mapping(uint256 => uint256) public requestToAmount;

    // Weighted token IDs for random selection
    uint256[] public weightedTokenIds;

    // Investment tracking
    struct Investment {
        uint256 investedAmount;
        uint256 timestamp;
    }
    mapping(uint256 => Investment) public investments;
    mapping(address => uint256) public totalRewards;

    // Constants
    uint256 public constant CLAIM_INTERVAL = 30 minutes;
    uint256 public constant SECONDS_PER_DAY = 24 hours;
    uint256 public constant MAX_LEVEL = 5;

    // Events
    event InvestmentMade(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 tokenId, uint256 amount);
    event RewardTokenUpdated(address indexed oldToken, address indexed newToken);

    // Add new mapping to track number of investments per request
    mapping(uint256 => uint256) public requestToNumberOfInvestments;

    constructor(
        address vrfCoordinator,
        bytes32 _keyHash,
        uint64 _subId,
        address _nftContract,
        address _rewardToken
    ) VRFConsumerBaseV2(vrfCoordinator) Ownable(msg.sender) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        keyHash = _keyHash;
        subscriptionId = _subId;
        nftContract = InvestmentNFT(_nftContract);
        rewardToken = IERC20(_rewardToken);

        // Initialize weighted token IDs
        _initializeWeightedTokens();
    }

    function _initializeWeightedTokens() internal {
        // Level 1: 40%
        for (uint256 i = 0; i < 40; i++) {
            weightedTokenIds.push(1);
        }
        // Level 2: 30%
        for (uint256 i = 0; i < 30; i++) {
            weightedTokenIds.push(2);
        }
        // Level 3: 20%
        for (uint256 i = 0; i < 20; i++) {
            weightedTokenIds.push(3);
        }
        // Level 4: 9%
        for (uint256 i = 0; i < 9; i++) {
            weightedTokenIds.push(4);
        }
        // Level 5: 1%
        for (uint256 i = 0; i < 1; i++) {
            weightedTokenIds.push(5);
        }
    }

    function invest() external payable returns (uint256 requestId) {
        require(msg.value > 0, "Send ETH to invest");

        emit InvestmentMade(msg.sender, msg.value);

        // Request random NFT
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );

        requestToSender[requestId] = msg.sender;
        requestToAmount[requestId] = msg.value;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        address user = requestToSender[requestId];
        uint256 amountPerInvestment = requestToAmount[requestId];
        uint256 numberOfInvestments = requestToNumberOfInvestments[requestId];
        require(user != address(0), "Invalid request");

        // If numberOfInvestments is 0, treat as single investment
        if (numberOfInvestments == 0) {
            numberOfInvestments = 1;
        }

        // Generate random tiers for all investments
        uint256[] memory randomTiers = new uint256[](numberOfInvestments);
        
        for (uint256 i = 0; i < numberOfInvestments; i++) {
            uint256 rand = randomWords[i] % weightedTokenIds.length;
            randomTiers[i] = weightedTokenIds[rand];
        }

        // Batch mint all NFTs at once (gas efficient)
        uint256[] memory tokenIds = nftContract.batchMintNFTWithRandomTiers(user, randomTiers);

        // Store investment data and initialize reward tracking for each token
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            
            investments[tokenId] = Investment({
                investedAmount: amountPerInvestment,
                timestamp: block.timestamp
            });
        }

        // Cleanup
        delete requestToSender[requestId];
        delete requestToAmount[requestId];
        delete requestToNumberOfInvestments[requestId];
    }

    // Public function for testing
    function fulfillRandomWordsTest(uint256 requestId, uint256[] memory randomWords) external {
        fulfillRandomWords(requestId, randomWords);
    }

    function calculateReward(address user, uint256 tokenId) public view returns (uint256) {
        require(nftContract.ownerOf(tokenId) == user, "User does not own this NFT");
        
        uint256 investedAmount = investments[tokenId].investedAmount;
        uint256 lastClaimTime = investments[tokenId].timestamp;
        
        uint256 currentTime = block.timestamp;
        
        // Calculate how many complete 30-minute intervals have passed since last claim
        uint256 intervalsSinceLastClaim = (currentTime - lastClaimTime) / CLAIM_INTERVAL;
        require(intervalsSinceLastClaim > 0, "Must wait 30 minutes between claims");

        (,uint256 roi,) = nftContract.getNFTInfo(tokenId);
        // Calculate reward for complete intervals only
        uint256 rewardAmount = (investedAmount * roi / 10000 / SECONDS_PER_DAY) * intervalsSinceLastClaim * CLAIM_INTERVAL;
        
        return rewardAmount;
    }

    function claimReward(uint256 tokenId) external {
        uint256 rewardAmount = calculateReward(msg.sender, tokenId);
        require(rewardAmount > 0, "No rewards to claim");
        require(rewardToken.balanceOf(address(this)) >= rewardAmount, "Insufficient reward token balance");

        uint256 lastClaimTime = investments[tokenId].timestamp;        // Calculate how many complete intervals have passed
        uint256 intervalsSinceLastClaim = (block.timestamp - lastClaimTime) / CLAIM_INTERVAL;
        
        // Set lastClaimTime to the last complete interval boundary
        investments[tokenId].timestamp = lastClaimTime + (intervalsSinceLastClaim * CLAIM_INTERVAL);
        totalRewards[msg.sender] += rewardAmount;

        require(rewardToken.transfer(msg.sender, rewardAmount), "Reward token transfer failed");

        emit RewardClaimed(msg.sender, tokenId, rewardAmount);
    }

    

    function getNFTRewardInfo(uint256 tokenId) external view returns (
        uint256 investedAmount,
        uint256 lastClaimTime,
        uint256 level,
        uint256 roi,
        string memory baseURI
    ) {
        investedAmount = investments[tokenId].investedAmount;
        lastClaimTime = investments[tokenId].timestamp;
        (level, roi, baseURI) = nftContract.getNFTInfo(tokenId);

        return (
            investedAmount,
            lastClaimTime,
            level,
            roi,
            baseURI
        );
    }

    function getNextClaimTime(uint256 tokenId) external view returns (uint256) {
        return investments[tokenId].timestamp + CLAIM_INTERVAL;
    }


    function depositRewardTokens(uint256 amount) external onlyOwner {
        require(rewardToken.transferFrom(msg.sender, address(this), amount), "Reward token deposit failed");
    }

    function withdrawETH() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function withdrawRewardTokens(uint256 amount) external onlyOwner {
        require(rewardToken.balanceOf(address(this)) >= amount, "Insufficient reward token balance");
        require(rewardToken.transfer(owner(), amount), "Reward token withdrawal failed");
    }

    function withdrawAllRewardTokens() external onlyOwner {
        uint256 balance = rewardToken.balanceOf(address(this));
        require(balance > 0, "No reward tokens to withdraw");
        require(rewardToken.transfer(owner(), balance), "Reward token withdrawal failed");
    }

    function getRewardTokenBalance() external view returns (uint256) {
        return rewardToken.balanceOf(address(this));
    }

    function setNFTContract(address _nftContract) external onlyOwner {
        nftContract = InvestmentNFT(_nftContract);
    }

    function setRewardToken(address _rewardToken) external onlyOwner {
        address oldToken = address(rewardToken);
        rewardToken = IERC20(_rewardToken);
        emit RewardTokenUpdated(oldToken, _rewardToken);
    }

    function batchInvest(uint256 numberOfInvestments) external payable returns (uint256 requestId) {
        require(msg.value > 0, "Send ETH to invest");
        require(numberOfInvestments > 0 && numberOfInvestments <= 10, "Invalid number of investments");
        
        uint256 amountPerInvestment = msg.value / numberOfInvestments;
        require(amountPerInvestment > 0, "Amount per investment too small");

        emit InvestmentMade(msg.sender, msg.value);

        // Request random words for batch minting
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            uint32(numberOfInvestments) // Request multiple random words
        );

        requestToSender[requestId] = msg.sender;
        requestToAmount[requestId] = amountPerInvestment; // Amount per NFT
        
        // Store number of investments for this request
        requestToNumberOfInvestments[requestId] = numberOfInvestments;
    }
} 