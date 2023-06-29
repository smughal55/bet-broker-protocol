// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IVault {
    /**
     * @notice Returns the underlying ERC20 asset of the Vault.
     */
    function underlying() external view returns (IERC20);

    /**
     * @notice Deposits `amount_` of the underlying asset into the Vault.
     * @param _from Address to deposit from.
     * @param _amount Amount of the underlying asset to deposit.
     */
    function depositFrom(address _from, uint256 _amount) external;

    /**
     * @notice Withdraws `amount_` of the underlying asset from the Vault.
     * @param _to Address to withdraw to.
     * @param _amount Amount of the underlying asset to withdraw.
     */
    function withdrawTo(address _to, uint256 _amount) external;
}
