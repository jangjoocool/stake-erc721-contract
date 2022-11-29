// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract RoleControlUpgradeable is AccessControlUpgradeable {
    // Roles
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Role: sender is not admin");
        _;
    }

    modifier onlyMinter() {
        require(hasRole(MINTER_ROLE, _msgSender()), "Role: sender is not allowed mint");
        _;
    }

    function __RoleControl_init() internal onlyInitializing {
        __RoleControl_init_unchained();
    }

    function __RoleControl_init_unchained() internal onlyInitializing {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setRoleAdmin(MINTER_ROLE, DEFAULT_ADMIN_ROLE);
    }

    function addAdmin(address account) external virtual onlyAdmin {
        grantRole(DEFAULT_ADMIN_ROLE, account);
    }

    function addMinter(address account) external virtual onlyAdmin {
        grantRole(MINTER_ROLE, account);
    }

}