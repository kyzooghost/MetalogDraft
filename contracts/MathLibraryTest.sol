// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "hardhat/console.sol";
import "@prb/math/contracts/PRBMathSD59x18.sol";

contract MathLibraryTest {
    using PRBMathSD59x18 for int256;

    function mul(int256 a, int256 b) external pure returns (int256) {
        return a.mul(b);
    }

    function div(int256 a, int256 b) external pure returns (int256) {
        return a.div(b);
    }

    function inv(int256 a) external pure returns (int256) {
        return a.inv();
    }

    function exp(int256 a) external pure returns (int256) {
        return a.exp();
    }

    function ln(int256 a) external pure returns (int256) {
        return a.ln();
    }

    function pow(int256 a, int256 b) external pure returns (int256) {
        return a.pow(b);
    }
}