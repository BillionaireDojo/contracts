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

contract BillionaireDojoTest is Test, Helper {
    using SafeMath for uint256;

    FightLogic fightLogic;
    Octagon octagon;
    BillionaireDojo dojo;

    event BillionaireMinted(uint256 indexed tokenId);

    function setUp() public {
        vm.startPrank(dev);
        dojo = new BillionaireDojo();
        fightLogic = new FightLogic(dojo);
        octagon = new Octagon(dojo, fightLogic);
        vm.stopPrank();
    }

    function testSetMintPrice() public {
        vm.startPrank(dev);
        uint256 mintPrice = dojo.mintPrice();
        assertEq(mintPrice, 0.007 ether);
        dojo.setMintPrice(0);
        mintPrice = dojo.mintPrice();
        assertEq(mintPrice, 0);
    }

    function testMint() public {
        vm.prank(users[1]);
        vm.roll(123461);
        vm.roll(1687696877);

        vm.expectEmit(true, false, false, false);
        emit BillionaireMinted(1);
        dojo.mint{value: 0.007 ether}(Billionaire.Bezos);
        uint256 count = dojo.count();
        assertEq(count, 1);
        uint256 balance = dojo.balanceOf(users[1]);
        assertEq(balance, 1);
        uint256 teamMemberCount = dojo.teamMemberCount(Billionaire.Bezos);
        assertEq(teamMemberCount, 1);
        uint256 teamBalance = dojo.teamBalances(Billionaire.Bezos);
        assertEq(teamBalance, 1000);

        BillionaireStats memory stat = dojo.getStat(1);
        console.log("Money: ", stat.money);
        console.log("Charisma: ", stat.charisma);
        console.log("Stength: ", stat.strength);
        console.log("Empathy: ", stat.empathy);
        console.log("Stamina: ", stat.stamina);
    }

    function testMintFuzz(uint256 _blocknum, uint256 _tstamp) public {
        Billionaire _billionaire = Billionaire.Zuck;

        vm.assume(_blocknum > 0);
        vm.assume(_blocknum < 999999999999);
        vm.assume(_tstamp > 10);
        vm.assume(_tstamp < 1987696877);

        vm.startPrank(users[1]);
        vm.roll(_blocknum);
        vm.roll(_tstamp);

        uint256 count = dojo.count();
        uint256 balance = dojo.balanceOf(users[1]);
        uint256 teamMemberCount = dojo.teamMemberCount(Billionaire(_billionaire));
        uint256 teamBalance = dojo.teamBalances(Billionaire(_billionaire));

        vm.expectEmit(true, false, false, false);
        emit BillionaireMinted(count+1);
        dojo.mint{value: 0.007 ether}(Billionaire(_billionaire));

        uint256 newBalance = dojo.balanceOf(users[1]);
        uint256 newTeamMemberCount = dojo.teamMemberCount(Billionaire(_billionaire));
        uint256 newTeamBalance = dojo.teamBalances(Billionaire(_billionaire));

        assertEq(balance + 1, newBalance);
        assertEq(teamMemberCount + 1, newTeamMemberCount);
        assertEq(teamBalance + 1000, newTeamBalance);

        BillionaireStats memory stat = dojo.getStat(1);

        assertLe(stat.money, 100);
        assertGe(stat.money, 1);
        assertLe(stat.charisma, 100);
        assertGe(stat.charisma, 1);
        assertLe(stat.strength, 100);
        assertGe(stat.strength, 1);
        assertLe(stat.empathy, 100);
        assertGe(stat.empathy, 1);
        assertLe(stat.stamina, 100);
        assertGe(stat.stamina, 1);
        
        console.log("Money: ", stat.money);
        console.log("Charisma: ", stat.charisma);
        console.log("Stength: ", stat.strength);
        console.log("Empathy: ", stat.empathy);
        console.log("Stamina: ", stat.stamina);

        vm.stopPrank();
    }

    function testCannotMintNotPaid() public {
        vm.expectRevert("Those mega yachts won't pay for themselves kid");
        dojo.mint(Billionaire.Elon);
    }

    function testCannotMintTeamOut() public {
        vm.startPrank(dev);
        dojo.mint{value: 0.007 ether}(Billionaire.Zuck);
        dojo.setOctagon(dev);
        dojo.decreasePlayerBalance(1, 1000);

        vm.expectRevert("This billionaire is busted");
        dojo.mint{value: 0.007 ether}(Billionaire.Zuck);
    }

    function testWithdraw() public {
        vm.prank(users[1]);
        dojo.mint{value: 0.007 ether}(Billionaire.Dorsey);

        uint256 oldBalance = address(users[2]).balance;
        vm.prank(dev);
        dojo.withdraw(users[2]);
        uint256 newBalance = address(users[2]).balance;
        assertEq(oldBalance + 0.007 ether, newBalance);
    }

    function testCannotWithdrawNotOwner() public {
        vm.prank(users[3]);

        bytes4 selector = bytes4(keccak256("OwnableCallerNotTheOwner(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, users[3]));

        dojo.withdraw(users[3]);
    }
}