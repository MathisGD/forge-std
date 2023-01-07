// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "../src/Test.sol";

contract StdGasTest is Test {
    // Base cost of `startGasMetering` and `stopGasMetering`.
    uint256 internal constant baseCost = 536;
    // Opcodes gas cost.
    uint256 internal constant PUSH = 3;
    uint256 internal constant SSTORE = 100;
    uint256 internal constant COLD_SSTORE = 2200;
    uint256 internal constant COLD_UNZEROED_SSTORE = 22100;

    function testGasMeteringEmpty() public noGasMetering {
        startGasMetering();
        uint256 gasConsumed = stopGasMetering();

        assertEq(gasConsumed, baseCost);
    }

    function testGasMeteringColdSSTORE() public noGasMetering {
        startGasMetering();
        assembly {
            sstore(0xffff, 0)
        }
        uint256 gasConsumed = stopGasMetering();

        assertEq(gasConsumed, COLD_SSTORE + PUSH + PUSH + baseCost);
    }

    function testGasMeteringWarmSSTORE() public noGasMetering {
        startGasMetering();
        assembly {
            // Store a first time in 0xffff to make the slot warm.
            sstore(0xffff, 1)
        }
        uint256 gasConsumed = stopGasMetering();

        assertEq(gasConsumed, COLD_UNZEROED_SSTORE + PUSH + PUSH + baseCost);

        startGasMetering();
        assembly {
            // Store again in 0xffff, we expect a false-warm-slot compensation.
            sstore(0xffff, 2)
        }
        gasConsumed = stopGasMetering();

        // We expect it to be as if the slot was cold (also one less push).
        assertEq(gasConsumed, COLD_SSTORE + PUSH + baseCost);
    }
}
