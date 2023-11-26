// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../Structs.sol";

interface IOctagon {
    event EnterOctagon(uint256 indexed tokenId, uint256 indexed level, uint8 indexed maxRounds);
    event LeaveOctagon(uint256 tokenId);
    event PickAFight(uint256 indexed player1, uint256 indexed player2, uint256 indexed winner);
    
    event EnterRecoveryZone(uint256 tokenId);
    event LeaveRecoveryZone(uint256 tokenId);

    function enterOctagon(uint256 _tokenId, OctagonLevel _level, uint8 _maxRounds) external;

    function leaveOctagon(uint256 _tokenId) external;

    function pickAFight(uint256 _tokenId, OctagonLevel _level, Billionaire _opponentTeam) external;

    function enterRecoveryZone(uint256 _tokenId) external;

    function leaveRecoveryZone(uint256 _tokenId) external;

    function getOctagonEntryForToken(uint256 _tokenId) external view returns (OctagonEntry memory);

    function getLevelInfo(OctagonLevel _level) external view returns (LevelInfo memory);
}