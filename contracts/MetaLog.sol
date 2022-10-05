// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import "@prb/math/contracts/PRBMathUD60x18.sol";

contract MetaLog {
    using PRBMathUD60x18 for uint256;

    uint256 constant internal HALF = 5e17;
    uint256 constant internal ONE = 1e18;

    enum MetalogBoundChoice {
        UNBOUNDED,
        BOUNDED_BELOW,
        BOUNDED_ABOVE,
        BOUNDED
    }

    struct MetalogBoundParameters {
        MetalogBoundChoice boundChoice;
        uint256 lowerBound;
        uint256 upperBound;
    }

    constructor() {}

    /**
     * @notice Internal helper function to query whether given number is even, using bitwise operations.
     * @dev If the least significant bit is 0, then must be even number.
     * @param x Number we are querying for.
     * @param isEven True is even, false if odd.
     */
    function _isEven(uint256 x) internal pure returns (bool isEven) {
        return (x & 1 == 0);
    }

    /**
     * @notice Internal helper function to query whether given number is odd, using bitwise operations.
     * @dev If the least significant bit is 1, then must be even number.
     * @param x Number we are querying for.
     * @param isOdd True is odd, false if even.
     */
    function _isOdd(uint256 x) internal pure returns (bool isOdd) {
        return (x & 1 == 1);
    }

    /**
     * @notice Internal helper function to obtain individual terms for metalog quantile polynomial function.
     * @param percentile_ Percentile that we desire to find the quantile (1e18 => 100th percentile, 5e17 => 50th percentile)
     * @param term_ Which term we want to find, i.e. `term_ == 1` means we want to find the first term.
     */
    function _getQuantilePolynomialTerm(uint256 percentile_, uint256 term_) internal pure returns (uint256 term) {
        if (term_ == 1) {
            return ONE;
        } else if (term_ == 2) {
            // Beware Solidity rounding down, use logarithm quotient rule.
            return percentile_.ln() - (ONE - percentile_).ln();
        } else if (term_ == 3) {
            return (percentile_ - HALF) * (percentile_.ln() - (ONE - percentile_).ln());
        } else if (term_ == 4) {
            return percentile_ - HALF;
        } else if (_isOdd(term_)) {
            return (percentile_ - HALF).pow((percentile_ - ONE) / 2);
        } else if (_isEven(term_)) {
            return (percentile_ - HALF).pow((percentile_ / 2) - ONE) * (percentile_.ln() - (ONE - percentile_).ln());
        }
    }

    /**
     * @notice Quantile function for metalog probability distribution defined at https://en.wikipedia.org/wiki/Metalog_distribution#Definition_and_quantile_function
     * @param percentile_ Percentile that we desire to find the quantile (1e18 => 100th percentile, 5e17 => 50th percentile)
     * @param coefficients_ Coefficients for metalog quantile function.
     * @param bound_ Metalog distribution bound choice.
     * @return quantile Quantile for provided parameters.
     */
    function getQuantile(uint256 percentile_, uint256[] calldata coefficients_, MetalogBoundParameters calldata bound_) external pure returns (uint256 quantile) {
        require(percentile_ <= 1e18, "percentile_ > 100%");
        uint256 unboundedQuantile = 0;

        for (uint256 i = 0; i < coefficients_.length; i++) {
            unboundedQuantile += coefficients_[i] * _getQuantilePolynomialTerm(percentile_, i + 1) / ONE;
        }

        // Use transformations defined in https://en.wikipedia.org/wiki/Metalog_distribution#Unbounded,_semi-bounded,_and_bounded_metalog_distributions.

        if (bound_.boundChoice == MetalogBoundChoice.UNBOUNDED) {
            return unboundedQuantile;
        } else if (bound_.boundChoice == MetalogBoundChoice.BOUNDED_BELOW) {
            return (bound_.lowerBound + unboundedQuantile.exp());
        } else if (bound_.boundChoice == MetalogBoundChoice.BOUNDED_ABOVE) {
            return (bound_.upperBound - unboundedQuantile.exp().inv());
        } else if (bound_.boundChoice == MetalogBoundChoice.BOUNDED) {
            uint256 numerator = bound_.lowerBound + bound_.upperBound * unboundedQuantile.exp();
            uint256 denominator = ONE + unboundedQuantile;
            return numerator / denominator;
        }
    }
}
