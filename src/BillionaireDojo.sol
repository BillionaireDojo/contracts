// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@lukso/LSP8/extensions/LSP8CompatibleERC721.sol";
import { _LSP4_CREATORS_ARRAY_KEY, _LSP4_CREATORS_MAP_KEY_PREFIX } from "@lukso/LSP4/LSP4Constants.sol";
import { _LSP8_TOKENID_TYPE_KEY } from "@lukso/LSP8/LSP8Constants.sol";
import "./interfaces/IBillionaireDojo.sol";
import "./Base64.sol";
import "./Constants.sol";

/*  Goal of the game is to mint NFTs of billionaires and people can fight them. */
contract BillionaireDojo is  LSP8CompatibleERC721, IBillionaireDojo, Constants, ReentrancyGuard {
    uint rand;
    uint256 public count;
    uint256 public mintPrice = 0.007 ether;
    address octagon;
    // mapping(uint256 => BillionaireStats) public stats;

    mapping(Billionaire => uint256) public teamMemberCount; // number of members in each billionaire team
    mapping(Billionaire => uint256) public teamBalances; // score for each billionaire team

    event BillionaireMinted(uint256 indexed tokenId);

    modifier onlyOctagon() {
        require(msg.sender == octagon, "Only octagon can call");
        _;
    }

    constructor() LSP8CompatibleERC721("Billionaire Dojo", "DOJO", msg.sender, 0) {
        // Setting the creator attribution metadata
        _setData(_LSP4_CREATORS_ARRAY_KEY, hex"01");
        _setData(0x114bd03b3a46d48759680d81ebb2b41400000000000000000000000000000000, hex"4E86B0301067Ab10e505B0d4C44e9E01d024A068");
        bytes32 creatorsMapKey = bytes32(abi.encodePacked(_LSP4_CREATORS_MAP_KEY_PREFIX, 0x4E86B0301067Ab10e505B0d4C44e9E01d024A068));
        _setData(creatorsMapKey , hex"667674970000000000000000");
    }

    function mint(Billionaire _billionaire) external payable nonReentrant {
        require(msg.value == mintPrice, "Those mega yachts won't pay for themselves kid");
        require(teamMemberCount[_billionaire] == 0 || teamBalances[_billionaire] > 0, "This billionaire is busted");

        uint256 _money = generateMoneyTrait();
        uint256 _charisma = generateTrait();
        uint256 _strength = generateTrait();
        uint256 _empathy = generateEmpathyTrait();
        uint256 _stamina = generateTrait();

        count++;

        BillionaireStats memory _stat = BillionaireStats(_billionaire, _money, _charisma, _strength, _empathy, _stamina, 1000);
        _setStat(count, _stat);

        _mint(msg.sender, bytes32(count), true, "");
        // _safeMint(msg.sender, count);
        teamMemberCount[_billionaire]++;
        teamBalances[_billionaire] += 1000;
        emit BillionaireMinted(count);
    }

    function mintMultiple(Billionaire _billionaire, uint256 _num) external payable nonReentrant {
        uint256 _price = mintPrice * _num;
        require(_num > 0 && _num < 6, "Minimum 1 and maximum 5 can be minted at once");
        require(msg.value == _price, "Those mega yachts won't pay for themselves kid");
        require(teamMemberCount[_billionaire] == 0 || teamBalances[_billionaire] > 0, "This billionaire is busted");

        for (uint256 i = 0; i < _num; i++) {
            uint256 _money = generateMoneyTrait();
            uint256 _charisma = generateTrait();
            uint256 _strength = generateTrait();
            uint256 _empathy = generateEmpathyTrait();
            uint256 _stamina = generateTrait();

            count++;

            //stats[count] = BillionaireStats(_billionaire, _money, _charisma, _strength, _empathy, _stamina, 1000);
            BillionaireStats memory _stat = BillionaireStats(_billionaire, _money, _charisma, _strength, _empathy, _stamina, 1000);
            _setStat(count, _stat);

            _mint(msg.sender, bytes32(count), true, "");
            //_safeMint(msg.sender, count);
            teamMemberCount[_billionaire]++;
            teamBalances[_billionaire] += 1000;
            emit BillionaireMinted(count);
        }
    }

    function setMintPrice(uint256 _mintPrice) external onlyOwner {
        mintPrice = _mintPrice;
    }

    function setOctagon(address _octagon) external onlyOwner {
        require(_octagon != address(0), "Octagon can't be set to the zero address");
        octagon = _octagon;
        emit SetOctagon(_octagon);
    }

    function setPunchlines(string[6] memory _punchlines) external onlyOwner {
        _setPunchlines(_punchlines);
    }

    function setImgUrls(string[6] memory _imgUrls) external onlyOwner {
        _setImgUrls(_imgUrls);
    }

    function decreasePlayerBalance(uint256 player, uint256 decrease) external onlyOctagon {
        BillionaireStats memory _stat = _getStat(player);
        _stat.balance -= decrease;
        _setStat(player, _stat);

        //stats[player].balance -= decrease;
        teamBalances[_stat.billionaire] -= decrease;
    }

    function increasePlayerBalance(uint256 player, uint256 increase) external onlyOctagon {
        BillionaireStats memory _stat = _getStat(player);
        _stat.balance += increase;
        _setStat(player, _stat);

        //stats[player].balance += increase;
        teamBalances[_stat.billionaire] += increase;
    }

    /**
    @dev Currently not called anywhere
    If the game finishes and players wish to start a new game a new Octagon contract can be deployed and that contract can call this method to reset team balances
     */
    function resetBalance() external onlyOctagon {
        Billionaire[6] memory billionaires = [
            Billionaire.Bezos,
            Billionaire.Cook,
            Billionaire.Dorsey,
            Billionaire.Elon,
            Billionaire.Pichai,
            Billionaire.Zuck
        ];

        for (uint256 i = 0; i < billionaires.length; i++) {
            teamBalances[billionaires[i]] = 0;
        }
    }

    /**
     * @dev Returns the token URI for a token.
     * @param _tokenId The id of the token.
     */
    function tokenURI(uint256 _tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(_exists(bytes32(_tokenId)), "Token does not exist");
        return _formatTokenUri(_tokenId);
    }

    function getStat(uint256 tokenId) external view returns (BillionaireStats memory) {
        // return stats[tokenId];
        return _getStat(tokenId);
    }

    function getBalance(uint256 tokenId) external view returns (uint256) {
        BillionaireStats memory _stat = _getStat(tokenId);
        return _stat.balance;
        // return stats[tokenId].balance;
    }

    function _setStat(uint256 _tokenId, BillionaireStats memory _stat) internal {
        bytes memory _statBytes = abi.encode(_stat);
        _setData(bytes32(_tokenId), _statBytes);
    }

    function _getStat(uint256 _tokenId) internal view returns (BillionaireStats memory) {
        bytes memory _statBytes = _getData(bytes32(_tokenId));
        return abi.decode(_statBytes, (BillionaireStats));
    }

    function generateTrait() internal returns (uint256) {
        rand++;
        uint256 randomNumber = uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), block.timestamp, rand)));
        return (randomNumber % 100) + 1; // Generate a random number between 1 and 100
    }

    function generateEmpathyTrait() internal returns (uint256) {
        rand++;
        uint256 randomNumber = uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), block.timestamp, rand)));

        if (randomNumber % 10 == 0) {
            return (randomNumber % 100) + 1;
        } else {
            return (randomNumber % 20) + 1; // we're not so high on empathy :(
        }
    }

    function generateMoneyTrait() internal returns (uint256) {
        rand++;
        uint256 randomNumber = uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), block.timestamp, rand)));

        return (randomNumber % 11) + 90; // but we have a lot of $$$ :)
    }

    function withdraw(address to) external onlyOwner {
        require(to != address(0), "Can't withdraw to the zero address");
        (bool success, ) = to.call{value: address(this).balance}("");
        require(success, "Withdraw failed");
    }

    function _generateAttributesString(
        BillionaireStats memory _stat
    ) internal pure returns (string memory) {
        return 
            string(
                abi.encodePacked(
                    Strings.toString(_stat.money),
                    '},{"display_type": "number", "trait_type": "charisma", "value": ',
                    Strings.toString(_stat.charisma),
                    '},{"display_type": "number", "trait_type": "strength", "value": ',
                    Strings.toString(_stat.strength),
                    '},{"display_type": "number", "trait_type": "empathy", "value": ',
                    Strings.toString(_stat.empathy),
                    '},{"display_type": "number", "trait_type": "stamina", "value": ',
                    Strings.toString(_stat.stamina),
                    '}]}'
                )
            );
    }

    function _formatTokenUri(
        uint256 _tokenId
    ) internal view returns (string memory) {
        BillionaireStats memory stat = _getStat(_tokenId);  
        string memory _name = names[uint256(stat.billionaire)];
        string memory _punchline = punchlines[uint256(stat.billionaire)];
        string memory _imgUri = imgUrls[uint256(stat.billionaire)];
        string memory _attString = _generateAttributesString(stat);
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name": "Billionaire Dojo", "description": "Simulation hypothesis confirmed. Will these billionaires fuck each other up?", "image": "',
                                _imgUri,
                                '", "attributes": [',
                                '{"trait_type": "billionaire", "value": "',
                                _name,
                                '"}, {"trait_type": "punchline", "value": "',
                                _punchline,
                                '"}, {"display_type": "number", "trait_type": "money", "value": ',
                                _attString
                            )
                        )
                    )
                )
            );
    }
}
