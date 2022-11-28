// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "../lib/RoleControl.sol";

contract StakingNFT is 
    Initializable,
    UUPSUpgradeable,
    ERC721Upgradeable,
    RoleControl
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    CountersUpgradeable.Counter private _tokenIdTracker;
    string private _baseTokenURI;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}
    
    function initialize(string calldata name_, string calldata symbol_) public initializer {
        __UUPSUpgradeable_init();
        __RoleControl_init();
        __ERC721_init(name_, symbol_);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Upgradeable, RoleControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function mint(address to) public onlyMinter {
        uint256 tokenId = _tokenIdTracker.current();
        _safeMint(to, tokenId);
        _tokenIdTracker.increment();
    }

    function setBaseURI(string calldata uri) external onlyAdmin {
        _baseTokenURI = uri;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}
}