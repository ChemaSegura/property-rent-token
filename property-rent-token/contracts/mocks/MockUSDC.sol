// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockUSDC
 * @notice ERC-20 simplificado usado solo en tests, para simular USDC
 * sin depender de una dirección real desplegada en mainnet/testnet.
 */
contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "mUSDC") {
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }
}
