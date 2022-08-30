// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721 as ERC721S} from "@rari-capital/solmate/src/tokens/ERC721.sol";

contract Minter is ERC721S, Ownable {
    address public authorizedMinter;

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

    function mint(address to, uint256 tokenId) external onlyAuthorizedMinter {
        return ERC721S._safeMint(to, tokenId);
    }
}
