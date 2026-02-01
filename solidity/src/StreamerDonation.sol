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

