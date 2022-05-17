// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TestNanner is ERC721Enumerable, Ownable {

    //EVENTS
    event TokenMinted(uint tokenIndex);


    //DATA STORAGE
    mapping (address => uint256) public whitelistedCounts;
    mapping (uint256 => uint256) public bitesLeft;
    mapping (address => bool) public isExcluded;
    mapping (uint256 => address) public originalOwner;
    string private baseURI = "ipfs://QmPh1fqHUjLi5zLXAq93FZ3h1aRzCEPNDVEXKFXFdVtPtW/";
    string public backupURI = "ipfs://QmPh1fqHUjLi5zLXAq93FZ3h1aRzCEPNDVEXKFXFdVtPtW/";
    uint public maxBites = 5;
    uint public MINTS_NO_OAPE = 2;
    uint public MINTS_MAX_OAPE = 20;
    uint public OAPE_THRESHOLD = 10000 ether;
    uint public eatenCount = 0;
    uint public peelCount = 0;
    bool public lockPeels = true;
    bool public standardize = false;
    IERC721 OAC = IERC721(0xCaB23D5Fb9a5d64F0755914C17e283Ff6563641d);
    IERC721 TG = IERC721(0x0000000000000000000000000000000000000000);
    IERC20 OAPE = IERC20(0xf4dEAd672d2E3e16A3dCAeF4C2bA7Cb1b4D304Ff);


    //BASIC ERC721 THINGS
    constructor() ERC721("TestNanner", "TNANNER") {
        isExcluded[owner()] = true;
        isExcluded[address(0)] = true;
        isExcluded[0x7bc8b1B5AbA4dF3Be9f9A32daE501214dC0E4f3f] = true; //marketplace
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        if (standardize) {
            return bytes(backupURI).length > 0 ? string(abi.encodePacked(backupURI)) : "";
        }
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, _toString(bitesLeft[tokenId]), ".json")) : "";
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override {
        if(!isExcluded[to] && !isExcluded[from] && lockPeels) {
            require(whitelistedCounts[to] == 0, "friend not hungry");
            require(bitesLeft[tokenId] != 0, "no more nanner");

            uint mintableCount = getMintCount(from);
            if (mintableCount > whitelistedCounts[msg.sender]) {
                whitelistedCounts[msg.sender] = mintableCount;
            }
            bitesLeft[tokenId] -= 1;
            peelCount += 1;
            if (bitesLeft[tokenId] == 0) {
                whitelistedCounts[originalOwner[tokenId]] +=1;
                eatenCount += 1;
            }
        }
        super._beforeTokenTransfer(from, to, tokenId);
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


    // CUSTOM NANNER STUFF
    function airdropLaunch(uint ripeBananas) external onlyOwner {
        for (uint i = 0; i < ripeBananas; i++) {
            uint mintIndex = totalSupply() + 1;
            bitesLeft[mintIndex] = 5;
            originalOwner[mintIndex] = OAC.ownerOf(mintIndex);
            _safeMint(OAC.ownerOf(mintIndex), mintIndex);
        }
    }

    function devMint(uint numToMint) external onlyOwner {
        for (uint i = 0; i < numToMint; i++) {
            uint mintIndex = totalSupply() + 1;
            bitesLeft[mintIndex] = 5;
            originalOwner[mintIndex] = msg.sender;
            _safeMint(msg.sender, mintIndex);
        } 
    }


    // ADMIN
    function setBaseURI(string memory uri) external onlyOwner {
        baseURI = uri;
    }

    function setParent(address parent) external onlyOwner {
        OAC = IERC721(parent);
    }

    function setTG(address _tg) external onlyOwner {
        TG = IERC721(_tg);
    }

    function setToken(address token) external onlyOwner {
        OAPE = IERC20(token);
    }

    function flipLock() external onlyOwner {
        lockPeels = !lockPeels;
    }

    function flipExclude(address _addy) external onlyOwner {
        isExcluded[_addy] = !isExcluded[_addy];
    }

    function decrementWL(address minter) external {
        require(msg.sender == owner() || msg.sender == address(TG));
        require(whitelistedCounts[minter] != 0, "not whitelisted");
        whitelistedCounts[minter] -= 1;
    }

    function setWL(address _addy, uint mints) external onlyOwner {
        whitelistedCounts[_addy] = mints;
    }

    function useBackupURI(bool _value, string memory _uri) external onlyOwner {
        standardize = _value;
        backupURI = _uri;
    }


    // WITHRDRAWALS
    receive() external payable { }

    function recoverToken(address _token, uint256 amount) external virtual onlyOwner {
        IERC20(_token).transfer(owner(), amount);
    }

    function withdraw(address payable to, uint256 amount) external onlyOwner {
        to.transfer(amount);
    }


    // HELPER FUNCTIONS
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

    function getMintCount(address oapeHolder) public view returns (uint) {
        uint oapeBalance = OAPE.balanceOf(oapeHolder);
        if (oapeBalance >= OAPE_THRESHOLD) {
            return MINTS_MAX_OAPE;
        } else {
            return MINTS_NO_OAPE;
        }
    }
}
