// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployBetEngine} from "../../script/DeployBetEngine.s.sol";
import {IBetEngine} from "src/interfaces/IBetEngine.sol";
import {BetEngine} from "src/BetEngine.sol";
import {Vault} from "src/Vault.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract BetEngineTest is Test {
    DeployBetEngine deployer;
    Vault vault;
    BetEngine betEngine;
    HelperConfig helperConfig;
    address btcUsdPriceFeed;
    address usdc;

    address public USERA = makeAddr("userA");
    address public USERB = makeAddr("userB");
    uint256 amountToMint = 100 ether;
    uint256 public constant STARTING_USER_BALANCE = 1000 ether;

    function setUp() public {
        deployer = new DeployBetEngine();
        (vault, betEngine, helperConfig) = deployer.run();
        (, btcUsdPriceFeed,,, usdc,) = helperConfig.activeNetworkConfig();
        ERC20Mock(usdc).mint(USERA, STARTING_USER_BALANCE);
        ERC20Mock(usdc).mint(USERB, STARTING_USER_BALANCE);
    }

    ///////////////////////
    // Constructor Tests //
    ///////////////////////

    function testRevertsIfPriceFeedAddressZero() public {
        vm.expectRevert(BetEngine.BetEngine__AddressZero.selector);
        new BetEngine(address(0), address(vault));
    }

    function testRevertsIfVaultAddressZero() public {
        vm.expectRevert(BetEngine.BetEngine__AddressZero.selector);
        new BetEngine(btcUsdPriceFeed, address(0));
    }

    modifier approveUsdcForUserA() {
        vm.startPrank(USERA);
        ERC20Mock(usdc).approve(address(vault), STARTING_USER_BALANCE);
        ERC20Mock(usdc).approve(address(betEngine), STARTING_USER_BALANCE);
        vm.stopPrank();
        _;
    }

    modifier approveUsdcForUserB() {
        vm.startPrank(USERB);
        ERC20Mock(usdc).approve(address(vault), STARTING_USER_BALANCE);
        ERC20Mock(usdc).approve(address(betEngine), STARTING_USER_BALANCE);
        vm.stopPrank();
        _;
    }

    ///////////////////
    // openBet Tests //
    ///////////////////

    modifier openBet() {
        vm.startPrank(USERA);
        betEngine.openBet(
            1000, IBetEngine.Position.LONG, IBetEngine.Expiration.ONE_DAY, IBetEngine.ClosingTime.THIRTY_DAYS
        );
        vm.stopPrank();
        _;
    }

    modifier joinBet() {
        vm.startPrank(USERB);
        betEngine.joinBet(0, 1000, IBetEngine.Position.SHORT);
        vm.stopPrank();
        _;
    }

    function testRevertsIfBetAmountIsZero() public approveUsdcForUserA {
        vm.startPrank(USERA);
        vm.expectRevert(BetEngine.BetEngine__NeedsMoreThanZero.selector);
        betEngine.openBet(
            0, IBetEngine.Position.LONG, IBetEngine.Expiration.ONE_DAY, IBetEngine.ClosingTime.THIRTY_DAYS
        );
        vm.stopPrank();
    }

    function testOpenBet() public approveUsdcForUserA {
        vm.startPrank(USERA);
        uint256 betId = betEngine.openBet(
            1000, IBetEngine.Position.LONG, IBetEngine.Expiration.ONE_DAY, IBetEngine.ClosingTime.THIRTY_DAYS
        );

        IBetEngine.Bet memory bet = betEngine.getBet(betId);
        assertEq(bet.amount, 1000);
        assertEq(uint256(bet.creatorPosition), uint256(IBetEngine.Position.LONG));
        assertEq(uint256(bet.expiration), uint256(IBetEngine.Expiration.ONE_DAY));
        assertEq(uint256(bet.closingTime), uint256(IBetEngine.ClosingTime.THIRTY_DAYS));
        assertEq(uint256(bet.status), uint256(IBetEngine.Status.PENDING));
        assertEq(bet.creator, address(USERA));
        assertEq(bet.joiner, address(0));
        assertEq(bet.winner, address(0));
        vm.stopPrank();
    }

    ///////////////////
    // joinBet Tests //
    ///////////////////

    function testRevertsIfBetIdDoesNotExist() public approveUsdcForUserB {
        vm.startPrank(USERB);
        vm.expectRevert(BetEngine.BetEngine__BetDoesNotExist.selector);
        betEngine.joinBet(1, 1000, IBetEngine.Position.SHORT);
        vm.stopPrank();
    }

    function testRevertsIfBetAmountsNotEqual() public approveUsdcForUserB approveUsdcForUserA openBet {
        vm.startPrank(USERB);
        vm.expectRevert(BetEngine.BetEngine__BetAmountsMustBeEqual.selector);
        betEngine.joinBet(0, 1001, IBetEngine.Position.SHORT);
        vm.stopPrank();
    }

    function testRevertsIfBetExpired() public approveUsdcForUserB approveUsdcForUserA openBet {
        vm.startPrank(USERB);
        vm.warp(24 hours + 1 seconds);
        vm.expectRevert(BetEngine.BetEngine__BetExpired.selector);
        betEngine.joinBet(0, 1000, IBetEngine.Position.SHORT);
        vm.stopPrank();
    }

    function testJoinBet() public approveUsdcForUserB approveUsdcForUserA openBet {
        vm.startPrank(USERB);
        betEngine.joinBet(0, 1000, IBetEngine.Position.SHORT);
        vm.stopPrank();

        IBetEngine.Bet memory bet = betEngine.getBet(0);
        assertEq(bet.amount, 1000);
        assertEq(bet.creator, address(USERA));
        assertEq(bet.joiner, address(USERB));
    }

    //////////////////
    // settle Tests //
    //////////////////

    function testRevertsWhenCallingSettleWhilstStillActive()
        public
        approveUsdcForUserB
        approveUsdcForUserA
        openBet
        joinBet
    {
        vm.startPrank(USERA);
        IBetEngine.Bet memory bet = betEngine.getBet(0);
        assertEq(uint256(bet.status), uint256(IBetEngine.Status.ACTIVE));
        vm.expectRevert(BetEngine.BetEngine__BetNotClosed.selector);
        betEngine.settleBet(0);
        vm.stopPrank();
    }

    function testSettleBetUserAWins() public approveUsdcForUserB approveUsdcForUserA openBet joinBet {
        vm.startPrank(USERA);
        vm.warp(31 days);
        MockV3Aggregator(btcUsdPriceFeed).updateAnswer(25600e8);
        betEngine.settleBet(0);
        vm.stopPrank();

        IBetEngine.Bet memory bet = betEngine.getBet(0);
        assertEq(uint256(bet.status), uint256(IBetEngine.Status.CLOSED));
        assertEq(bet.winner, address(USERA));
    }

    function testSettleBetUserBWins() public approveUsdcForUserB approveUsdcForUserA openBet joinBet {
        vm.startPrank(USERA);
        vm.warp(31 days);
        MockV3Aggregator(btcUsdPriceFeed).updateAnswer(24600e8);
        betEngine.settleBet(0);
        vm.stopPrank();

        IBetEngine.Bet memory bet = betEngine.getBet(0);
        assertEq(uint256(bet.status), uint256(IBetEngine.Status.CLOSED));
        assertEq(bet.winner, address(USERB));
    }

    /////////////////////////////
    // withdraw & cancel Tests //
    /////////////////////////////

    function testRevertsIfBetIdDoesNotExistWhenCallingWithdraw() public {
        vm.startPrank(USERA);
        vm.expectRevert(BetEngine.BetEngine__BetDoesNotExist.selector);
        betEngine.withdraw(0);
        vm.stopPrank();
    }

    function testWithdraw() public approveUsdcForUserB approveUsdcForUserA openBet joinBet {
        vm.startPrank(USERA);
        vm.warp(31 days);
        MockV3Aggregator(btcUsdPriceFeed).updateAnswer(25600e18);
        betEngine.settleBet(0);
        betEngine.withdraw(0);
        vm.stopPrank();

        assertEq(ERC20Mock(usdc).balanceOf(address(USERA)), STARTING_USER_BALANCE + 1000);
        assertEq(ERC20Mock(usdc).balanceOf(address(USERB)), STARTING_USER_BALANCE - 1000);
        assertEq(ERC20Mock(usdc).balanceOf(address(betEngine)), 0);
    }

    function testRevertsIfBetIdDoesNotExistWhenCallingCancelBeforeActive() public {
        vm.startPrank(USERA);
        vm.expectRevert(BetEngine.BetEngine__BetDoesNotExist.selector);
        betEngine.cancelBeforeActive(0);
        vm.stopPrank();
    }

    function testCancelBeforeActive() public approveUsdcForUserB approveUsdcForUserA openBet {
        vm.startPrank(USERA);
        betEngine.cancelBeforeActive(0);
        vm.stopPrank();

        vm.expectRevert(BetEngine.BetEngine__BetDoesNotExist.selector);
        betEngine.getBet(0);
    }

    /////////////////////////////
    // misc Tests //
    /////////////////////////////

    function testBtcUsdPrice() public {
        assertEq(betEngine.getBtcUsdPrice(), 25600e18);
    }
}
