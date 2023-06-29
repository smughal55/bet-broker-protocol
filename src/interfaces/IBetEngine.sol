// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IBetEngine {
    event BetActive(uint256 indexed betId);
    event BetPending(uint256 indexed betId);
    event BetSettled(uint256 indexed betId, address indexed winner);

    enum Position {
        LONG,
        SHORT
    }

    enum Status {
        PENDING,
        ACTIVE,
        CLOSED
    }

    enum Expiration {
        ONE_DAY,
        ONE_WEEK,
        TWO_WEEKS
    }

    enum ClosingTime {
        THIRTY_DAYS,
        SIXTY_DAYS,
        NINETY_DAYS
    }

    struct Bet {
        uint256 betId;
        uint256 amount;
        uint256 openingPrice;
        Position creatorPosition;
        Expiration expiration;
        ClosingTime closingTime;
        Status status;
        address creator;
        address joiner;
        address winner;
        uint64 creationTime;
    }

    /**
     * @notice Opens a new bet
     * @param _amount Amount of USDC to bet
     * @param _position Position of the bet
     * @param _expiration Expiration of the bet
     * @param _closingTime Closing time of the bet
     * @return betId of the new bet
     */
    function openBet(uint256 _amount, Position _position, Expiration _expiration, ClosingTime _closingTime)
        external
        returns (uint256 betId);

    /**
     * @notice Joins an existing bet
     * @param _betId Id of the bet to join
     * @param _amount Amount of USDC to bet
     * @param _position Position of the bet
     */
    function joinBet(uint256 _betId, uint256 _amount, Position _position) external;

    /**
     * @notice Settles an existing bet
     * @param _betId Id of the bet to settle
     */
    function settleBet(uint256 _betId) external;

    /**
     * @notice Withdraws winnings from a settled bet
     * @param _betId Id of the bet to withdraw from
     */
    function withdraw(uint256 _betId) external;

    /**
     * @notice Cancels a bet before it is joined
     * @param _betId Id of the bet to cancel
     */
    function cancelBeforeActive(uint256 _betId) external;

    /**
     * @notice Retrieves a bet by id
     * @param _betId Id of the bet
     */
    function getBet(uint256 _betId) external view returns (Bet memory);
}
