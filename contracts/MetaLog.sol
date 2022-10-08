// TO-DO Test getApproximatePercentile function
// TO-DO Compare with Python implementation in https://github.com/kimsergeo/metalog/tree/master/metalog

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "hardhat/console.sol";
import "@prb/math/contracts/PRBMathSD59x18.sol";

contract MetaLog {
    // @dev We need to ensure all numbers are to 18 decimals places, to conform with 59.18 fixed point maths library.
    // @dev Ensure we don't use native * and / operators in Solidity, but library mul() and div() operations.
    using PRBMathSD59x18 for int256;

    /***************************************
    GLOBAL PUBLIC AND DATA STRUCTURES
    ***************************************/

    int256 constant internal HALF = 5e17;
    int256 constant internal ONE = 1e18;
    int256 constant internal TWO = 2e18;
    int256 constant internal THREE = 3e18;
    int256 constant internal FIVE = 5e18;


    enum MetalogBoundChoice {
        UNBOUNDED,
        BOUNDED_BELOW,
        BOUNDED_ABOVE,
        BOUNDED
    }

    struct MetalogBoundParameters {
        MetalogBoundChoice boundChoice;
        int256 lowerBound;
        int256 upperBound;
    }

    /****************************************
    EXTERNAL VIEW FUNCTIONS
    ****************************************/

    /**
     * @notice Quantile function for metalog probability distribution defined at https://en.wikipedia.org/wiki/Metalog_distribution#Definition_and_quantile_function
     * @param percentile_ Percentile that we desire to find the quantile (1e18 => 100th percentile, 5e17 => 50th percentile)
     * @param coefficients_ Coefficients for metalog quantile function, to 18 decimal places.
     * @param bound_ Metalog distribution bound choice.
     * @return quantile Quantile for provided parameters.
     */
    function getQuantile(int256 percentile_, int256[] calldata coefficients_, MetalogBoundParameters calldata bound_) external view returns (int256 quantile) {
        return _getQuantile(percentile_, coefficients_, bound_);
    }

    /**
     * @notice Internal helper function to obtain individual terms for the derivative of the metalog quantile function.
     * @dev Using Newton-Raphson method.
     * @param quantile_ Quantile to find cumulative probability for.
     * @param coefficients_ Coefficients for metalog quantile function.
     * @param bound_ Metalog distribution bound choice.
     * @return approximatePercentile Approximate cumulative probability for quantile.
     */
    function getApproximatePercentile(
        int256 quantile_, 
        int256[] calldata coefficients_, 
        MetalogBoundParameters calldata bound_ 
    ) external view returns (int256 approximatePercentile) {
        return _getApproximatePercentile(quantile_, coefficients_, bound_);
    }

    /****************************************
    INTERNAL HELPER FUNCTIONS
    ****************************************/

    /**
     * @notice Internal helper function to query whether given number is even, using bitwise operations.
     * @dev If the least significant bit is 0, then must be even number.
     * @dev Quick test in Remix shows that this implementation costs 27 gas, vs `return (x % 2 == 0)` which costs 202 gas.
     * @param x Number we are querying for.
     * @param isEven True is even, false if odd.
     */
    function _isEven(int256 x) internal pure returns (bool isEven) {
        return (x & 1 == 0);
    }

    /**
     * @notice Internal helper function to query whether given number is odd, using bitwise operations.
     * @dev If the least significant bit is 1, then must be even number.
     * @param x Number we are querying for.
     * @param isOdd True is odd, false if even.
     */
    function _isOdd(int256 x) internal pure returns (bool isOdd) {
        return (x & 1 == 1);
    }

    /******************************************
    INTERNAL METALOG QUANTILE HELPER FUNCTIONS
    ******************************************/

    /**
     * @notice Internal helper function to obtain individual terms for metalog quantile function.
     * @param percentile_ Percentile that we desire to find the quantile (1e18 => 100th percentile, 5e17 => 50th percentile)
     * @param term_ Which term we want to find, i.e. `term_ == 1` means we want to find the first term.
     */
    function _getQuantileFunctionTerm(int256 percentile_, int256 term_) internal view returns (int256 term) {
        if (term_ == 1) {
            return ONE;
        } else if (term_ == 2) {
            // Beware Solidity rounding down, use logarithm quotient rule.
            return percentile_.ln() - (ONE - percentile_).ln();
        } else if (term_ == 3) {
            return (percentile_ - HALF)
            .mul((percentile_.ln() - (ONE - percentile_).ln()));
        } else if (term_ == 4) {
            return percentile_ - HALF;
        } else if (_isOdd(term_)) {
            int256 exponent = (term_.fromInt() - ONE).div(TWO);
            int256 sign = percentile_ > HALF || _isEven(exponent.toInt()) ? ONE : -ONE;
            return (percentile_ - HALF).abs().pow(exponent).mul(sign);
        } else if (_isEven(term_)) {
            int256 exponent = term_.fromInt().div(TWO) - ONE;
            int256 sign = percentile_ > HALF || _isEven(exponent.toInt()) ? ONE : -ONE;
            return (percentile_ - HALF).abs().pow(exponent)
            .mul((percentile_.ln() - (ONE - percentile_).ln()))
            .mul(sign);
        }
    }

    /**
     * @notice Quantile function for metalog probability distribution defined at https://en.wikipedia.org/wiki/Metalog_distribution#Definition_and_quantile_function
     * @param percentile_ Percentile that we desire to find the quantile (1e18 => 100th percentile, 5e17 => 50th percentile)
     * @param coefficients_ Coefficients for metalog quantile function, to 18 decimal places.
     * @param bound_ Metalog distribution bound choice.
     * @return quantile Quantile for provided parameters.
     */
    function _getQuantile(int256 percentile_, int256[] calldata coefficients_, MetalogBoundParameters calldata bound_) internal view returns (int256 quantile) {
        require(percentile_ > 0, 'percentile_ <= 0%');
        require(percentile_ < 1e18, 'percentile_ >= 100%');
        int256 unboundedQuantile = 0;

        for (uint256 i = 0; i < coefficients_.length; i++) {
            unboundedQuantile += coefficients_[i].mul(_getQuantileFunctionTerm(percentile_, int256(i) + 1));
        }

        // Use transformations defined in https://en.wikipedia.org/wiki/Metalog_distribution#Unbounded,_semi-bounded,_and_bounded_metalog_distributions.

        if (bound_.boundChoice == MetalogBoundChoice.UNBOUNDED) {
            return unboundedQuantile;
        } else if (bound_.boundChoice == MetalogBoundChoice.BOUNDED_BELOW) {
            return (bound_.lowerBound + unboundedQuantile.exp());
        } else if (bound_.boundChoice == MetalogBoundChoice.BOUNDED_ABOVE) {
            return (bound_.upperBound - unboundedQuantile.exp().inv());
        } else if (bound_.boundChoice == MetalogBoundChoice.BOUNDED) {
            int256 numerator = bound_.lowerBound + bound_.upperBound.mul(unboundedQuantile.exp());
            int256 denominator = ONE + unboundedQuantile.exp();
            return unboundedQuantile.mul(numerator.div(denominator));
        }
    }

    /**************************************************
    INTERNAL INVERSE METALOG QUANTILE HELPER FUNCTIONS
    **************************************************/

    // FIX-ME: Is there an efficient way to get the starting point other than a blind guess? Like there is with Babylonian method for square roots.
    // FIX-ME: Do quantile functions have an inflection point?
    /**
     * @notice Internal helper function to obtain individual terms for the derivative of the metalog quantile function.
     * @dev Using Newton-Raphson method. Appropriate because the quantile function is a monotonically increasing function for a continuous probability distribution
     * @param quantile_ Quantile to find cumulative probability for.
     * @param coefficients_ Coefficients for metalog quantile function.
     * @param bound_ Metalog distribution bound choice.
     * @return approximatePercentile Approximate cumulative probability for quantile.
     */
    function _getApproximatePercentile(
        int256 quantile_, 
        int256[] calldata coefficients_, 
        MetalogBoundParameters calldata bound_
    ) internal view returns (int256 approximatePercentile) {
        uint256 gas = gasleft();
        // Stop while-loop when gaining less than 0.01% accuracy with each iteration.
        int256 accepted_error = 1e14;
        int256 current_error = 1e18;
        int256 loop_count = 0;

        // Start at 50% percentile
        approximatePercentile = 5e17; 

        while (current_error > accepted_error && loop_count < 100) {
            int256 getQuantileResult = _getQuantile(approximatePercentile, coefficients_, bound_);

            int newApproximatePercentile = approximatePercentile 
            - (getQuantileResult - quantile_)
            .div(_getQuantileDerivative(approximatePercentile, coefficients_, bound_, getQuantileResult))
            .div(FIVE);

            current_error = (newApproximatePercentile - approximatePercentile).abs();
            approximatePercentile = newApproximatePercentile;
            console.log("newApproximatePercentile");
            console.logInt(approximatePercentile);
            loop_count += 1;
            console.log("loop_count");
            console.logInt(loop_count);
        }

        if (loop_count >= 100) {
            revert('Unable to find approximate percentile');
        }

        console.log("gas used: %d", gas - gasleft());
    }

    /**
     * @notice Derivative of quantile function (or quantile density function, or inverse of probability density function) for metalog probability distribution defined at https://en.wikipedia.org/wiki/Metalog_distribution#Definition_and_quantile_function
     * @param percentile_ Percentile that we desire to find the quantile derivative (1e18 => 100th percentile, 5e17 => 50th percentile)
     * @param coefficients_ Coefficients for metalog quantile function.
     * @param bound_ Metalog distribution bound choice.
     * @param quantileResult_ Result of evaluation metalog quantile function for same percentile_ value, provided as parameter to avoid repeating duplicate computation in Newton-Raphson approximation method.
     * @return unboundedQuantileDerivative Quantile derivate for provided parameters.
     */
    function _getQuantileDerivative(
        int256 percentile_, 
        int256[] calldata coefficients_, 
        MetalogBoundParameters calldata bound_,
        int256 quantileResult_
    ) internal view returns (int256 unboundedQuantileDerivative) {
        require(percentile_ <= 1e18, "percentile_ > 100%");
        unboundedQuantileDerivative = 0;

        for (uint256 i = 0; i < coefficients_.length; i++) {
            // console.log("Term %d", i + 1);
            // console.logInt(_getQuantileDerivativeFunctionTerm(percentile_, int256(i) + 1));
            unboundedQuantileDerivative += coefficients_[i].mul(_getQuantileDerivativeFunctionTerm(percentile_, int256(i) + 1));
        }

        // Use transformations defined in https://en.wikipedia.org/wiki/Metalog_distribution#Unbounded,_semi-bounded,_and_bounded_metalog_distributions.

        if (bound_.boundChoice == MetalogBoundChoice.UNBOUNDED) {
            return unboundedQuantileDerivative;
        } else if (bound_.boundChoice == MetalogBoundChoice.BOUNDED_BELOW) {
            return unboundedQuantileDerivative.mul(quantileResult_.exp());
        } else if (bound_.boundChoice == MetalogBoundChoice.BOUNDED_ABOVE) {
            return unboundedQuantileDerivative.div(quantileResult_.exp());
        } else if (bound_.boundChoice == MetalogBoundChoice.BOUNDED) {
            int256 numerator = (bound_.upperBound - bound_.lowerBound).mul(quantileResult_.exp());
            int256 denominator = (ONE + quantileResult_.exp()).pow(TWO);
            return unboundedQuantileDerivative.mul(numerator).div(denominator);
        }
    }

    /**
     * @notice Internal helper function to obtain individual terms for the derivative of the metalog quantile function.
     * @dev Using https://www.derivative-calculator.net/
     * @dev Compare to https://github.com/kimsergeo/metalog/blob/851a75d7afd66a584c68543e7031a588cf50ea84/metalog/support_func.py#L53-L101.
     * @param percentile_ Percentile that we desire to find the quantile (1e18 => 100th percentile, 5e17 => 50th percentile)
     * @param term_ Which term we want to find, i.e. `term_ == 1` means we want to find the first term.
     */
    function _getQuantileDerivativeFunctionTerm(int256 percentile_, int256 term_) internal view returns (int256 term) {
        if (term_ == 1) {
            return 0;
        } else if (term_ == 2) {
            // Beware Solidity rounding down, use logarithm quotient rule.
            return (percentile_.mul((ONE - percentile_))).inv();
        } else if (term_ == 3) {
            return percentile_.ln() 
            - (ONE - percentile_).ln() 
            + (percentile_ - HALF).div(percentile_.mul((ONE - percentile_)));
        } else if (term_ == 4) {
            return ONE;
        } else if (_isOdd(term_)) {
            int256 exponent = (term_.fromInt() - THREE).div(TWO);
            int256 sign = percentile_ > HALF || _isEven(exponent.toInt()) ? ONE : -ONE;

            return ((term_.fromInt() - ONE).div(TWO))
            .mul((percentile_ - HALF).abs().pow(exponent))
            .mul(sign);
        } else if (_isEven(term_)) {
            int256 exponent1 = term_.fromInt().div(TWO) - TWO;
            int256 exponent2 = term_.fromInt().div(TWO) - ONE;

            // Unable to define `sign1` and `sign2` due to stack-too-deep issue.
            // int256 sign1 = percentile_ > HALF || _isEven(exponent1.toInt()) ? ONE : -ONE;
            // int256 sign2 = percentile_ > HALF || _isEven(exponent2.toInt()) ? ONE : -ONE;

            return (term_.fromInt().div(TWO) - ONE)
                .mul((percentile_ - HALF).abs().pow(exponent1))
                .mul((percentile_.ln() - (ONE - percentile_).ln()))
                // mul.sign(1)
                .mul(percentile_ > HALF || _isEven(exponent1.toInt()) ? ONE : -ONE)
                + (
                    (percentile_ - HALF).abs().pow(exponent2)
                    .div(percentile_.mul(ONE - percentile_))
                    // mul.sign(2)
                    .mul(percentile_ > HALF || _isEven(exponent2.toInt()) ? ONE : -ONE)
                );
        }
    }
}
