// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract JigsawPoints is ERC20, ERC20Burnable, AccessControlDefaultAdminRules, ERC20Permit {
    // --- Errors ---
    /**
     * @dev The operation failed because renouncing default admin role is prohibited.
     */
    error RenouncingDefaultAdminRoleProhibited();

    /**
     * @dev The operation failed because amount is zero;
     */
    error InvalidAmount();

    /**
     * Declaration of the Burner role - privileged actor, allowed to perform burnFrom operation.
     */
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    // -- Constructor --

    constructor(
        address _initialAdmin,
        uint256 _premintAmount
    )
        ERC20("Jigsaw Points", "jPoints")
        ERC20Permit("Jigsaw Points")
        AccessControlDefaultAdminRules(2 days, _initialAdmin)
    {
        _mint(_initialAdmin, _premintAmount * 10 ** decimals());
    }

    // --- Administration ---

    function mint(address to, uint256 amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _mint(to, amount);
    }

    /// @notice burns token from an address
    /// @param _user the user to burn it from
    /// @param _amount the amount of tokens to be burnt
    function burnFrom(address _user, uint256 _amount) public override onlyRole(BURNER_ROLE) validAmount(_amount) {
        _burn(_user, _amount);
    }

    /**
     * @dev Prevents the renouncement of the default admin role by overriding beginDefaultAdminTransfer
     */
    function beginDefaultAdminTransfer(address newAdmin)
        public
        override(AccessControlDefaultAdminRules)
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (newAdmin == address(0)) revert RenouncingDefaultAdminRoleProhibited();
        _beginDefaultAdminTransfer(newAdmin);
    }

    // -- Modifiers --

    modifier validAmount(uint256 _val) {
        if (_val == 0) revert InvalidAmount();
        _;
    }
}
