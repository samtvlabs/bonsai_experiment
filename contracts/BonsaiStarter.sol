// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.17;

import {IBonsaiRelay} from "bonsai/IBonsaiRelay.sol";
import {BonsaiCallbackReceiver} from "bonsai/BonsaiCallbackReceiver.sol";

/// @title A starter application using Bonsai through the on-chain relay.
/// @dev This contract demonstrates one pattern for offloading the computation of an expensive
//       or difficult to implement function to a RISC Zero guest running on Bonsai.
contract BonsaiStarter is BonsaiCallbackReceiver {
    struct StmAggrSig {
        StmSigRegParty[] signatures;
        bytes batchProof;
    }

    struct StmSigRegParty {
        bytes sig;
        bytes regParty;
    }

    struct VerificationData {
        bytes msg;
        bytes sig;
    }

    /// @notice Cache of the results calculated by our guest program in Bonsai.
    /// @dev Using a cache is one way to handle the callback from Bonsai. Upon callback, the
    ///      information from the journal is stored in the cache for later use by the contract.
    mapping(bytes32 => bool) public verificationCache;

    function getVerificationDataId(VerificationData memory data) public pure returns (bytes32) {
        return keccak256(abi.encode(data.msg, data.sig));
    }

    /// @notice Image ID of the only zkVM binary to accept callbacks from.
    bytes32 public immutable verificationImageId;

    /// @notice Gas limit set on the callback from Bonsai.
    /// @dev Should be set to the maximum amount of gas your callback might reasonably consume.
    uint64 private constant BONSAI_CALLBACK_GAS_LIMIT = 100000;

    /// @notice Initialize the contract, binding it to a specified Bonsai relay and RISC Zero guest image.
    constructor(IBonsaiRelay bonsaiRelay, bytes32 _verificationImageId) BonsaiCallbackReceiver(bonsaiRelay) {
        verificationImageId = _verificationImageId;
    }

    event CalculateVerificationCallback(bytes indexed msg, bytes indexed sig, bool result);

    /// @notice Returns the verification result for the given data.
    /// @dev Only precomputed results can be returned. Call verifySignatures(data) to precompute.
    function verification(VerificationData memory data) external view returns (bool) {
        bytes32 id = getVerificationDataId(data);
        bool result = verificationCache[id];
        require(result, "value not available in cache");
        return result;
    }

    // function verifySignatures(bytes memory msg, bytes memory msig) external {
    //     // Create a VerificationData struct
    //     VerificationData memory data = VerificationData({
    //         msg: msg,
    //         sig: msig,
    //     });

    //     // Get the ID of the verification data
    //     bytes32 id = getVerificationDataId(data);

    //     // Check if the result is already in the cache
    //     bool result = verificationCache[id];
    //     if (result) {
    //         // If the result is in the cache, emit an event and return
    //         emit CalculateVerificationCallback(data.msg, data.sig,  result);
    //         return;
    //     }

    //     // If the result is not in the cache, send a request to Bonsai
    //     bytes memory input = abi.encode(data);
    //     bonsaiRelay.request(verificationImageId, input, BONSAI_CALLBACK_GAS_LIMIT);
    // }

    /// @notice Sends a request to Bonsai to verify the signatures.
    /// @dev This function sends the request to Bonsai through the on-chain relay.
    ///      The request will trigger Bonsai to run the specified RISC Zero guest program with
    ///      the given input and asynchronously return the verified results via the callback below.
    function storeResult(VerificationData memory data, bool result) external onlyBonsaiCallback(verificationImageId) {
        bytes32 id = getVerificationDataId(data);
        verificationCache[id] = result;
        emit CalculateVerificationCallback(data.msg, data.sig, result);
    }

    /// @notice Sends a request to Bonsai to have have the nth Fibonacci number calculated.
    /// @dev This function sends the request to Bonsai through the on-chain relay.
    ///      The request will trigger Bonsai to run the specified RISC Zero guest program with
    ///      the given input and asynchronously return the verified results via the callback below.
    function verifySignatures(VerificationData memory data) external {
        bonsaiRelay.requestCallback(
            verificationImageId, abi.encode(data), address(this), this.storeResult.selector, BONSAI_CALLBACK_GAS_LIMIT
        );
    }
}
