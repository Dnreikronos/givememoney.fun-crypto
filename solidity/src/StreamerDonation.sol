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

    mapping(bytes32 => bool) public processedTxHashes;


    event DonationReceived (
        uint256 indexed donationId,
        address indexed streamer,
        address indexed donor,
        uint256 amount,
        string message,
        uint256 timestamp 
    );
}