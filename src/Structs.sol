// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
@dev List of billionaires that can be minted
 */
enum Billionaire {
    Bezos,
    Cook,
    Dorsey,
    Elon,
    Pichai,
    Zuck
}

/**
@dev Stats that each billionaire NFT gets some random value between 1-100 of
Each billionaire starts with 1000 in balance 
 */
struct BillionaireStats {
    Billionaire billionaire;
    uint256 money;
    uint256 charisma;
    uint256 strength;
    uint256 empathy;
    uint256 stamina;
    uint256 balance;
}

enum OctagonLevel {
    MANIAC,
    NORMAL,
    BABY
}

struct OctagonEntry {
    OctagonLevel level;
    uint8 rounds;
    uint256 tokenId;
    uint256 arrayIdx;
}

struct Fight {
    bytes32 id;
    uint256 player1;
    uint256 player2;
    OctagonLevel level;
    uint256 created;
    uint256 winner;
}

struct LevelInfo {
    uint256 buyIn;
    uint256 maxRandomVal;
    uint256 minRandomVal;
}

/**
@dev Info about an NFT that entered the recovery zone
@param tokenId ID of the NFT
@param recoverStart block.timestamp when token entered recovery zone
@param isRecovering boolean that's true if token is recovering currently, false otherwise
 */
struct RecoverInfo {
    uint256 tokenId;
    uint256 recoverStart;
    bool isRecovering;
}

/**
@dev This struct will hold the info about the eventual winner team of the game
@param winnerTeam the team that won
@param isValid this will be true if game already won, false otherwise
 */
struct GameWinner {
    Billionaire winnerTeam;
    bool isValid;
}

/**
@dev struct that we use in the frontend to get all the info needed to render a card in one on-chain query
 */
struct TokenInfo {
    bool isInOctagon;
    uint256 balance;
    RecoverInfo recoverInfo;
    OctagonEntry octagonEntry;
}