// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface NannerWL {
    function whitelistedCounts(address user) external view returns (uint256);
    function decrementWL(address minter) external;
}

contract TestGorillers is ERC721Enumerable, Ownable {

    event LevelChange(address indexed owner, uint256 indexed tokenId, uint256 indexed newLevel, uint256 oldLevel, uint256 timestamp);
    event MultiplierChange(address indexed owner, uint256 indexed tokenId, uint256 indexed newLevel, uint256 oldLevel, uint256 timestamp);

    // MINT + COLLECTION DETAILS
    enum Batch { ONE, TWO, THREE }
    NannerWL NANNER_WHITELIST = NannerWL(0x49a670506377dfBe60bDA8214ac45f6840a92b3f);
    uint256 public tokenPrice = 250 ether;
    uint256 private mintMax = 10;
    uint256 public constant MAX_SUPPLY = 6666;
    uint256 public constant BATCH_MAX = 2222;
    uint256 private constant BATCH_ONE_MIN = 1;
    uint256 private constant BATCH_ONE_MAX = 2222;
    uint256 private constant BATCH_TWO_MIN = 2223;
    uint256 private constant BATCH_TWO_MAX = 4444;
    uint256 private constant BATCH_THREE_MIN = 4445;
    uint256 private constant BATCH_THREE_MAX = 6666;
    uint256 private constant TEAM_ALLOC_PER_BATCH = 50;
    string private HIDDEN_BASE = "ipfs://";
    bool public saleIsActive = false;
    bool public useWhitelist = false;
    mapping(Batch => bool) public batchSaleIsActive;
    mapping(Batch => bool) public batchHidden;
    mapping(Batch => string) public batchURI;
    mapping(Batch => uint256) public batchMinted;
    mapping(Batch => uint256) public batchOffset;
    mapping(address => bool) public administrators;

    // GAME RELATED DETAILS
    enum Type { FIRE, WATER, EARTH, AIR, LIGHTNING, NANNER }
    mapping(uint256 => uint256) private gorillerMultiplier;
    mapping(uint256 => uint256) public gorillerLevel;
    mapping(uint256 => Type) public gorillerType;
    uint256 public MAX_LEVEL = 6969;
    uint256 public MIN_LEVEL = 0;
    struct Goriller { uint256 tokenId; string uri; uint256 baseLevel; uint256 multiplier; uint256 totalLevel; Type baseType; }


    // PERMISSIONS FOR BATTLE/ARENA CONTRACT
    modifier onlyAdmins {
        require(administrators[_msgSender()] || owner() == _msgSender(), "Not owner or admin.");
        _;
    }


    // STANDARD FUNCTIONS
    constructor() ERC721("ThicccqGorillers", "THICQ") {
        batchURI[Batch.ONE] = "ipfs://";
        batchURI[Batch.TWO] = "ipfs://";
        batchURI[Batch.THREE] = "ipfs://";
        batchOffset[Batch.ONE] = 1;
        batchOffset[Batch.TWO] = 2223;
        batchOffset[Batch.THREE] = 4445;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        if (tokenId >= BATCH_ONE_MIN && tokenId <= BATCH_ONE_MAX) {
            return batchHidden[Batch.ONE] ? HIDDEN_BASE : string(abi.encodePacked(batchURI[Batch.ONE], _toString(tokenId), ".json"));
        } else if (tokenId >= BATCH_TWO_MIN && tokenId <= BATCH_TWO_MAX) {
            return batchHidden[Batch.TWO] ? HIDDEN_BASE : string(abi.encodePacked(batchURI[Batch.TWO], _toString(tokenId), ".json"));
        } else {
            return batchHidden[Batch.THREE] ? HIDDEN_BASE : string(abi.encodePacked(batchURI[Batch.THREE], _toString(tokenId), ".json"));
        }

    }

    function mint(uint256 numTokens, Batch _batch, Type _type) public payable {
        if (msg.sender != owner()) {
            require(saleIsActive, "Mint not active.");
            require(batchSaleIsActive[_batch], "Batch minting disabled.");
            require((batchMinted[_batch] + numTokens <= BATCH_MAX) && (numTokens + totalSupply() <= MAX_SUPPLY), "Above max.");
            require(numTokens <= mintMax, "Above max.");
            require(msg.value >= numTokens * tokenPrice, "Insufficient funds.");
            if (useWhitelist) require(NANNER_WHITELIST.whitelistedCounts(msg.sender) > numTokens, "");

        }
        if(_batch == Batch.ONE) require(_type == Type.FIRE || _type == Type.WATER);
        if(_batch == Batch.TWO) require(_type == Type.EARTH || _type == Type.AIR);
        if(_batch == Batch.THREE) require(_type == Type.LIGHTNING || _type == Type.NANNER);

        uint mintStartIndex = batchOffset[_batch] + batchMinted[_batch];
        for (uint i = mintStartIndex; i < numTokens + mintStartIndex;) {
            batchMinted[_batch] += 1;
            if (useWhitelist) NANNER_WHITELIST.decrementWL(msg.sender);

            gorillerLevel[i] = 1;
            gorillerMultiplier[i] = 1;
            gorillerType[i] = _type;

            _safeMint(msg.sender, i);
            unchecked { ++i; }
        }

        if (batchMinted[_batch] >= 2222) batchSaleIsActive[_batch] = false;
    }

    function tokensOfOwner(address _owner) external view returns(uint256[] memory ) {
        uint256 tokenCount = balanceOf(_owner);
        if (tokenCount == 0) {
            // Return an empty array
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            uint256 index;
            for (index = 0; index < tokenCount; index++) {
                result[index] = tokenOfOwnerByIndex(_owner, index);
            }
            return result;
        }
    }


    // GAME/LEVELING
    function incrementLevel(uint256 tokenId) external onlyAdmins {
        uint256 oldLevel = gorillerLevel[tokenId];
        require(oldLevel < MAX_LEVEL, "Max level reached.");
        setLevel(tokenId, oldLevel + 1);
    }

    function decrementLevel(uint256 tokenId) external onlyAdmins {
        uint256 oldLevel = gorillerLevel[tokenId];
        require(oldLevel != 0, "RIP, negative level.");
        setLevel(tokenId, oldLevel - 1);
    }

    function setLevel(uint256 tokenId, uint256 newLevel) public onlyAdmins {
        emit LevelChange(ownerOf(tokenId), tokenId, newLevel, gorillerLevel[tokenId], block.timestamp);
        gorillerLevel[tokenId] = newLevel;
    }

    function setMultiplier(uint256 tokenId, uint256 multiplier) external onlyAdmins {
        gorillerMultiplier[tokenId] = multiplier;
    }

    function setMaxLevel(uint256 _maxLevel) external onlyAdmins {
        require((_maxLevel >= MIN_LEVEL) && (_maxLevel >= 0), "Invalid max level.");
        MAX_LEVEL = _maxLevel;
    }

    function setMinLevel(uint256 _minLevel) external onlyAdmins {
        require(_minLevel <= MAX_LEVEL, "Invalid min level.");
        MIN_LEVEL = _minLevel;
    }

    function setType(uint256 tokenId, Type _type) external onlyAdmins {
        gorillerType[tokenId] =  _type;
    }

    function gorillerDetails(uint256 tokenId) external view returns (Goriller memory) {
        return Goriller(
            tokenId, 
            tokenURI(tokenId), 
            gorillerLevel[tokenId], 
            gorillerMultiplier[tokenId], 
            gorillerLevel[tokenId] * gorillerMultiplier[tokenId],
            gorillerType[tokenId]);
    }


    // HELPERS
    function _toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    function flipBatchMinting(Batch batch) external onlyAdmins {
        batchSaleIsActive[batch] = !batchSaleIsActive[batch];
    }

    function flipBatchHidden(Batch batch) external onlyAdmins {
        batchHidden[batch] = !batchHidden[batch];
    }

    function flipSale() external onlyAdmins {
        saleIsActive = !saleIsActive;
    }

    function setAdmin(address _administrator) external onlyOwner {
        administrators[_administrator] = !administrators[_administrator];
    }

    function setMintPrice(uint256 _tokenPrice) external onlyOwner {
        tokenPrice = _tokenPrice;
    }

    function setMintMax(uint256 _mintMax) external onlyOwner {
        mintMax = _mintMax;
    }

    function flipUseWL() external onlyOwner {
        useWhitelist = !useWhitelist;
    }


    // WITHRDRAWALS
    receive() external payable { }

    function recoverToken(address _token, uint256 amount) external virtual onlyOwner {
        IERC20(_token).transfer(owner(), amount);
    }

    function withdraw(address payable to, uint256 amount) external onlyOwner {
        to.transfer(amount);
    }

}