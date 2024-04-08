pragma solidity >=0.8.19 <=0.9.0;

import { Script, stdJson } from "forge-std/Script.sol";

abstract contract BaseScript is Script {
    using stdJson for string;

    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

    /// @dev The address of the transaction broadcaster.
    // address internal broadcaster;

    /// @dev Used to derive the broadcaster's address if $ETH_FROM is not defined.
    string internal mnemonic;

    bool internal deployCreate2;

    modifier broadcast() {
        vm.startBroadcast(deployerPrivateKey);
        _;
        vm.stopBroadcast();
    }

    modifier broadcastFrom(uint256 from) {
        vm.startBroadcast(from);
        _;
        vm.stopBroadcast();
    }
}
