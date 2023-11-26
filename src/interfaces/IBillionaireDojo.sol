// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "../Structs.sol";

interface IBillionaireDojo {
    event SetOctagon(address octagon);

    function getStat(uint256 tokenId) external view returns (BillionaireStats memory); 

    function teamBalances(Billionaire billionaire) external view returns (uint256);

    function teamMemberCount(Billionaire billionaire) external view returns (uint256);

    function decreasePlayerBalance(uint256 player, uint256 decrease) external;

    function increasePlayerBalance(uint256 player, uint256 increase) external;

    function getBalance(uint256 tokenId) external view returns (uint256);
}
