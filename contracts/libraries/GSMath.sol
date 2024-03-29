// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

/// @title Math Library
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Library for performing various math operations
library GSMath {
    function max(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x > y ? x : y;
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x < y ? x : y;
    }

    /// @dev Returns the square root of `a`.
    /// @param a number to square root
    /// @return z square root of a
    function sqrt(uint256 a) internal pure returns (uint256 z) {
        if (a == 0) return 0;

        assembly {
            z := 181 // Should be 1, but this saves a multiplication later.

            let r := shl(7, lt(0xffffffffffffffffffffffffffffffffff, a))
            r := or(shl(6, lt(0xffffffffffffffffff, shr(r, a))), r)
            r := or(shl(5, lt(0xffffffffff, shr(r, a))), r)
            r := or(shl(4, lt(0xffffff, shr(r, a))), r)
            z := shl(shr(1, r), z)

            // Doesn't overflow since y < 2**136 after above.
            z := shr(18, mul(z, add(shr(r, a), 65536))) // A mul() saved from z = 181.

            // Given worst case multiplicative error of 2.84 above, 7 iterations should be enough.
            z := shr(1, add(div(a, z), z))
            z := shr(1, add(div(a, z), z))
            z := shr(1, add(div(a, z), z))
            z := shr(1, add(div(a, z), z))
            z := shr(1, add(div(a, z), z))
            z := shr(1, add(div(a, z), z))
            z := shr(1, add(div(a, z), z))

            // If x+1 is a perfect square, the Babylonian method cycles between floor(sqrt(x)) and ceil(sqrt(x)).
            // We always return floor. Source https://en.wikipedia.org/wiki/Integer_square_root#Using_only_integer_division
            z := sub(z, lt(div(a, z), z))
        }
    }
}
