// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
@dev Minimal interface for fight logic contracts
Fight function that takes two tokens and produces a winner
Logic can be swapped to more complex logic later in the Octagon contract
 */
interface IFightLogic {
    function fight(uint256 player1, uint256 player2) external view returns (uint256 winner);
}