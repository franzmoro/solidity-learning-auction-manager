// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721 as ERC721S} from "@rari-capital/solmate/src/tokens/ERC721.sol";

contract DropMinter is ERC721S, Ownable {
    address public authorizedMinter;

    mapping(uint256 => uint128) public maxSupply; // dropId --> max
    mapping(uint256 => uint128) public circulating; // dropId --> circulating

    string public baseURI = "https://nft.franzmoro.com/metadata";

    modifier onlyAuthorizedMinter() {
        require(msg.sender == authorizedMinter, "Unauthorized");
        _;
    }

    constructor() ERC721S("MinterFranz", "MFRZ") {}

    function setBaseURI(string calldata _baseURI) public onlyOwner {
        baseURI = _baseURI;
    }

    function setMaxSupply(uint256 dropId, uint128 amount)
        external
        onlyAuthorizedMinter
    {
        maxSupply[dropId] = amount;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        return string(abi.encodePacked(baseURI, "/", tokenId));
    }

    function setAuthorizer(address _authorizedMinter) public onlyOwner {
        authorizedMinter = _authorizedMinter;
    }

    function getNextTokenId(uint256 dropId) internal view returns (uint256) {
        uint256 nameSpace = dropId * 10000;
        return nameSpace + circulating[dropId];
    }

    function mint(address to, uint256 dropId) external onlyAuthorizedMinter {
        require(maxSupply[dropId] > 0, "Supply not set");
        require(circulating[dropId] < maxSupply[dropId], "Sold out");

        // extreme simplification for singleAuction...
        uint256 tokenId = getNextTokenId(dropId);

        circulating[dropId]++;

        return ERC721S._safeMint(to, tokenId);
    }
}
