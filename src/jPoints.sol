// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// @note add interface

/// @title Jigsaw stablecoin
/// @author Hovooo (@hovooo)
contract jPoints is ERC20, Ownable2Step {
    /// @notice token's symbol
    string private constant SYMBOL = "jPoints";
    /// @notice token's name
    string private constant NAME = "Jigsaw Points";
    /// @notice token's decimals
    uint8 private constant DECIMALS = 18;

    /// @notice mint limit
    uint256 public mintLimit;

    /// @notice creates the jUsd contract
    constructor(address _initialOwner, uint256 _limit) ERC20(NAME, SYMBOL) Ownable(_initialOwner) {
        mintLimit = _limit * (10 ** DECIMALS);
    }

    // -- Owner specific methods --

    /// @notice sets the maximum mintable amount
    /// @param _limit the new mint limit
    function updateMintLimit(uint256 _limit) external onlyOwner validAmount(_limit) {
        // emit MintLimitUpdated(mintLimit, _limit);
        mintLimit = _limit;
    }

    // -- Write type methods --

    /// @notice mint tokens
    /// @dev no need to check if '_to' is a valid address if the '_mint' method is used
    /// @param _to address of the user receiving minted tokens
    /// @param _amount the amount to be minted
    function mint(address _to, uint256 _amount) external onlyOwner validAmount(_amount) {
        require(totalSupply() + _amount <= mintLimit, "2007");
        _mint(_to, _amount);
    }

    /// @notice burns token from sender
    /// @param _amount the amount of tokens to be burnt
    function burn(uint256 _amount) external validAmount(_amount) {
        _burn(msg.sender, _amount);
    }

    /// @notice burns token from an address
    /// @param _user the user to burn it from
    /// @param _amount the amount of tokens to be burnt
    function burnFrom(address _user, uint256 _amount) external validAmount(_amount) onlyOwner {
        _burn(_user, _amount);
    }

    // -- Modifiers --
    modifier validAmount(uint256 _val) {
        require(_val > 0, "2001");
        _;
    }
}
