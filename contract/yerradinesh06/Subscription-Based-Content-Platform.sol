// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Subscription-Based Content Platform
 * @dev A decentralized platform for managing content subscriptions using blockchain
 */
contract SubscriptionBasedContentPlatform {
    
    // State variables
    address public owner;
    uint256 public subscriptionPrice;
    uint256 public contentCounter;
    
    // Structs
    struct Subscription {
        bool isActive;
        uint256 expirationDate;
        uint256 subscriptionTier;
    }
    
    struct Content {
        uint256 contentId;
        string title;
        string contentHash; // IPFS hash or encrypted content reference
        address creator;
        uint256 requiredTier;
        uint256 createdAt;
        bool isActive;
    }
    
    // Mappings
    mapping(address => Subscription) public subscriptions;
    mapping(uint256 => Content) public contents;
    mapping(address => bool) public contentCreators;
    mapping(address => uint256) public creatorEarnings;
    
    // Events
    event SubscriptionPurchased(address indexed subscriber, uint256 expirationDate, uint256 tier);
    event ContentCreated(uint256 indexed contentId, address indexed creator, string title, uint256 tier);
    event ContentAccessed(address indexed subscriber, uint256 indexed contentId);
    event EarningsWithdrawn(address indexed creator, uint256 amount);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyContentCreator() {
        require(contentCreators[msg.sender], "Only approved content creators can call this function");
        _;
    }
    
    modifier hasActiveSubscription(address subscriber) {
        require(subscriptions[subscriber].isActive && 
                subscriptions[subscriber].expirationDate > block.timestamp, 
                "No active subscription");
        _;
    }
    
    constructor(uint256 _subscriptionPrice) {
        owner = msg.sender;
        subscriptionPrice = _subscriptionPrice;
        contentCounter = 0;
    }
    
    /**
     * @dev Core Function 1: Purchase or renew subscription
     * @param tier The subscription tier (1 = Basic, 2 = Premium, 3 = VIP)
     */
    function purchaseSubscription(uint256 tier) external payable {
        require(tier >= 1 && tier <= 3, "Invalid subscription tier");
        require(msg.value >= subscriptionPrice * tier, "Insufficient payment");
        
        uint256 duration;
        if (tier == 1) duration = 30 days;      // Basic: 30 days
        else if (tier == 2) duration = 60 days; // Premium: 60 days
        else duration = 90 days;                 // VIP: 90 days
        
        uint256 newExpiration;
        if (subscriptions[msg.sender].isActive && 
            subscriptions[msg.sender].expirationDate > block.timestamp) {
            // Extend existing subscription
            newExpiration = subscriptions[msg.sender].expirationDate + duration;
        } else {
            // New subscription
            newExpiration = block.timestamp + duration;
        }
        
        subscriptions[msg.sender] = Subscription({
            isActive: true,
            expirationDate: newExpiration,
            subscriptionTier: tier
        });
        
        emit SubscriptionPurchased(msg.sender, newExpiration, tier);
    }
    
    /**
     * @dev Core Function 2: Create and publish content
     * @param title The content title
     * @param contentHash IPFS hash or encrypted content reference
     * @param requiredTier Minimum subscription tier required to access content
     */
    function createContent(
        string memory title, 
        string memory contentHash, 
        uint256 requiredTier
    ) external onlyContentCreator {
        require(requiredTier >= 1 && requiredTier <= 3, "Invalid required tier");
        require(bytes(title).length > 0, "Title cannot be empty");
        require(bytes(contentHash).length > 0, "Content hash cannot be empty");
        
        contentCounter++;
        
        contents[contentCounter] = Content({
            contentId: contentCounter,
            title: title,
            contentHash: contentHash,
            creator: msg.sender,
            requiredTier: requiredTier,
            createdAt: block.timestamp,
            isActive: true
        });
        
        emit ContentCreated(contentCounter, msg.sender, title, requiredTier);
    }
    
    /**
     * @dev Core Function 3: Access content with subscription verification
     * @param contentId The ID of the content to access
     * @return contentHash The IPFS hash or content reference
     */
    function accessContent(uint256 contentId) 
        external 
        hasActiveSubscription(msg.sender) 
        returns (string memory contentHash) 
    {
        require(contentId > 0 && contentId <= contentCounter, "Invalid content ID");
        require(contents[contentId].isActive, "Content is not active");
        require(subscriptions[msg.sender].subscriptionTier >= contents[contentId].requiredTier, 
                "Subscription tier too low for this content");
        
        // Distribute earnings to content creator (90% to creator, 10% platform fee)
        uint256 viewReward = subscriptionPrice / 100; // Small reward per view
        creatorEarnings[contents[contentId].creator] += (viewReward * 90) / 100;
        
        emit ContentAccessed(msg.sender, contentId);
        
        return contents[contentId].contentHash;
    }
    
    // Additional utility functions
    function addContentCreator(address creator) external onlyOwner {
        contentCreators[creator] = true;
    }
    
    function removeContentCreator(address creator) external onlyOwner {
        contentCreators[creator] = false;
    }
    
    function withdrawEarnings() external {
        uint256 earnings = creatorEarnings[msg.sender];
        require(earnings > 0, "No earnings to withdraw");
        
        creatorEarnings[msg.sender] = 0;
        payable(msg.sender).transfer(earnings);
        
        emit EarningsWithdrawn(msg.sender, earnings);
    }
    
    function updateSubscriptionPrice(uint256 newPrice) external onlyOwner {
        subscriptionPrice = newPrice;
    }
    
    function deactivateContent(uint256 contentId) external {
        require(contentId > 0 && contentId <= contentCounter, "Invalid content ID");
        require(contents[contentId].creator == msg.sender || msg.sender == owner, 
                "Only creator or owner can deactivate content");
        
        contents[contentId].isActive = false;
    }
    
    function getSubscriptionStatus(address subscriber) 
        external 
        view 
        returns (bool isActive, uint256 expirationDate, uint256 tier) 
    {
        Subscription memory sub = subscriptions[subscriber];
        return (
            sub.isActive && sub.expirationDate > block.timestamp,
            sub.expirationDate,
            sub.subscriptionTier
        );
    }
    
    function getContentDetails(uint256 contentId) 
        external 
        view 
        returns (
            string memory title,
            address creator,
            uint256 requiredTier,
            uint256 createdAt,
            bool isActive
        ) 
    {
        require(contentId > 0 && contentId <= contentCounter, "Invalid content ID");
        Content memory content = contents[contentId];
        return (
            content.title,
            content.creator,
            content.requiredTier,
            content.createdAt,
            content.isActive
        );
    }
    
    function withdrawPlatformFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        payable(owner).transfer(balance);
    }
    
    // Emergency pause functionality
    bool public platformPaused = false;
    
    function pausePlatform() external onlyOwner {
        platformPaused = true;
    }
    
    function unpausePlatform() external onlyOwner {
        platformPaused = false;
    }
    
    modifier whenNotPaused() {
        require(!platformPaused, "Platform is paused");
        _;
    }
}
