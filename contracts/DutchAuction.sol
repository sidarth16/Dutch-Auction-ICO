// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DutchAuction is Ownable  {
    
    uint immutable TOTAL_SHARES;
    uint immutable PRICE_DECAY_RATE; // Rate at which price will reduce every 10 minutes
    uint immutable START_SHARE_PRICE;
    uint immutable BASE_PRICE;

    uint AuctionStartTime;
    uint availableShares;
    uint cutoffPrice;

    struct Bids{
        uint256 shares;
        uint256 sharePrice;
    }
    mapping(address => Bids) private bids;

    enum AuctionStates{
        YetToStart,
        Started,
        Closed,
        allocateShares
    }
    AuctionStates public auctionState;


    event AuctionStarted(uint indexed timestamp);
    event PlaceBid(uint indexed shares, uint indexed sharePrice, uint indexed timestamp );

    // constructor(uint totalShares, uint priceDecayRate, uint shareStartPrice, uint basePrice) {
    //     TOTAL_SHARES = totalShares;
    //     PRICE_DECAY_RATE = priceDecayRate;
    //     START_SHARE_PRICE = shareStartPrice;
    //     BASE_PRICE = basePrice;
    //     AuctionStartTime = block.timestamp;
    //     availableShares = totalShares;
    //     auctionState = AuctionStates.YetToStart
    // }

    constructor() {
        TOTAL_SHARES = 100;
        PRICE_DECAY_RATE = 1;
        START_SHARE_PRICE = 100;
        BASE_PRICE = 10;
        AuctionStartTime = block.timestamp;
        availableShares = 100;
        auctionState = AuctionStates.YetToStart;
    }

    function startAuction() public onlyOwner {
        AuctionStartTime = block.timestamp;
        auctionState = AuctionStates.Started;

    }

    function EndAuction() public onlyOwner {
        auctionState = AuctionStates.Closed;
    }

    function startBidExecution() public onlyOwner {
        auctionState = AuctionStates.allocateShares;
    }

    function getCurrentSharePrice() public view returns (uint){
        if (auctionState != AuctionStates.Started)
            return cutoffPrice;
        uint minutesElapsed = (block.timestamp - AuctionStartTime)/60;
        uint currSharePrice =  START_SHARE_PRICE - (PRICE_DECAY_RATE * minutesElapsed)/10;
        if (currSharePrice < BASE_PRICE) return BASE_PRICE;
        return currSharePrice; 
    }

    function getBidDetails(address user) public view returns (uint256 shares, uint256 sharePrice){
        Bids memory userBid = bids[user] ;
        (shares, sharePrice) =  (userBid.shares, userBid.sharePrice) ;
    }

    function placeBid(uint shares, uint targetSharePrice) external payable{

        require(auctionState == AuctionStates.Started, "Auction yet to to Start");
        require(msg.value == targetSharePrice*shares, "Invalid amount paid");
        require(bids[msg.sender].shares==0 , "A User can bid only once");
        require(shares <= availableShares, "Requested Share amount exceeds availability");
        
        uint256 currSharePrice = getCurrentSharePrice();
        require(currSharePrice == targetSharePrice, "Requested Target Price expired");
        
        bids[msg.sender] = Bids(shares, currSharePrice);
        availableShares -= shares;

        cutoffPrice = currSharePrice;
        console.log("Bid PLaced for %o shared at %o wei per share", shares, targetSharePrice);
        emit PlaceBid(shares, currSharePrice, block.timestamp );
    }

    function executeBidAndRedeemShares() external {
        require(auctionState == AuctionStates.allocateShares, "Auction yet to to Start");
        require(bids[msg.sender].shares > 0 , "A User has no quoted Bids");

    }
}
