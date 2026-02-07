// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract StreamerDonations is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    /// @notice Fee taken from each donation (5%)
    uint256 public constant FEE_PERCENTAGE = 5;

    /// @notice Maximum donation message length
    uint256 public constant MAX_MESSAGE_LENGTH = 280;

    /// @notice Minimum native ETH donation
    uint256 public constant MIN_DONATION_AMOUNT = 0.001 ether;

    /// @notice Minimum for ERC-20 donations (e.g. 1 USDC/USDT with 6 decimals)
    uint256 public constant MIN_ERC20_DONATION_AMOUNT = 1e6;

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
    mapping(address => bool) public registeredStreamers;

    event DonationReceived(
        uint256 indexed donationId,
        address indexed streamer,
        address indexed donor,
        uint256 amount,
        string message,
        uint256 timestamp,
        address token
    );

    event StreamerRegistered(address indexed streamer);

    constructor() Ownable(msg.sender) {}

    /// @notice Register the caller as a streamer eligible to receive donations
    function registerStreamer() external {
        require(!registeredStreamers[msg.sender], "Streamer already registered");
        registeredStreamers[msg.sender] = true;
        emit StreamerRegistered(msg.sender);
    }

    /// @notice Donate native ETH to a registered streamer
    /// @param streamer Registered streamer address
    /// @param message Short message attached to the donation (max 280 chars)
    function donate(address streamer, string calldata message)
        external
        payable
        nonReentrant
        whenNotPaused
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
            (bool feeSuccess,) = owner().call{value: fee}("");
            require(feeSuccess, "Fee transfer failed");
        }
        if (streamerAmount > 0) {
            (bool success,) = streamer.call{value: streamerAmount}("");
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
    /// @param message Short message attached to the donation (max 280 chars)
    function donateWithToken(
        address streamer,
        address token,
        uint256 amount,
        string calldata message
    ) external nonReentrant whenNotPaused {
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

        IERC20 erc20 = IERC20(token);

        if (fee > 0) {
            erc20.safeTransferFrom(msg.sender, owner(), fee);
        }
        if (streamerAmount > 0) {
            erc20.safeTransferFrom(msg.sender, streamer, streamerAmount);
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

    /// @notice Retrieve a specific donation for a streamer
    function getDonation(address streamer, uint256 donationId)
        external
        view
        returns (Donation memory)
    {
        return donations[streamer][donationId];
    }

    /// @notice Pause all donations (emergency stop). Only callable by owner.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause donations. Only callable by owner.
    function unpause() external onlyOwner {
        _unpause();
    }
}
