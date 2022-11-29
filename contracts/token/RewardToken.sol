// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "../lib/RoleControlUpgradeable.sol";

contract RewardToken is 
    Initializable,
    UUPSUpgradeable,
    ERC20Upgradeable,
    RoleControlUpgradeable
{   
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}
    
    function initialize(string calldata name_, string calldata symbol_) public initializer {
        __UUPSUpgradeable_init();
        __ERC20_init(name_, symbol_);
        __RoleControl_init();
    }

    function mint(address to, uint256 amount) public onlyMinter {
        _mint(to, amount);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyMinter {}
}