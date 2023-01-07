// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

import {VmSafe} from "./Vm.sol";
import {console} from "./console.sol";

abstract contract StdGas {
    VmSafe private constant vm = VmSafe(address(uint160(uint256(keccak256("hevm cheat code")))));

    // Stores the storage slots that have been accessed before the last recording.
    mapping(address => mapping(bytes32 => bool)) private accessed;

    // Gas left when the metering started.
    uint256 gasLeftAtStart;

    function startGasMetering() internal {
        // Store gas left before recording.
        gasLeftAtStart = gasleft();
        // Clear accesses list.
        vm.record();
        // Start gas metering.
        vm.resumeGasMetering();
    }

    /// @notice Returns the gas consumed during the recording, if what it 
    /// happened as a transaction on its own.
    /// @dev 2100 is added to the total gas cost for all SLOAD and SSTORE if the 
    /// slot has been accessed before in this test (in `accessed`) and not 
    /// already accessed during this recording.
    function stopGasMetering() internal returns (uint256) {
        vm.pauseGasMetering();

        uint256 gasLeft = gasleft();

        // Retrieve slots accessed during the last recording.
        bytes32[] memory slots = _accessedDuringRecording();

        // Compute total gas spent.
        uint256 gasConsumed = gasLeftAtStart - gasLeft;

        for (uint256 i; i < slots.length; i++) {
            // If the slot was warm, but shouldn't have been.
            if (accessed[address(this)][slots[i]]) {
                // Compensate for false warm slot.
                gasConsumed += 2100;
            }
            // Store accessed slot, such that next time it is accessed, the
            // compensation can be added.
            accessed[address(this)][slots[i]] = true;
        }

        return gasConsumed;
    }

    // Helpers for `_accessedDuringRecording`.
    mapping(bytes32 => bool) private accessedTemp;
    bytes32[] private slotsTemp;

    /// @notice Returns all slots accessed during the last recording.
    /// @dev Concatenates all accesses and removes duplicates (which are not
    // needed because we don't need to compensate for their warm access).
    function _accessedDuringRecording() private returns (bytes32[] memory) {
        // Retrive all accesses (read an write).
        (bytes32[] memory reads, bytes32[] memory writes) = vm.accesses(address(this));

        // Concatenate `reads` and `writes` and remove duplicates.
        for (uint256 i; i < reads.length; i++) {
            if (!accessedTemp[reads[i]]) {
                accessedTemp[reads[i]] = true;
                slotsTemp.push(reads[i]);
            }
        }
        for (uint256 i; i < writes.length; i++) {
            if (!accessedTemp[writes[i]]) {
                accessedTemp[writes[i]] = true;
                slotsTemp.push(writes[i]);
            }
        }

        bytes32[] memory slots = slotsTemp;

        // Clear temporary mapping.
        for (uint256 i; i < slotsTemp.length; i++) {
            accessedTemp[slotsTemp[i]] = false;
        }
        // Clear temporary array.
        slotsTemp = new bytes32[](0);

        return slots;
    }
}
