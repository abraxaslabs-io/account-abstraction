// SPDX-License-Identifier: MIT

/**
 * @title IBlessnetBeacon.sol. Interface for the Blessnet config beacon.
 *
 * @author abraxas https://abraxaslabs.io
 *         for
 *         blessnet https://bless.net
 *
 *         version 0.1.0
 */

pragma solidity ^0.8.23;

import {IBlessnetStructs} from "../configuration/IBlessnetStructs.sol";

interface IBlessnetBeacon is IBlessnetStructs {
  struct BlessnetBeaconStorage {
    address relayerAddress;
    address previousRelayerAddress;
    uint32 updateTimestamp;
    uint32 bufferInSeconds;
    uint256 integerNativeInBless;
    uint256 integerBlessInNative;
    uint256 nativeDecimals;
  }

  event RelayerUpdated(address oldRelayer, address newRelayer, uint32 buffer);
  event ExchangeRatesUpdated(
    uint256 integerNativeInBless_,
    uint256 integerBlessInNative
  );

  /**
   * @dev getVersion: Retrieve the current version
   */
  function getVersion() external pure returns (string memory);

  /**
   * @dev blessDecimals: Number of decimals in the bless token
   */
  function decimals() external view returns (uint8);

  /**
   * @dev convertNativeToBless: Convert a native token amount to an amount in
   * $bless token. This receives amounts in wei, NOT whole token, and returns
   * amounts of $bless in wei (i.e. to 18dp).
   */
  function convertNativeToBless(
    uint256 native_
  ) external view returns (uint256);

  /**
   * @dev convertBlessToNative: Convert a $bless token amount to an amount in
   * native token.
   */
  function convertBlessToNative(uint256 bless_) external view returns (uint256);

  /**
   * @dev getCurrentRelayer: Retrieve the current relayer
   */
  function getCurrentRelayer() external view returns (address currentRelayer_);

  /**
   * @dev getPreviousRelayer: Retrieve the previous relayer, if within the buffer
   */
  function getPreviousRelayer()
    external
    view
    returns (address previousRelayer_);

  /**
   * @dev getMessageIsValidBySignature: Return if the message is valid or not by checking an
   * accompanying signed message is from the trusted relay
   */
  function getMessageIsValidBySignature(
    bytes32 hash_,
    bytes memory sig_,
    StorageRecord calldata blessing_
  ) external view returns (bool);

  /**
   * @dev getMessageIsValidBySender: Return if the message is valid or not by checking the
   * msg.sender is the trusted relay.
   */
  function getMessageIsValidBySender(
    address sender_
  ) external view returns (bool);

  /**
   * @dev updateRelayer: Update the relayer address
   *
   * @param relayerAddress_ The new relayer address
   * @param bufferInSeconds_ The buffer in seconds for how long the
   * previous address should be a valid relayer. This allows the update of the
   * beacons within a suitable update window to migrate to the new relayer signer.
   * This can be set to zero seconds i.e. the previous relayer is immediately invalid.
   */
  function updateRelayer(
    address relayerAddress_,
    uint32 bufferInSeconds_
  ) external;

  /**
   * @dev updateExchangeRates: Update held exchange values
   *
   */
  function updateExchangeRates(
    uint256 integerNativeInBless_,
    uint256 integerBlessInNative_
  ) external;
}
