// SPDX-License-Identifier: MIT
/**
 * @title IBlessedAccountV1.sol. Blessnet abstracted account, version 1, interface.
 *
 * @author abraxas https://abraxaslabs.io
 *         for
 *         blessnet https://bless.net
 *
 *         version 0.1.0
 */

pragma solidity 0.8.23;

import {IBlessnetBeacon} from "../beacon/IBlessnetBeacon.sol";
import {IEntryPoint} from "../../core/BaseAccount.sol";

/**
 * Minimal account.
 *  has execute, eth handling methods
 *  has a single signer (relay) that can send requests through the entryPoint.
 */
interface IBlessedAccountV1 {
  /**
   * @param platform_ the platform for this blessed account.
   * @param userIdHash_ the userIdHash for this blessed account.
   */
  function initialize(string calldata platform_, bytes32 userIdHash_) external;

  function entryPoint() external view returns (IEntryPoint);

  function beacon() external view returns (IBlessnetBeacon);

  function platform() external view returns (string memory);

  function userIdHash() external view returns (bytes32);

  /**
   * execute a transaction
   * @param dest destination address to call
   * @param value the value to pass in this call
   * @param func the calldata to pass in this call
   */
  function execute(address dest, uint256 value, bytes calldata func) external;

  /**
   * execute a sequence of transactions
   * @dev to reduce gas consumption for trivial case (no value), use a zero-length array to mean zero value
   * @param dest an array of destination addresses
   * @param value an array of values to pass to each call. can be zero-length for no-value calls
   * @param func an array of calldata to pass to each call
   */
  function executeBatch(
    address[] calldata dest,
    uint256[] calldata value,
    bytes[] calldata func
  ) external;

  /**
   * check current account deposit in the entryPoint
   */
  function getDeposit() external view returns (uint256);

  /**
   * deposit more funds for this account in the entryPoint
   */
  function addDeposit() external payable;

  /**
   * withdraw value from the account's deposit
   * @param withdrawAddress target to send to
   * @param amount to withdraw
   */
  function withdrawDepositTo(
    address payable withdrawAddress,
    uint256 amount
  ) external;
}
