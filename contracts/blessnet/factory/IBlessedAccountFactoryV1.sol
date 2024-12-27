// SPDX-License-Identifier: MIT
/**
 * @title IBlessedAccountFactoryV1.sol. Blessnet abstracted account factory, version 1, interface.
 *
 * @author abraxas https://abraxaslabs.io
 *         for
 *         blessnet https://bless.net
 *
 *         version 0.1.0
 */

pragma solidity 0.8.23;

import {BlessedAccountV1, IBlessnetBeacon, IEntryPoint} from "./BlessedAccountV1.sol";

/**
 * Factory contract for BlessedAccount
 */
interface IBlessedAccountFactoryV1 {
  function accountImplementation() external view returns (BlessedAccountV1);

  function entryPoint() external view returns (IEntryPoint);

  function beacon() external view returns (IBlessnetBeacon);

  /**
   * create an account, and return its address.
   * returns the address even if the account is already deployed.
   * Note that during UserOperation execution, this method is called only if the account is not deployed.
   * This method returns an existing account address so that entryPoint.getSenderAddress() would work even after account creation
   *
   * @param platform_ The platform we are creating an account for.
   * @param userIdHash_ The userIdHash on the platform we are creating an account for.
   * @return account_ The address of the account.
   */
  function createAccount(
    string calldata platform_,
    bytes32 userIdHash_
  ) external payable returns (BlessedAccountV1 account_);

  /**
   * calculate the counterfactual address of this account as it would be returned by createAccount()
   *
   * @param platform_ The platform we are creating an account for.
   * @param userIdHash_ The userIdHash on the platform we are creating an account for.
   * @return account_ The address of the account.
   * @return salt_ The salt used to derive the account address.
   */
  function getAddress(
    string calldata platform_,
    bytes32 userIdHash_
  ) external view returns (address account_, bytes32 salt_);
}
