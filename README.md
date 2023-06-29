Motivation:

- Create a simple, trustless, decentralized betting platform
- Users can bet on the price of BTC in V1, and multiple assets in V2
- Users bet with USDC
- The winner of the bet gets the loser's USDC
- The winner is determined by the price of BTC at the closing time of the bet
- The winner can withdraw their winnings at any time

Overview flow:

1. Isolated deposit token (USDC) and single betting asset (BTC)
2. Isolated deposit token (USDC) and multiple betting assets (BTC, ETH, LINK, etc.) - V2
3. User A opens a pending bet position
   1. Selects side (long/short)
   2. Bet amount in USDC
   3. Expiration time (counterparty has to accept the bet before this time)
   4. Closing time (what point in time the conditions of the bet must be evaluated)
   5. Deposits USDC
4. User B selects a pending bet to join
   1. Opposing side of User A's bet (short/long)
   2. Deposits USDC (same amount as User A's bet)
5. Bet becomes active
   1. Fetch btcusd price (Chainlink price feed), store in contract
6. Winner is determined once closing time is reached
   1. Fetch btcusd price (Chainlink price feed)
   2. If price is higher than opening price, long wins, else short wins
   3. If long wins, long gets their deposit back + short's deposit
   4. If short wins, short gets their deposit back + long's deposit
   5. Winner withdraws their winnings

Requirements:

git: https://git-scm.com/book/en/v2/Getting-Started-Installing-Git
foundry: https://getfoundry.sh/

Quickstart

git clone https://github.com/smughal55/bet-broker-protocol
cd bet-broker-protocol

Dependencies

Run `forge install smartcontractkit/chainlink-brownie-contracts chainlink-brownie-contracts`

Build

`forge build`

Testing

Run `forge test`
