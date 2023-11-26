// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../src/SafeMath.sol";
import "forge-std/src/Test.sol";
import "forge-std/src/console.sol";
import "./Helper.sol";
import "../src/BillionaireDojo.sol";
import "../src/FightLogic.sol";
import "../src/Octagon.sol";
import "../src/Structs.sol";

contract OctagonTest is Test, Helper {
    using SafeMath for uint256;

    FightLogic fightLogic;
    Octagon octagon;
    BillionaireDojo dojo;

    event EnterOctagon(
        uint256 indexed tokenId,
        uint256 indexed level,
        uint8 indexed maxRounds
    );
    event LeaveOctagon(uint256 tokenId);
    event PickAFight(
        uint256 indexed player1,
        uint256 indexed player2,
        uint256 indexed winner
    );

    event EnterRecoveryZone(uint256 tokenId);
    event LeaveRecoveryZone(uint256 tokenId);

    uint256 rand;
    uint256[] notInOctagonFighters;

    function setUp() public {
        vm.startPrank(dev);
        dojo = new BillionaireDojo();
        fightLogic = new FightLogic(dojo);
        octagon = new Octagon(dojo, fightLogic);
        dojo.setOctagon(address(octagon));
        fightLogic.setOctagon(octagon);
        vm.stopPrank();
    }

    function testEnterOctagon() public {
        vm.startPrank(users[1]);
        dojo.mint{value: 0.007 ether}(Billionaire.Cook);

        vm.roll(999);

        vm.expectEmit(true, true, true, false);
        emit EnterOctagon(1, 0, 1);
        octagon.enterOctagon(1, OctagonLevel(0), 1);

        // get in octagon length check ok
        bool _isFighting = octagon.isInOctagon(1);
        assertTrue(_isFighting);

        // get entries check token id is there
        uint256 _entryCount = octagon.getOctagonEntryLength(
            OctagonLevel(0),
            Billionaire.Cook
        );
        assertEq(_entryCount, 1);

        // get entry for token id check ok
        OctagonEntry memory _entry = octagon.getOctagonEntryForToken(1);
        assertEq(uint256(_entry.level), 0);
        assertEq(_entry.tokenId, 1);
        assertEq(_entry.rounds, 1);
        assertEq(_entry.arrayIdx, 0);

        vm.stopPrank();
    }

    function testCannotEnterOctagonNotOwner() public {
        vm.prank(users[1]);
        dojo.mint{value: 0.007 ether}(Billionaire.Cook);

        vm.prank(users[2]);
        vm.expectRevert("Token is not owned by msg.sender");
        octagon.enterOctagon(1, OctagonLevel(0), 1);
    }

    function testCannotEnterOctagonAlreadyIn() public {
        vm.startPrank(users[1]);
        dojo.mint{value: 0.007 ether}(Billionaire.Cook);

        octagon.enterOctagon(1, OctagonLevel(0), 1);
        vm.expectRevert("Player is currently in another fight");
        octagon.enterOctagon(1, OctagonLevel(0), 1);
        vm.stopPrank();
    }

    function testCannotEnterOctagonIsRecovering() public {
        vm.startPrank(users[1]);
        dojo.mint{value: 0.007 ether}(Billionaire.Cook);
        dojo.mint{value: 0.007 ether}(Billionaire.Cook);
        vm.stopPrank();

        vm.startPrank(dev);
        dojo.setOctagon(dev);
        dojo.decreasePlayerBalance(1, 1000);
        dojo.setOctagon(address(octagon));
        vm.stopPrank();

        vm.startPrank(users[1]);
        octagon.enterRecoveryZone(1);

        vm.expectRevert("Player is currently resting");
        octagon.enterOctagon(1, OctagonLevel(0), 1);
    }

    function testCannotEnterOctagonNotEnoughBalance() public {
        vm.startPrank(users[1]);
        dojo.mint{value: 0.007 ether}(Billionaire.Cook);
        dojo.mint{value: 0.007 ether}(Billionaire.Cook);
        vm.stopPrank();

        vm.startPrank(dev);
        dojo.setOctagon(dev);
        dojo.decreasePlayerBalance(1, 1000);
        dojo.setOctagon(address(octagon));
        vm.stopPrank();

        vm.prank(users[1]);
        vm.expectRevert("You don't have enough balance. Try recovery zone");
        octagon.enterOctagon(1, OctagonLevel(0), 1);
    }

    function testLeaveOctagon() public {
        vm.startPrank(users[1]);
        dojo.mint{value: 0.007 ether}(Billionaire.Cook);
        octagon.enterOctagon(1, OctagonLevel(0), 1);
        vm.roll(999);

        vm.expectEmit(true, false, false, false);
        emit LeaveOctagon(1);
        octagon.leaveOctagon(1);

        // get in octagon length check ok
        uint256 _fightsLength = octagon.getFightsLength();
        assertEq(_fightsLength, 0);

        // get entries check token id is there
        uint256 _entryCount = octagon.getOctagonEntryLength(
            OctagonLevel(0),
            Billionaire.Cook
        );
        assertEq(_entryCount, 0);

        // get entry for token id check ok
        OctagonEntry memory _entry = octagon.getOctagonEntryForToken(1);
        assertEq(uint256(_entry.level), 0);
        assertEq(_entry.rounds, 0);
        assertEq(_entry.tokenId, 0);

        bool _isInOctagon = octagon.isInOctagon(1);
        assertFalse(_isInOctagon);
        vm.stopPrank();
    }

    function testCannotLeaveOctagonNotOwner() public {
        vm.startPrank(users[1]);
        dojo.mint{value: 0.007 ether}(Billionaire.Cook);
        octagon.enterOctagon(1, OctagonLevel(0), 1);
        vm.stopPrank();

        vm.prank(users[2]);
        vm.expectRevert("Token is not owned by msg.sender");
        octagon.leaveOctagon(1);
    }

    function testCannotLeaveOctagonNotIn() public {
        vm.startPrank(users[1]);
        dojo.mint{value: 0.007 ether}(Billionaire.Cook);
        vm.expectRevert("Token is currently not in octagon");
        octagon.leaveOctagon(1);
        vm.stopPrank();
    }

    function testPickFight() public {
        vm.startPrank(users[1]);
        dojo.mint{value: 0.007 ether}(Billionaire.Cook);
        vm.roll(37601920);

        vm.expectEmit(true, true, true, false);
        emit EnterOctagon(1, 0, 99);
        octagon.enterOctagon(1, OctagonLevel(0), 99);
        vm.stopPrank();

        vm.startPrank(users[2]);
        dojo.mint{value: 0.007 ether}(Billionaire.Elon);

        octagon.pickAFight(2, OctagonLevel(0), Billionaire.Cook);

        // get fight id
        bytes32 _fightId = octagon.fightIds(0);
        // get fight
        Fight memory _fight = octagon.getFight(_fightId);
        // check p1,p2,winner
        assertEq(_fight.player1, 2);
        assertEq(_fight.player2, 1);

        BillionaireStats memory statPlayer1 = dojo.getStat(_fight.player1);
        BillionaireStats memory statPlayer2 = dojo.getStat(_fight.player2);

        // check that winner balance > and loser balance  <
        if (_fight.winner == _fight.player1) {
            assertEq(statPlayer1.balance, 1500);
            assertEq(statPlayer2.balance, 500);
        } else if (_fight.winner != 0) {
            assertEq(statPlayer2.balance, 1500);
            assertEq(statPlayer1.balance, 500);
        }

        vm.stopPrank();
    }

    /// forge-config: default.fuzz.runs = 10000
    function testPickFightFuzz(uint256 blockNum) public {
        vm.assume(blockNum > 37601920);

        vm.startPrank(users[1]);
        dojo.mint{value: 0.007 ether}(Billionaire.Cook);
        vm.roll(blockNum);

        vm.expectEmit(true, true, true, false);
        emit EnterOctagon(1, 0, 99);
        octagon.enterOctagon(1, OctagonLevel(0), 99);
        vm.stopPrank();

        vm.startPrank(users[2]);
        dojo.mint{value: 0.007 ether}(Billionaire.Elon);

        octagon.pickAFight(2, OctagonLevel(0), Billionaire.Cook);
        vm.stopPrank();

        // get fight id
        bytes32 _fightId = octagon.fightIds(0);
        // get fight
        Fight memory _fight = octagon.getFight(_fightId);
        // check p1,p2,winner
        assertEq(_fight.player1, 2);
        assertEq(_fight.player2, 1);

        BillionaireStats memory statPlayer1 = dojo.getStat(_fight.player1);
        BillionaireStats memory statPlayer2 = dojo.getStat(_fight.player2);

        // check that winner balance > and loser balance  <
        if (_fight.winner == _fight.player1) {
            assertEq(statPlayer1.balance, 1500);
            assertEq(statPlayer2.balance, 500);
        } else if (_fight.winner != 0) {
            assertEq(statPlayer2.balance, 1500);
            assertEq(statPlayer1.balance, 500);
        }
    }

    function testPickFightRandom() public {
        // mint 10 NFTs from each team
        vm.roll(37601925);
        vm.startPrank(users[1]);
        for (uint256 i = 0; i < 6; i++) {
            for (uint256 j = 0; j < 10; j++) {
                Billionaire _b = Billionaire(i);
                dojo.mint{value: 0.007 ether}(_b);
                uint256 _tokenId = dojo.count();
                // enter octagon with five
                if (j % 2 == 0) {
                    octagon.enterOctagon(_tokenId, OctagonLevel(2), 10);
                } else {
                    notInOctagonFighters.push(_tokenId);
                }
            }
        }

        // TODO: Fix over/underflow if loop > 69
        // do this in loop 100x:
        for (uint256 i = 0; i < 100; i++) {
            //  pick a random team and a fighter
            uint256 _fighter = notInOctagonFighters[
                randomNum(notInOctagonFighters.length)
            ];
            BillionaireStats memory _stat = dojo.getStat(_fighter);

            //  pick another random team
            uint256 _otherTeamNum = randomNum(6);
            while (_otherTeamNum == uint256(_stat.billionaire)) {
                _otherTeamNum = randomNum(6);
            }
            
            BillionaireStats memory statBeforeFight = dojo.getStat(_fighter);

            //  run fight
            octagon.pickAFight(
                _fighter,
                OctagonLevel(2),
                Billionaire(_otherTeamNum)
            );

            // check balances
            // get fight id
            bytes32 _fightId = octagon.fightIds(octagon.getFightsLength() - 1);
            Fight memory _fight = octagon.getFight(_fightId);

            BillionaireStats memory statAfterFight = dojo.getStat(_fighter);

            if (_fight.winner == _fighter) {
                assertEq(statAfterFight.balance, statBeforeFight.balance + 150);
            } else {
                assertEq(statAfterFight.balance, statBeforeFight.balance - 150);
            }

        }
        vm.stopPrank();
    }

    function randomNum(uint256 _max) internal returns (uint256) {
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
        return (randomNumber % _max);
    }

    function testCannotPickFightNotOwner() public {
        vm.prank(users[1]);
        dojo.mint{value: 0.007 ether}(Billionaire.Cook);

        vm.prank(users[2]);
        vm.expectRevert("Token is not owned by msg.sender");
        octagon.pickAFight(1, OctagonLevel(0), Billionaire.Bezos);
    }

    function testCannotPickFightInOctagon() public {
        vm.startPrank(users[1]);
        dojo.mint{value: 0.007 ether}(Billionaire.Cook);
        octagon.enterOctagon(1, OctagonLevel(0), 99);
        vm.expectRevert("Player is currently in another fight");
        octagon.pickAFight(1, OctagonLevel(0), Billionaire.Bezos);
        vm.stopPrank();
    }

    function testCannotPickFightIsRecovering() public {
        vm.startPrank(users[1]);
        dojo.mint{value: 0.007 ether}(Billionaire.Cook);
        dojo.mint{value: 0.007 ether}(Billionaire.Cook);
        vm.stopPrank();

        vm.startPrank(dev);
        dojo.setOctagon(dev);
        dojo.decreasePlayerBalance(1, 1000);
        dojo.setOctagon(address(octagon));
        vm.stopPrank();

        vm.startPrank(users[1]);
        octagon.enterRecoveryZone(1);

        vm.expectRevert("Player is currently recovering");
        octagon.pickAFight(1, OctagonLevel(0), Billionaire.Bezos);
        vm.stopPrank();
    }

    function testCannotPickFightNotEnoughBalance() public {
        vm.startPrank(users[1]);
        dojo.mint{value: 0.007 ether}(Billionaire.Cook);
        vm.stopPrank();

        vm.startPrank(dev);
        dojo.setOctagon(dev);
        dojo.decreasePlayerBalance(1, 1000);
        dojo.setOctagon(address(octagon));
        vm.stopPrank();

        vm.startPrank(users[1]);
        vm.expectRevert("Not enough balance for level");
        octagon.pickAFight(1, OctagonLevel(0), Billionaire.Bezos);
        vm.stopPrank();
    }

    function testCannotPickFightSameTeam() public {
        vm.startPrank(users[2]);
        dojo.mint{value: 0.007 ether}(Billionaire.Cook);
        vm.expectRevert("Can't fight your own team");
        octagon.pickAFight(1, OctagonLevel(0), Billionaire.Cook);
        vm.stopPrank();
    }

    function testCannotPickFightNoFightersInOctagonOnOpponentTeam() public {
         //No fighters from that team in the octagon
        vm.startPrank(users[2]);
        dojo.mint{value: 0.007 ether}(Billionaire.Cook);
        vm.expectRevert("No fighters from that team in the octagon");
        octagon.pickAFight(1, OctagonLevel(0), Billionaire.Zuck);
        vm.stopPrank();
    }

    function testEnterRecoveryZone() public {
        vm.startPrank(users[1]);
        dojo.mint{value: 0.007 ether}(Billionaire.Cook);
        dojo.mint{value: 0.007 ether}(Billionaire.Cook);
        vm.stopPrank();

        vm.startPrank(dev);
        dojo.setOctagon(dev);
        dojo.decreasePlayerBalance(1, 1000);
        dojo.setOctagon(address(octagon));
        vm.stopPrank();

        vm.prank(users[1]);
        octagon.enterRecoveryZone(1);

        RecoverInfo memory recoverInfo = octagon.getRecoverInfo(1);

        assertEq(recoverInfo.tokenId, 1);
        assertEq(recoverInfo.recoverStart, 1);
        assertTrue(recoverInfo.isRecovering);
    }

    function testDecreaseRecoverableBalance() public {
        vm.startPrank(users[1]);
        dojo.mint{value: 0.007 ether}(Billionaire.Cook);
        dojo.mint{value: 0.007 ether}(Billionaire.Cook);
        vm.stopPrank();

        uint256 newBalance = 1000;

        for (uint256 i = 0; i < 10; i++) {
            vm.startPrank(dev);
            dojo.setOctagon(dev);
            dojo.decreasePlayerBalance(1, newBalance);
            dojo.setOctagon(address(octagon));
            vm.stopPrank();

            vm.startPrank(users[1]);
            octagon.enterRecoveryZone(1);

            skip(10000);

            octagon.leaveRecoveryZone(1);

            uint256 balance = dojo.getBalance(1);
            console.log(balance);
            if (balance != 1000) {
                assertEq(newBalance - 100, balance);
            }
            vm.stopPrank();
            newBalance = balance;
        }

        vm.startPrank(dev);
        dojo.setOctagon(dev);
        dojo.decreasePlayerBalance(1, newBalance);
        dojo.setOctagon(address(octagon));
        vm.stopPrank();

        vm.prank(users[1]);
        vm.expectRevert("This fighter can't recover anymore");
        octagon.enterRecoveryZone(1);
    }

    function testCannotEnterRecoveryZoneNotOwner() public {
        vm.prank(users[1]);
        dojo.mint{value: 0.007 ether}(Billionaire.Cook);

        vm.expectRevert("Token is not owned by msg.sender");
        octagon.enterRecoveryZone(1);
    }

    function testCannotEnterRecoveryZoneInOctagon() public {
        vm.startPrank(users[1]);
        dojo.mint{value: 0.007 ether}(Billionaire.Cook);

        octagon.enterOctagon(1, OctagonLevel(0), 1);
        vm.expectRevert("Player is currently in a fight");
        octagon.enterRecoveryZone(1);
    }

    function testCannotEnterRecoveryZoneStillHasBalance() public {
        vm.startPrank(users[1]);
        dojo.mint{value: 0.007 ether}(Billionaire.Cook);
        dojo.mint{value: 0.007 ether}(Billionaire.Cook);
        vm.stopPrank();

        vm.prank(users[1]);
        vm.expectRevert("Player still has enough balance");
        octagon.enterRecoveryZone(1);
    }

    function testCannotEnterRecoveryZoneTeamIsOut() public {
        vm.startPrank(users[1]);
        dojo.mint{value: 0.007 ether}(Billionaire.Cook);
        vm.stopPrank();

        vm.startPrank(dev);
        dojo.setOctagon(dev);
        dojo.decreasePlayerBalance(1, 1000);
        dojo.setOctagon(address(octagon));
        vm.stopPrank();

        vm.prank(users[1]);
        vm.expectRevert("This team is out");
        octagon.enterRecoveryZone(1);
    }

    function testLeaveRecoveryZone() public {
        vm.startPrank(users[1]);
        dojo.mint{value: 0.007 ether}(Billionaire.Cook);
        dojo.mint{value: 0.007 ether}(Billionaire.Cook);
        vm.stopPrank();

        vm.startPrank(dev);
        dojo.setOctagon(dev);
        dojo.decreasePlayerBalance(1, 1000);
        dojo.setOctagon(address(octagon));
        vm.stopPrank();

        vm.prank(users[1]);
        octagon.enterRecoveryZone(1);

        // 1 token every ten seconds
        // move clock forward by 1000 seconds -> 100 tokens
        vm.warp(1001);
        vm.prank(users[1]);
        octagon.leaveRecoveryZone(1);

        RecoverInfo memory _recoverInfo = octagon.getRecoverInfo(1);
        assertEq(_recoverInfo.tokenId, 0);
        assertEq(_recoverInfo.recoverStart, 0);
        assertFalse(_recoverInfo.isRecovering);

        BillionaireStats memory stat = dojo.getStat(1);
        assertEq(stat.balance, 100);
    }

    function testLeaveRecoveryZoneFuzz(uint256 currentTstamp) public {
        vm.assume(currentTstamp > 100);
        vm.assume(currentTstamp < 1987696877);

        vm.startPrank(users[1]);
        dojo.mint{value: 0.007 ether}(Billionaire.Cook);
        dojo.mint{value: 0.007 ether}(Billionaire.Cook);
        vm.stopPrank();

        vm.startPrank(dev);
        dojo.setOctagon(dev);
        dojo.decreasePlayerBalance(1, 1000);
        dojo.setOctagon(address(octagon));
        vm.stopPrank();

        vm.prank(users[1]);
        octagon.enterRecoveryZone(1);

        // 1 token every ten seconds
        // move clock forward by 1000 seconds -> 100 tokens
        vm.warp(currentTstamp + 1);

        vm.prank(users[1]);
        octagon.leaveRecoveryZone(1);

        RecoverInfo memory _recoverInfo = octagon.getRecoverInfo(1);
        assertEq(_recoverInfo.tokenId, 0);
        assertEq(_recoverInfo.recoverStart, 0);
        assertFalse(_recoverInfo.isRecovering);

        BillionaireStats memory stat = dojo.getStat(1);

        uint256 lastUpdateTime = _recoverInfo.recoverStart;

        uint256 recoverDuration = (
            ((currentTstamp.sub(lastUpdateTime)).mul(10 ** 18)).div(10)
        );

        uint256 earned = (recoverDuration.mul(1)).div(10 ** 18);

        if (earned > 1000) {
            earned = 1000;
        }

        assertEq(stat.balance, earned);
    }

    function testCannotLeaveRecoveryZoneNotOwner() public {
        vm.startPrank(users[1]);
        dojo.mint{value: 0.007 ether}(Billionaire.Cook);
        dojo.mint{value: 0.007 ether}(Billionaire.Cook);
        vm.stopPrank();

        vm.startPrank(dev);
        dojo.setOctagon(dev);
        dojo.decreasePlayerBalance(1, 1000);
        dojo.setOctagon(address(octagon));
        vm.stopPrank();

        vm.prank(users[1]);
        octagon.enterRecoveryZone(1);

        vm.expectRevert("Token is not owned by msg.sender");
        octagon.leaveRecoveryZone(1);
    }

    function testCannotLeaveRecoveryZoneNotInRecovery() public {
        vm.startPrank(users[1]);
        dojo.mint{value: 0.007 ether}(Billionaire.Cook);
        vm.expectRevert("Player is not recovering");
        octagon.leaveRecoveryZone(1);
    }

    function testConcludeGame() public {
        // mint an nft from each category
        Billionaire[6] memory billionaires = [
            Billionaire.Bezos,
            Billionaire.Cook,
            Billionaire.Dorsey,
            Billionaire.Elon,
            Billionaire.Pichai,
            Billionaire.Zuck
        ];

        for (uint256 i = 0; i < billionaires.length; i++) {
            vm.prank(users[1]);
            dojo.mint{value: 0.007 ether}(billionaires[i]);

            // set balance to 0 except one
            if (i > 0) {
                vm.startPrank(dev);
                dojo.setOctagon(dev);
                dojo.decreasePlayerBalance(i + 1, 1000);
                dojo.setOctagon(address(octagon));
                vm.stopPrank();
            }
        }

        // conclude game
        octagon.concludeGame();

        bool _isGameRunning = octagon.isGameRunning();
        assertFalse(_isGameRunning);
        GameWinner memory _winner = octagon.getGameWinner();
        assertTrue(_winner.isValid);
        assertEq(uint256(_winner.winnerTeam), uint256(Billionaire.Bezos));
    }

    function testCannotConcludeGameNotAllMinted() public {
        vm.expectRevert("At least one token has to be minted in each category");
        octagon.concludeGame();
    }

    function testCannotConcludeGame() public {
        // mint NFT from each category
        Billionaire[6] memory billionaires = [
            Billionaire.Bezos,
            Billionaire.Cook,
            Billionaire.Dorsey,
            Billionaire.Elon,
            Billionaire.Pichai,
            Billionaire.Zuck    
        ];

        for (uint256 i = 0; i < billionaires.length; i++) {
            vm.prank(users[1]);
            dojo.mint{value: 0.007 ether}(billionaires[i]);
        }

        // check game can not be concluded
        vm.expectRevert("Game is not over yet");
        octagon.concludeGame();

        // keep zeroing balances and checking that game can't be concluded
        for (uint256 i = 0; i < billionaires.length - 2; i++) {
            // set balance to 0 except one
            vm.startPrank(dev);
            dojo.setOctagon(dev);
            dojo.decreasePlayerBalance(i + 1, 1000);
            dojo.setOctagon(address(octagon));
            vm.stopPrank();

            vm.expectRevert("Game is not over yet");
            octagon.concludeGame();
        }
    }
}
