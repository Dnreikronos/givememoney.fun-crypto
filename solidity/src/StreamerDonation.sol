// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;



contract StreamerDonations {
    struct Donation {
        address donor;
        address streamer;
        uint256 amount;
        string message;
        uint256 timestamp;
        uint256 donationId;
    }


    mapping(address => mapping(uint256 => Donation)) public donations;

    mapping(address => uint256) public donationCount;

    event DonationReceived (
        uint256 indexed donationId,
        address indexed streamer,
        address indexed donor,
        uint256 amount,
        string message,
        uint256 timestamp 
    );


    event StreamerRegistered (address indexed streamer);

    uint256 public constant MAX_MESSAGE_LENGTH = 280;
    
    uint256 public constant MIN_DONATION_AMOUNT = 0.001 ether;

    mapping(address => bool) public registeredStreamers;

        modifier onlyRegisteredStreamer() {
        require(registeredStreamers[msg.sender], "Not registered");
        _;
        
    }

    function registerStreamer() external {
        require(!registeredStreamers[msg.sender], "Streamer already registered");
        registeredStreamers[msg.sender] = true;
        emit StreamerRegistered(msg.sender);
    }

       function donate(address streamer, string calldata message) 
        external 
        payable 
    {
        require(registeredStreamers[streamer], "Streamer not registered");
        require(msg.value >= MIN_DONATION_AMOUNT, "Below minimum");
        require(bytes(message).length <= MAX_MESSAGE_LENGTH, "Message too long");
        
        uint256 donationId = donationCount[streamer]++;
        
        donations[streamer][donationId] = Donation({
            donor: msg.sender,
            streamer: streamer,
            amount: msg.value,
            message: message,
            timestamp: block.timestamp,
            donationId: donationId
        });
        
        // Transfer immediately to streamer
        (bool success, ) = streamer.call{value: msg.value}("");
        require(success, "Transfer failed");
        
        emit DonationReceived(
            donationId,
            streamer,
            msg.sender,
            msg.value,
            message,
            block.timestamp
        );
    }
    
}