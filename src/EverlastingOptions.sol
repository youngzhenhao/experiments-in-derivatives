//IN PROGRESS...
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7 <0.9.0;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

///@notice An Everlasting Option: Are the same as perpetual futures, but for options.
///The trader gets exposure with no need to roll the position. There is No expiration.
///Everyday, traders who are long pay a "funding fee" to those who are short.
///Funding Fee is a little different from perps.
///Funding Fee = (mark price - payoff price)
///Mark price == current option market price. Payoff price == is the put pay off, so if strike>spot == value, if strike<spot, then payoff is 0 for put option.
///Example: Trader holds the $5000 strike ETH put, will always be able to sell ETH for $5000 as long as trader holds the put.
///Adavantage of this is trader only pays cost when entering or exiting position. No Rolling or worry about expiration.
///But will still pay funding fee q 24 hours (automatically).
///In general: If a perp gets more expensive than an underlying, longs will pay high funding fees.
///This leads to longs selling the perp, returning price to neutral.
contract EverlastingOptions {

}
