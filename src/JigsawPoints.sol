// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract JigsawPoints is ERC20, ERC20Burnable, Ownable, ERC20Permit {
    error InvalidAmount();

    constructor(
        address _initialOwner,
        uint256 _premintAmount
    )
        ERC20("Jigsaw Points", "jPoints")
        Ownable(_initialOwner)
        ERC20Permit("Jigsaw Points")
    {
        _mint(msg.sender, _premintAmount * 10 ** decimals());
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    /// @notice burns token from an address
    /// @param _user the user to burn it from
    /// @param _amount the amount of tokens to be burnt
    function burnFrom(address _user, uint256 _amount) public override validAmount(_amount) onlyOwner {
        _burn(_user, _amount);
    }

    // -- Modifiers --
    modifier validAmount(uint256 _val) {
        if (_val == 0) revert InvalidAmount();
        _;
    }
}
