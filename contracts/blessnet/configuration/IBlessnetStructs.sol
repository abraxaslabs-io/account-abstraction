// SPDX-License-Identifier: MIT
/**
 * @title IBlessnetStructs.sol. Interface for core blessnet structures
 *
 * @author abraxas https://abraxaslabs.io
 *         for
 *         blessnet https://bless.net
 *
 */

pragma solidity ^0.8.23;

interface IBlessnetStructs {
  struct GatewayPayload {
    address caller;
    address target;
    bytes arguments;
  }

  struct Parameters {
    bytes methodArguments; // Method arguments to include on call. These will need to be decoded.
    bytes auxParameters; // Aux parameters to send with the call, for example CRON parameters.
  }

  struct StorageRecord {
    // Slot #1
    uint256 targetChain; // The native chain ID, *NOT* the wormhole chain ID.
    // Slot #2
    address targetContract; // The contract we will call on the target chain.
    uint96 maxGasGwei; // The maximum gas cost in gwei to pay for execution on target.
    // Slot #3
    address targetAccount; // The account that will be the "caller" on the target contract.
    uint96 tokenForGas; // The quantity of token provided for gas cost.
    // Slot #4
    address makerAccount; // The address that submitted this storage record.
    uint8 transportMethod; // The transport method to relay this call.
    // Slot #5
    uint256 targetNative; // The native token to deliver in the call on the target.
    // Slot #6 +
    Parameters parameters;
  }

  struct DeliveryRecord {
    uint256 targetChain; // The native chain ID, *NOT* the wormhole chain ID.
    address targetContract; // The contract we will call on the target chain.
    address targetAccount; // The account that will be the "caller" on the target contract.
    uint8 transportMethod; // The transport method to relay this call.
    uint256 targetNative; // The native token to deliver in the call on the target.
    bytes methodArguments; // Method arguments to include on call. These will need to be decoded.
  }

  struct AttestationRecord {
    uint96 attestationTypeId;
    address attestedBy;
    address[] attestedFor;
    uint96 attestedAt;
    string attestationText;
    bytes attestationBytes;
    bytes32 attestationTarget;
  }

  struct AttestationType {
    string attestationTypeText;
    string attestationURI;
    bytes attestationTypeBytes;
  }
}
