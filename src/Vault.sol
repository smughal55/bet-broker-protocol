// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IVault} from "./interfaces/IVault.sol";

/**
 * @title Vault
 * @author Shahzad Mughal (Haltoshi)
 * @notice A simple vault that holds an underlying ERC20 asset.
 * @dev User balances must be managed by the owning contract.
 *      Owning contract must adhere to the CEI pattern for withdrawing funds,
 *          it's not the responsiblity of this contract.
 */
contract Vault is IVault, Ownable {
    ///////////////////
    // Errors
    ///////////////////
    error Vault__AddressZero();
    error Vault__DepositZero();
    error Vault__WithdrawZero();

    ///////////////////
    // Types
    ///////////////////
    using SafeERC20 for IERC20;

    ///////////////////
    // State Variables
    ///////////////////
    IERC20 public underlying;

    ///////////////////
    // Functions
    ///////////////////
    constructor(address underlying_) {
        if (underlying_ == address(0)) revert Vault__AddressZero();
        underlying = IERC20(underlying_);
    }

    /// @inheritdoc IVault
    function depositFrom(address _from, uint256 _amount) public onlyOwner {
        if (_from == address(0)) revert Vault__AddressZero();
        if (_amount == 0) revert Vault__DepositZero();
        underlying.safeTransferFrom(_from, address(this), _amount);
    }

    /// @inheritdoc IVault
    function withdrawTo(address _to, uint256 _amount) public onlyOwner {
        if (_to == address(0)) revert Vault__AddressZero();
        if (_amount == 0) revert Vault__WithdrawZero();
        underlying.safeTransfer(_to, _amount);
    }
}
