// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IBetEngine} from "./interfaces/IBetEngine.sol";
import {OracleLib} from "./libs/OracleLib.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IVault} from "./interfaces/IVault.sol";

/*
* @title BetEngine
* @author Shahzad Mughal (Haltoshi)
*
* The BetEngine is a contract that allows users to create bets, join bets,
* and settle bets.
* The BetEngine uses Chainlink Oracles to check the price of BTC/USD.
* The BetEngine uses USDC as the deposit token and is initialised with a Vault during deployment.
* The BetEngine uses a Vault to store USDC deposits.
* One single betting asset (BTC) is used for all bets.
* 1:1 bets are supported. (Long/Short)
*
* @notice This contract is used to create and manage bets.
*/
contract BetEngine is IBetEngine, ReentrancyGuard {
    ///////////////////
    // Errors
    ///////////////////
    error BetEngine__AddressZero();
    error BetEngine__NeedsMoreThanZero();
    error BetEngine__BetNotActive();
    error BetEngine__BetNotClosed();
    error BetEngine__BetNotPending();
    error BetEngine__BetExpired();
    error BetEngine__BetDoesNotExist();
    error BetEngine__CannotJoinSamePosition();
    error BetEngine__CannotJoinOwnBet();
    error BetEngine__CannotJoinBetTwice();
    error BetEngine__BetAmountsMustBeEqual();
    error BetEngine__OnlyWinnerCanWithdraw();
    error BetEngine__OnlyCreatorCanCancel();
    error BetEngine__UserHasNoBet();
    error BetEngine__BetNotSettled();
    error BetEngine__InvalidExpiration();
    error BetEngine__InvalidClosingTime();

    ///////////////////
    // Types
    ///////////////////
    using OracleLib for AggregatorV3Interface;

    /////////////////////////////////////////
    // Contants/Immutables & State Variables
    /////////////////////////////////////////
    uint256 private constant PRECISION = 1e18;
    AggregatorV3Interface public immutable btcusdpriceFeed;

    uint256 private betId;
    IVault private capitalVault;

    /// @dev Mapping of betId to Bet struct
    mapping(uint256 betId => Bet bet) public bets;

    /// @dev Mapping of user to betId to amount
    mapping(address user => mapping(uint256 betId => uint256 amount)) public userBets;

    ///////////////////
    // Modifiers
    ///////////////////
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert BetEngine__NeedsMoreThanZero();
        }
        _;
    }

    ///////////////////
    // Functions
    ///////////////////
    constructor(address btcusdPriceFeedAddress, address vault) {
        if (btcusdPriceFeedAddress == address(0)) revert BetEngine__AddressZero();
        if (vault == address(0)) revert BetEngine__AddressZero();
        btcusdpriceFeed = AggregatorV3Interface(btcusdPriceFeedAddress);
        capitalVault = IVault(vault);
    }

    /// @inheritdoc IBetEngine
    /// @dev depositFrom non revert assumes susccessful token deposit as per SafeERC20
    function openBet(uint256 _amount, Position _position, Expiration _expiration, ClosingTime _closingTime)
        external
        override
        moreThanZero(_amount)
        returns (uint256)
    {
        uint256 _betId = betId++;
        Bet memory bet = Bet(
            _betId,
            _amount,
            0,
            _position,
            _expiration,
            _closingTime,
            Status.PENDING,
            msg.sender,
            address(0),
            address(0),
            uint64(block.timestamp)
        );
        bets[_betId] = bet;
        userBets[msg.sender][_betId] = _amount;
        capitalVault.depositFrom(msg.sender, _amount);
        emit BetPending(_betId);
        return _betId;
    }

    /// @inheritdoc IBetEngine
    /// @dev depositFrom non revert assumes susccessful token deposit as per SafeERC20
    function joinBet(uint256 _betId, uint256 _amount, Position _position) external override moreThanZero(_amount) {
        Bet storage bet = bets[_betId];

        if (bets[_betId].creator == address(0)) revert BetEngine__BetDoesNotExist();
        if (betExpired(_betId)) revert BetEngine__BetExpired();
        if (bet.creatorPosition == _position) revert BetEngine__CannotJoinSamePosition();
        if (bet.status != Status.PENDING) revert BetEngine__BetNotPending();
        if (bet.creator == msg.sender) revert BetEngine__CannotJoinOwnBet();
        if (userBets[msg.sender][_betId] != 0) revert BetEngine__CannotJoinBetTwice();
        if (bet.amount != _amount) revert BetEngine__BetAmountsMustBeEqual();

        userBets[msg.sender][_betId] = _amount;
        bet.status = Status.ACTIVE;
        bet.joiner = msg.sender;
        bet.openingPrice = getBtcUsdPrice();
        capitalVault.depositFrom(msg.sender, _amount);
        emit BetActive(_betId);
    }

    /// @inheritdoc IBetEngine
    function settleBet(uint256 _betId) external override {
        if (!betClosed(_betId)) revert BetEngine__BetNotClosed();
        Bet storage bet = bets[_betId];
        if (bet.status != Status.ACTIVE) revert BetEngine__BetNotActive();

        uint256 closingPrice = getBtcUsdPrice();
        address winner;

        if (
            (bet.creatorPosition == Position.LONG && closingPrice >= bet.openingPrice)
                || (bet.creatorPosition != Position.LONG && closingPrice <= bet.openingPrice)
        ) {
            // creator wins
            winner = bet.creator;
        } else {
            // joiner wins
            winner = bet.joiner;
        }

        uint256 winningAmount = bet.amount + userBets[bet.joiner][_betId];
        userBets[bet.creator][_betId] = 0;
        userBets[bet.joiner][_betId] = 0;
        userBets[winner][_betId] = winningAmount;

        bet.winner = winner;
        bet.status = Status.CLOSED;
        emit BetSettled(_betId, winner);
    }

    /// @inheritdoc IBetEngine
    /// @dev withdraw non revert assumes susccessful token withdrawal as per SafeERC20
    function withdraw(uint256 _betId) external override nonReentrant {
        Bet storage bet = bets[_betId];

        if (bet.creator == address(0)) revert BetEngine__BetDoesNotExist();
        if (bet.winner == address(0)) revert BetEngine__BetNotSettled();
        if (bet.winner != msg.sender) revert BetEngine__OnlyWinnerCanWithdraw();
        if (bet.status != Status.CLOSED) revert BetEngine__BetNotClosed();
        if (userBets[msg.sender][_betId] == 0) revert BetEngine__UserHasNoBet();

        uint256 amount = userBets[msg.sender][_betId];
        userBets[msg.sender][_betId] = 0;
        capitalVault.withdrawTo(msg.sender, amount);
    }

    /// @inheritdoc IBetEngine
    /// @dev withdraw non revert assumes susccessful token withdrawal as per SafeERC20
    function cancelBeforeActive(uint256 _betId) external override nonReentrant {
        Bet storage bet = bets[_betId];

        if (bet.creator == address(0)) revert BetEngine__BetDoesNotExist();
        if (bet.status != Status.PENDING) revert BetEngine__BetNotPending();
        if (bet.creator != msg.sender) revert BetEngine__OnlyCreatorCanCancel();
        if (userBets[msg.sender][_betId] == 0) revert BetEngine__UserHasNoBet();

        uint256 amount = userBets[msg.sender][_betId];
        userBets[msg.sender][_betId] = 0;
        delete bets[_betId];
        capitalVault.withdrawTo(msg.sender, amount);
    }

    function betExpired(uint256 _betId) public view returns (bool) {
        return block.timestamp >= _getBetExpirationTime(_betId);
    }

    function betClosed(uint256 _betId) public view returns (bool) {
        return block.timestamp >= _getBetClosingTime(_betId);
    }

    ///////////////////////////////
    // Private & Internal Functions
    ///////////////////////////////

    function _getBetExpirationTime(uint256 _betId) internal view returns (uint256) {
        Bet storage bet = bets[_betId];
        uint256 duration;

        if (bet.expiration == Expiration.ONE_DAY) {
            duration = 1 days;
        } else if (bet.expiration == Expiration.ONE_WEEK) {
            duration = 1 weeks;
        } else if (bet.expiration == Expiration.TWO_WEEKS) {
            duration = 2 weeks;
        } else {
            revert BetEngine__InvalidExpiration();
        }

        return bet.creationTime + duration;
    }

    function _getBetClosingTime(uint256 _betId) internal view returns (uint256) {
        Bet storage bet = bets[_betId];
        uint256 duration;

        if (bet.closingTime == ClosingTime.THIRTY_DAYS) {
            duration = 30 days;
        } else if (bet.closingTime == ClosingTime.SIXTY_DAYS) {
            duration = 60 days;
        } else if (bet.closingTime == ClosingTime.NINETY_DAYS) {
            duration = 90 days;
        } else {
            revert BetEngine__InvalidClosingTime();
        }

        return bet.creationTime + duration;
    }

    ////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////
    // External & Public View & Pure Functions
    ////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////

    /// @inheritdoc IBetEngine
    function getBet(uint256 _betId) external view override returns (Bet memory) {
        if (bets[_betId].creator == address(0)) revert BetEngine__BetDoesNotExist();
        return bets[_betId];
    }

    /// @dev Returns the price of BTC in USD with 18 decimals
    function getBtcUsdPrice() public view returns (uint256) {
        (, int256 price,,,) = btcusdpriceFeed.staleCheckLatestRoundData();
        return (uint256(price) * PRECISION) / 10 ** btcusdpriceFeed.decimals();
    }
}
