// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

contract StreamerDonations {
    address public owner;

    /// @notice Fee taken from each donation (5%)
    uint256 public constant FEE_PERCENTAGE = 5;

    struct Donation {
        address donor;
        address streamer;
        uint256 amount;
        string message;
        uint256 timestamp;
        uint256 donationId;
        address token; // address(0) = native ETH
    }

    mapping(address => mapping(uint256 => Donation)) public donations;

    mapping(address => uint256) public donationCount;

    event DonationReceived (
        uint256 indexed donationId,
        address indexed streamer,
        address indexed donor,
        uint256 amount,
        string message,
        uint256 timestamp,
        address token
    );

    event StreamerRegistered (address indexed streamer);

    constructor() {
        owner = msg.sender;
    }

    uint256 public constant MAX_MESSAGE_LENGTH = 280;

    uint256 public constant MIN_DONATION_AMOUNT = 0.001 ether;
    /// @notice Minimum for ERC-20 donations (e.g. 1 USDC/USDT with 6 decimals)
    uint256 public constant MIN_ERC20_DONATION_AMOUNT = 1e6;

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
        require(streamer != address(0), "Invalid streamer");
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
            donationId: donationId,
            token: address(0)
        });

        uint256 fee = (msg.value * FEE_PERCENTAGE) / 100;
        uint256 streamerAmount = msg.value - fee;

        if (fee > 0) {
            (bool feeSuccess, ) = owner.call{value: fee}("");
            require(feeSuccess, "Fee transfer failed");
        }
        if (streamerAmount > 0) {
            (bool success, ) = streamer.call{value: streamerAmount}("");
            require(success, "Transfer failed");
        }

        emit DonationReceived(
            donationId,
            streamer,
            msg.sender,
            msg.value,
            message,
            block.timestamp,
            address(0)
        );
    }

    /// @notice Donate using an ERC-20 token (e.g. USDT, USDC). Caller must approve this contract first.
    /// @param streamer Registered streamer address
    /// @param token ERC-20 token contract address
    /// @param amount Amount in token's smallest unit (e.g. 6 decimals for USDC/USDT)
    function donateWithToken(
        address streamer,
        address token,
        uint256 amount,
        string calldata message
    ) external {
        require(streamer != address(0), "Invalid streamer");
        require(registeredStreamers[streamer], "Streamer not registered");
        require(token != address(0), "Invalid token");
        require(amount >= MIN_ERC20_DONATION_AMOUNT, "Below minimum");
        require(bytes(message).length <= MAX_MESSAGE_LENGTH, "Message too long");

        uint256 donationId = donationCount[streamer]++;

        donations[streamer][donationId] = Donation({
            donor: msg.sender,
            streamer: streamer,
            amount: amount,
            message: message,
            timestamp: block.timestamp,
            donationId: donationId,
            token: token
        });

        uint256 fee = (amount * FEE_PERCENTAGE) / 100;
        uint256 streamerAmount = amount - fee;

        if (fee > 0) {
            _safeTransferFrom(IERC20(token), msg.sender, owner, fee);
        }
        if (streamerAmount > 0) {
            uint256 streamerBalanceBefore = IERC20(token).balanceOf(streamer);
            _safeTransferFrom(IERC20(token), msg.sender, streamer, streamerAmount);
            require(
                IERC20(token).balanceOf(streamer) == streamerBalanceBefore + streamerAmount,
                "Transfer failed"
            );
        }

        emit DonationReceived(
            donationId,
            streamer,
            msg.sender,
            amount,
            message,
            block.timestamp,
            token
        );
    }

    /// @dev Safe transferFrom that works with tokens that don't return bool (e.g. USDT on mainnet)
    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool ok, ) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        require(ok, "transferFrom failed");
    }

    function getDonation(address streamer, uint256 donationId)
    external
    view
    returns (Donation memory)  
    {
        return donations[streamer][donationId];
    }
}