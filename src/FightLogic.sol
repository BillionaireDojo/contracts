// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./interfaces/IBillionaireDojo.sol";
import "./interfaces/IFightLogic.sol";
import "./interfaces/IOctagon.sol";
import "./Structs.sol";

contract FightLogic is IFightLogic {

    uint256 constant EMPATHY_MULTIPLIER = 15; // 1.5 

    IBillionaireDojo immutable dojo;
    IOctagon octagon;

    constructor(IBillionaireDojo _dojo) {
        dojo = _dojo;
    }

    function setOctagon(IOctagon _octagon) external {
        require(address(octagon) == address(0), "Octagon has been set already");
        octagon = _octagon;
    }

    function fight(
        uint256 player1,
        uint256 player2
    ) public view returns (uint256 winner) {
        BillionaireStats memory statsPlayer1 = dojo.getStat(player1);
        BillionaireStats memory statsPlayer2 = dojo.getStat(player2);

        // get level we're playing on
        OctagonEntry memory entry = octagon.getOctagonEntryForToken(player2);

        LevelInfo memory levelInfo = octagon.getLevelInfo(entry.level);

        uint256 saltPlayer1 = uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), block.timestamp, player2)));
        uint256 saltPlayer2 = uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), block.timestamp, player1)));

        uint256 randomValPlayer1 = (saltPlayer1 % levelInfo.maxRandomVal) + levelInfo.minRandomVal;
        uint256 randomValPlayer2 = (saltPlayer2 % levelInfo.maxRandomVal) + levelInfo.minRandomVal;

        uint256 scorePlayer1 = sumStats(statsPlayer1) + randomValPlayer1;
        uint256 scorePlayer2 = sumStats(statsPlayer2) + randomValPlayer2;

        if (scorePlayer1 > scorePlayer2) {
            return player1;
        } else if (scorePlayer2 > scorePlayer1) {
            return player2;
        } else {
            return 0; // IT's a TIE
        }
    }

    function sumStats(BillionaireStats memory stat) internal pure returns (uint256) {
        uint256 empathy = empathyScore(stat.empathy);
        return stat.money + stat.charisma + empathy + stat.stamina + stat.strength;
    }

    function empathyScore(uint256 _val) internal pure returns (uint256) {
        uint256 res = _val * EMPATHY_MULTIPLIER;
        return (res / 10);
    }
}
