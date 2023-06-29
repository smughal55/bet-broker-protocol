// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {Vault} from "src/Vault.sol";
import {BetEngine} from "src/BetEngine.sol";
import {DeployBetEngine} from "../../script/DeployBetEngine.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract VaultTest is Test {
    DeployBetEngine deployer;
    Vault vault;
    BetEngine betEngine;
    HelperConfig helperConfig;
    address btcUsdPriceFeed;
    address usdc;

    address public USERA = makeAddr("userA");
    uint256 public constant STARTING_USER_BALANCE = 1000 ether;

    function setUp() public {
        deployer = new DeployBetEngine();
        (vault, betEngine, helperConfig) = deployer.run();
        (, btcUsdPriceFeed,,, usdc,) = helperConfig.activeNetworkConfig();
        ERC20Mock(usdc).mint(USERA, STARTING_USER_BALANCE);
        ERC20Mock(usdc).mint(address(betEngine), STARTING_USER_BALANCE);
    }

    ///////////////////////
    // Constructor Tests //
    ///////////////////////

    function testRevertsIfTokenAddressZero() public {
        vm.expectRevert(Vault.Vault__AddressZero.selector);
        new Vault(address(0));
    }

    modifier approveUsdcForUserA() {
        vm.startPrank(USERA);
        ERC20Mock(usdc).approve(address(vault), STARTING_USER_BALANCE);
        vm.stopPrank();
        _;
    }

    ///////////////////////
    // depositFrom Tests //
    ///////////////////////

    function testRevertsIfDepositZero() public {
        vm.startPrank(address(betEngine));
        vm.expectRevert(Vault.Vault__AddressZero.selector);
        vault.depositFrom(address(0), 0);
        vm.stopPrank();
    }

    function testRevertsIfDepositFromZero() public {
        vm.startPrank(address(betEngine));
        vm.expectRevert(Vault.Vault__DepositZero.selector);
        vault.depositFrom(USERA, 0);
    }

    function testRevertsIfDepositFromNonOwner() public {
        vm.startPrank(address(USERA));
        vm.expectRevert("Ownable: caller is not the owner");
        vault.depositFrom(USERA, STARTING_USER_BALANCE);
    }

    function testDeposit() public approveUsdcForUserA {
        vm.startPrank(address(betEngine));
        vault.depositFrom(USERA, STARTING_USER_BALANCE);
        assertEq(ERC20Mock(usdc).balanceOf(address(vault)), STARTING_USER_BALANCE);
        vm.stopPrank();
    }

    //////////////////////
    // withdrawTo Tests //
    //////////////////////

    function testRevertsIfWithdrawZero() public {
        vm.startPrank(address(betEngine));
        vm.expectRevert(Vault.Vault__AddressZero.selector);
        vault.withdrawTo(address(0), 0);
        vm.stopPrank();
    }

    function testRevertsIfWithdrawToZero() public {
        vm.startPrank(address(betEngine));
        vm.expectRevert(Vault.Vault__WithdrawZero.selector);
        vault.withdrawTo(USERA, 0);
        vm.stopPrank();
    }

    function testRevertsIfWithdrawFromNonOwner() public {
        vm.startPrank(address(USERA));
        vm.expectRevert("Ownable: caller is not the owner");
        vault.withdrawTo(USERA, STARTING_USER_BALANCE);
        vm.stopPrank();
    }

    function testWithdraw() public approveUsdcForUserA {
        vm.startPrank(address(betEngine));
        vault.depositFrom(USERA, STARTING_USER_BALANCE);
        vault.withdrawTo(USERA, STARTING_USER_BALANCE);
        assertEq(ERC20Mock(usdc).balanceOf(address(vault)), 0);
        vm.stopPrank();
    }
}
