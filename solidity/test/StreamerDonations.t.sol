// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {StreamerDonations} from "../src/StreamerDonation.sol";

contract StreamerDonationsTest is Test {
    StreamerDonations public donations;

    address public streamer;
    address public donor;

    function setUp() public {
        donations = new StreamerDonations();
        streamer = makeAddr("streamer");
        donor = makeAddr("donor");
        vm.deal(donor, 10 ether);
    }

    /* ---------- registerStreamer ---------- */

    function test_RegisterStreamer() public {
        vm.prank(streamer);
        donations.registerStreamer();

        assertTrue(donations.registeredStreamers(streamer));
    }

    function test_RevertWhen_RegisterStreamer_AlreadyRegistered() public {
        vm.startPrank(streamer);
        donations.registerStreamer();
        vm.expectRevert("Streamer already registered");
        donations.registerStreamer();
        vm.stopPrank();
    }

    /* ---------- donate ---------- */

    function test_Donate() public {
        vm.prank(streamer);
        donations.registerStreamer();

        uint256 amount = 0.01 ether;
        string memory message = "Great stream!";

        vm.prank(donor);
        vm.expectEmit(true, true, true, true);
        emit StreamerDonations.DonationReceived(
            0,
            streamer,
            donor,
            amount,
            message,
            block.timestamp
        );
        donations.donate{value: amount}(streamer, message);

        assertEq(address(streamer).balance, amount);
        assertEq(donations.donationCount(streamer), 1);

        StreamerDonations.Donation memory d = donations.getDonation(streamer, 0);
        assertEq(d.donor, donor);
        assertEq(d.streamer, streamer);
        assertEq(d.amount, amount);
        assertEq(d.message, message);
        assertEq(d.donationId, 0);
    }

    function test_Donate_MultipleDonations() public {
        vm.prank(streamer);
        donations.registerStreamer();

        vm.prank(donor);
        donations.donate{value: 0.01 ether}(streamer, "First");

        vm.prank(donor);
        donations.donate{value: 0.02 ether}(streamer, "Second");

        assertEq(donations.donationCount(streamer), 2);
        assertEq(donations.getDonation(streamer, 0).amount, 0.01 ether);
        assertEq(donations.getDonation(streamer, 1).amount, 0.02 ether);
        assertEq(address(streamer).balance, 0.03 ether);
    }

    function test_RevertWhen_Donate_StreamerIsZero() public {
        vm.prank(donor);
        vm.expectRevert("Invalid streamer");
        donations.donate{value: 0.01 ether}(address(0), "hi");
    }

    function test_RevertWhen_Donate_StreamerNotRegistered() public {
        vm.prank(donor);
        vm.expectRevert("Streamer not registered");
        donations.donate{value: 0.01 ether}(streamer, "hi");
    }

    function test_RevertWhen_Donate_BelowMinimum() public {
        vm.prank(streamer);
        donations.registerStreamer();

        vm.prank(donor);
        vm.expectRevert("Below minimum");
        donations.donate{value: 0.0009 ether}(streamer, "hi");
    }

    function test_Donate_AtMinimumSucceeds() public {
        vm.prank(streamer);
        donations.registerStreamer();

        vm.prank(donor);
        donations.donate{value: 0.001 ether}(streamer, "min");

        assertEq(address(streamer).balance, 0.001 ether);
    }

    function test_RevertWhen_Donate_MessageTooLong() public {
        vm.prank(streamer);
        donations.registerStreamer();

        string memory longMessage = new string(281);
        vm.prank(donor);
        vm.expectRevert("Message too long");
        donations.donate{value: 0.01 ether}(streamer, longMessage);
    }

    function test_Donate_AtMaxMessageLengthSucceeds() public {
        vm.prank(streamer);
        donations.registerStreamer();

        string memory maxMessage = new string(280);
        vm.prank(donor);
        donations.donate{value: 0.01 ether}(streamer, maxMessage);

        assertEq(donations.getDonation(streamer, 0).message, maxMessage);
    }

    /* ---------- getDonation ---------- */

    function test_GetDonation_ReturnsEmptyForNonExistent() public {
        StreamerDonations.Donation memory d = donations.getDonation(streamer, 0);
        assertEq(d.donor, address(0));
        assertEq(d.streamer, address(0));
        assertEq(d.amount, 0);
        assertEq(d.donationId, 0);
    }
}
