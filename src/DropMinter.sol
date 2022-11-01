// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721 as ERC721S} from "@rari-capital/solmate/src/tokens/ERC721.sol";

contract DropMinter is ERC721S, Ownable {
    address public authorizedMinter;

    struct Drop {
        uint128 maxSupply;
        uint128 circulating;
        // TODO: start date?
    }

    uint256 nextDropId = 1;
    mapping(uint256 => Drop) public drops;

    string public baseURI = "https://nft.franzmoro.com/metadata";

    modifier onlyAuthorizedMinter() {
        require(msg.sender == authorizedMinter, "Unauthorized");
        _;
    }

    constructor() ERC721S("MinterFranz", "MFRZ") {}

    function setBaseURI(string calldata _baseURI) public onlyOwner {
        baseURI = _baseURI;
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

    function maxSupply(uint256 dropId) public view returns (uint128) {
        return drops[dropId].maxSupply;
    }

    function circulating(uint256 dropId) public view returns (uint128) {
        return drops[dropId].circulating;
    }

    function createDrop(uint128 supply)
        public
        onlyAuthorizedMinter
        returns (uint256)
    {
        require(supply > 0, "Supply must be gt 0");

        uint256 dropId = nextDropId;

        nextDropId++;
        drops[dropId] = Drop(supply, 0);

        return dropId;
    }

    function setMaxSupply(uint256 dropId, uint128 amount)
        external
        onlyAuthorizedMinter
    {
        Drop memory drop = drops[dropId];

        if (drop.maxSupply == 0) {
            revert("Drop does not exist");
        }
        require(drop.circulating == 0, "Cannot edit supply after minting");

        drops[dropId].maxSupply = amount;
    }

    function getNextTokenId(uint256 dropId) internal view returns (uint256) {
        uint256 nameSpace = dropId * 10000;
        return nameSpace + drops[dropId].circulating;
    }

    function mint(address to, uint256 dropId) external onlyAuthorizedMinter {
        Drop memory drop = drops[dropId];

        require(drop.maxSupply > 0, "Supply not set");
        require(drop.circulating < drop.maxSupply, "Sold out");

        // extreme simplification for singleAuction...
        uint256 tokenId = getNextTokenId(dropId);

        drops[dropId].circulating++;

        return ERC721S._safeMint(to, tokenId);
    }
}
