// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./SafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./BillionaireDojo.sol";
import "./interfaces/IFightLogic.sol";
import "./interfaces/IOctagon.sol";
import "./Structs.sol";

contract Octagon is IOctagon, Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    uint256 rand;

    bool public isGameRunning = true;

    uint256 public constant RECOVERY_AMOUNT = 1;
    uint256 public constant RECOVERY_AMOUNT_ACCRUE_DURATION = 10; // 1 token every 10 seconds

    BillionaireDojo immutable dojo;
    IFightLogic immutable fightLogic;

    mapping(OctagonLevel => LevelInfo) public levelInfo;

    mapping(OctagonLevel => mapping(Billionaire => uint256[])) public entries; // mapping from level to team to token id
    mapping(uint256 => OctagonEntry) public entryForToken;

    mapping(bytes32 => Fight) public fightHistory;
    bytes32[] public fightIds;

    mapping(uint256 => bool) public isInOctagon;

    mapping(uint256 => RecoverInfo) public recoverInfos; // which tokens are currently recovering

    uint256 public inOctagonLength;

    GameWinner public gameWinner;

    modifier onlyIfGameRunning() {
        require(isGameRunning, "Game is not running");
        _;
    }

    constructor(BillionaireDojo _dojo, IFightLogic _fightLogic) Ownable(msg.sender) {
        levelInfo[OctagonLevel.MANIAC] = LevelInfo(500, 2000, 1000);
        levelInfo[OctagonLevel.NORMAL] = LevelInfo(300, 600, 300);
        levelInfo[OctagonLevel.BABY] = LevelInfo(150, 300, 100);

        dojo = _dojo;
        fightLogic = _fightLogic;
    }

    function enterOctagon(
        uint256 _tokenId,
        OctagonLevel _level,
        uint8 _maxRounds
    ) external nonReentrant {
        // check that owner of token ID is msg sender
        require(
            dojo.ownerOf(_tokenId) == msg.sender,
            "Token is not owned by msg.sender"
        );

        // check that token ID is not currently involved in another fight
        require(
            isInOctagon[_tokenId] == false,
            "Player is currently in another fight"
        );

        // check that player is not recovering
        require(
            recoverInfos[_tokenId].isRecovering == false,
            "Player is currently resting"
        );

        // check that token id has enough balance to cover bet
        BillionaireStats memory playerStat = dojo.getStat(_tokenId);
        require(
            playerStat.balance >= levelInfo[_level].buyIn,
            "You don't have enough balance. Try recovery zone"
        );

        uint256 idx = entries[_level][playerStat.billionaire].length;
        // create Octagon entry struct
        OctagonEntry memory entry = OctagonEntry(
            _level,
            _maxRounds,
            _tokenId,
            idx
        );

        // append struct to entries array in correct place
        entries[_level][playerStat.billionaire].push(_tokenId);

        entryForToken[_tokenId] = entry;

        isInOctagon[_tokenId] = true;
        inOctagonLength++;

        // emit event
        emit EnterOctagon(_tokenId, uint256(_level), _maxRounds);
    }

    function leaveOctagon(uint256 _tokenId) external nonReentrant {
        // check that owner of token ID is msg sender
        require(
            dojo.ownerOf(_tokenId) == msg.sender,
            "Token is not owned by msg.sender"
        );

        require(
            isInOctagon[_tokenId] == true,
            "Token is currently not in octagon"
        );

        BillionaireStats memory playerStat = dojo.getStat(_tokenId);
        _removeTokenEntry(_tokenId, playerStat.billionaire);

        isInOctagon[_tokenId] = false;
        inOctagonLength--;

        emit LeaveOctagon(_tokenId);
    }

    function pickAFight(
        uint256 _tokenId,
        OctagonLevel _level,
        Billionaire _opponentTeam
    ) external nonReentrant {
        // check that owner of token ID is msg sender
        require(
            dojo.ownerOf(_tokenId) == msg.sender,
            "Token is not owned by msg.sender"
        );

        // check that token is not in octagon already
        require(
            isInOctagon[_tokenId] == false,
            "Player is currently in another fight"
        );

        // check that token is not recovering
        require(
            recoverInfos[_tokenId].isRecovering == false,
            "Player is currently recovering"
        );

        // check that token has enough balance
        BillionaireStats memory _stat = dojo.getStat(_tokenId);
        require(
            _stat.balance >= levelInfo[_level].buyIn,
            "Not enough balance for level"
        );
        // check that token team and opponent team are not the same
        require(
            _stat.billionaire != _opponentTeam,
            "Can't fight your own team"
        );

        // pick a random opponent
        // get length of array of oppoennt team fighters
        uint256 length = entries[_level][_opponentTeam].length;
        require(length > 0, "No fighters from that team in the octagon");

        // generate random number for opponent -> pick opponent
        uint256 opponentIdx = randomFighter(length);

        uint256 opponent = entries[_level][_opponentTeam][opponentIdx];

        // run fight
        uint256 winner = fightLogic.fight(_tokenId, opponent);

        bytes32 fightId = keccak256(
            abi.encodePacked(_tokenId, opponent, block.timestamp, winner)
        );
        Fight memory newFight = Fight(
            fightId,
            _tokenId,
            opponent,
            _level,
            block.timestamp,
            winner
        );

        // update balances & handle ties
        uint256 betAmount = levelInfo[_level].buyIn;

        if (winner != 0) {
            dojo.increasePlayerBalance(winner, betAmount);
            uint256 loser = winner == _tokenId ? opponent : _tokenId;
            dojo.decreasePlayerBalance(loser, betAmount);

            // if player who is in the octagon loses, we check its balance
            // if balance is lower than min bet we remove it from the octagon
            BillionaireStats memory playerStat = dojo.getStat(loser);
            if (loser == opponent && playerStat.balance < betAmount) {
                _removeTokenEntry(loser, playerStat.billionaire);
                isInOctagon[loser] = false;
                inOctagonLength--;
            }
        }

        OctagonEntry memory tokenEntry = entryForToken[opponent];

        bool isOpponentInOctagon = isInOctagon[opponent];
        if (isOpponentInOctagon) {
            if (tokenEntry.rounds == 1) {
                _removeTokenEntry(opponent, _opponentTeam);
                isInOctagon[opponent] = false;
                inOctagonLength--;
            } else {
                entryForToken[opponent].rounds--;
            }
        }

        fightHistory[fightId] = newFight;
        fightIds.push(fightId);

        emit PickAFight(_tokenId, opponent, winner);
    }

    function enterRecoveryZone(uint256 _tokenId) external nonReentrant {
        // check that owner of player2 is msg sender
        require(
            dojo.ownerOf(_tokenId) == msg.sender,
            "Token is not owned by msg.sender"
        );

        // check that token id is not currently involved in another fight
        require(
            isInOctagon[_tokenId] == false,
            "Player is currently in a fight"
        );

        BillionaireStats memory stat = dojo.getStat(_tokenId);
        require(
            stat.balance < levelInfo[OctagonLevel.BABY].buyIn,
            "Player still has enough balance"
        );
        require(dojo.teamBalances(stat.billionaire) > 0, "This team is out");

        recoverInfos[_tokenId] = RecoverInfo(_tokenId, block.timestamp, true);
    }

    function leaveRecoveryZone(uint256 _tokenId) external nonReentrant {
        require(
            dojo.ownerOf(_tokenId) == msg.sender,
            "Token is not owned by msg.sender"
        );

        RecoverInfo memory recoverInfo = recoverInfos[_tokenId];
        require(recoverInfo.isRecovering, "Player is not recovering");

        uint256 currentBlock = block.timestamp;
        uint256 lastUpdateTime = recoverInfo.recoverStart;

        uint256 recoverDuration = (
            ((currentBlock.sub(lastUpdateTime)).mul(10 ** 18)).div(
                RECOVERY_AMOUNT_ACCRUE_DURATION
            )
        );

        uint256 earned = (recoverDuration.mul(RECOVERY_AMOUNT)).div(10 ** 18);

        if (earned > 1000) {
            earned = 1000;
        }

        dojo.increasePlayerBalance(_tokenId, earned);
        recoverInfos[_tokenId] = RecoverInfo(0, 0, false);
    }

    function getTokenInfo(
        uint256 _tokenId
    ) external view returns (TokenInfo memory) {
        return
            TokenInfo(
                isInOctagon[_tokenId],
                dojo.getBalance(_tokenId),
                recoverInfos[_tokenId],
                entryForToken[_tokenId]
            );
    }

    function getOctagonEntryForToken(
        uint256 _tokenId
    ) external view returns (OctagonEntry memory) {
        return entryForToken[_tokenId];
    }

    function getLevelInfo(
        OctagonLevel _level
    ) external view returns (LevelInfo memory) {
        return levelInfo[_level];
    }

    // getting the length of each octagon entry array ->
    // this can be used on the FE to query the whole array and display all the open entries
    function getOctagonEntryLength(
        OctagonLevel _level,
        Billionaire _billionaire
    ) external view returns (uint256) {
        return entries[_level][_billionaire].length;
    }

    function getFightsLength() external view returns (uint256) {
        return fightIds.length;
    }

    function getRecoverInfo(
        uint256 _tokenId
    ) external view returns (RecoverInfo memory) {
        return recoverInfos[_tokenId];
    }

    function getFight(bytes32 _fightId) external view returns (Fight memory) {
        return fightHistory[_fightId];
    }

    function getGameWinner() external view returns (GameWinner memory) {
        return gameWinner;
    }

    function _removeTokenEntry(
        uint256 _tokenId,
        Billionaire _billionaire
    ) internal {
        // get entry info for token id
        OctagonEntry memory _entryInfo = entryForToken[_tokenId];

        // get length of the array that stores the ID
        uint256 length = entries[_entryInfo.level][_billionaire].length;

        // if it is the last ID we're deleting just pop the item
        if (_entryInfo.arrayIdx == length - 1) {
            entries[_entryInfo.level][_billionaire].pop();
            entryForToken[_tokenId] = OctagonEntry(
                OctagonLevel.MANIAC,
                0,
                0,
                0
            );
            return;
        }

        // get the last element otherwise
        uint256 lastTokenId = entries[_entryInfo.level][_billionaire][
            length - 1
        ];
        // set the deletable index to the last element
        entries[_entryInfo.level][_billionaire][
            _entryInfo.arrayIdx
        ] = lastTokenId;
        entryForToken[lastTokenId].arrayIdx = _entryInfo.arrayIdx;

        // pop the last element
        entries[_entryInfo.level][_billionaire].pop();
        entryForToken[_tokenId] = OctagonEntry(OctagonLevel.MANIAC, 0, 0, 0);
    }

    function randomFighter(uint256 _maxNum) internal returns (uint256) {
        rand++;
        uint256 randomNumber = uint256(
            keccak256(
                abi.encodePacked(
                    blockhash(block.number - 1),
                    block.timestamp,
                    rand
                )
            )
        );
        return (randomNumber % _maxNum);
    }

    function concludeGame() external onlyIfGameRunning {
        // check that only one team has all the balance
        Billionaire[6] memory billionaires = [
            Billionaire.Bezos,
            Billionaire.Cook,
            Billionaire.Dorsey,
            Billionaire.Elon,
            Billionaire.Pichai,
            Billionaire.Zuck
        ];

        Billionaire _winner;
        uint256 _winnerBalance;

        for (uint256 i = 0; i < billionaires.length; i++) {
            require(
                dojo.teamMemberCount(billionaires[i]) > 0,
                "At least one token has to be minted in each category"
            );
            uint256 _balance = dojo.teamBalances(billionaires[i]);
            if (_winnerBalance != 0 && _balance != 0) {
                revert("Game is not over yet");
            }

            if (_winnerBalance == 0 && _balance != 0) {
                _winner = billionaires[i];
                _winnerBalance = _balance;
            }
        }
        // set game running to false
        isGameRunning = false;
        gameWinner = GameWinner(_winner, true);
    }
}
