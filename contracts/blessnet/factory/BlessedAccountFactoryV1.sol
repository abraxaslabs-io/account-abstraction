// SPDX-License-Identifier: MIT
/**
 * @title BlessedAccountFactoryV1.sol. Blessnet abstracted account factory, version 1.
 *
 * @author abraxas https://abraxaslabs.io
 *         for
 *         blessnet https://bless.net
 *
 *         version 0.1.0
 */

pragma solidity 0.8.23;

import {IBlessedAccountFactoryV1, BlessedAccountV1, IBlessnetBeacon, IEntryPoint} from "./IBlessedAccountFactoryV1.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * Factory contract for BlessedAccount
 * A UserOperations "initCode" holds the address of the factory, and a method call (to createAccount, in this sample factory).
 * The factory's createAccount returns the target account address even if it is already installed.
 * This way, the entryPoint.getSenderAddress() can be called either before or after the account is created.
 */
contract BlessedAccountFactoryV1 is IBlessedAccountFactoryV1 {
  uint256 public constant VERSION = 1;

  BlessedAccountV1 private immutable _accountImplementation;
  IBlessnetBeacon private immutable _beacon;
  IEntryPoint private immutable _entryPoint;

  constructor(IEntryPoint entryPoint_, IBlessnetBeacon beacon_) {
    _accountImplementation = new BlessedAccountV1(entryPoint_, beacon_);
    _entryPoint = entryPoint_;
    _beacon = beacon_;
  }

  function accountImplementation() public view returns (BlessedAccountV1) {
    return _accountImplementation;
  }

  function entryPoint() public view returns (IEntryPoint) {
    return _entryPoint;
  }

  function beacon() public view returns (IBlessnetBeacon) {
    return _beacon;
  }

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
  ) public payable returns (BlessedAccountV1 account_) {
    // The salt is a hash of the concatenated hashes of the platform and user id, so that each
    // unique platform/userId pair creates a single account address, and so we don't get
    // multiple platform/userId pairs that would create the same salt (e.g. twitter omnus would
    // produce the same hash as twitt eromnus if we just hashed the concatenated strings).
    (address addr, bytes32 salt) = getAddress(platform_, userIdHash_);
    uint256 codeSize = addr.code.length;
    if (codeSize > 0) {
      account_ = BlessedAccountV1(payable(addr));
    } else {
      account_ = BlessedAccountV1(
        payable(
          new ERC1967Proxy{salt: bytes32(salt)}(
            address(_accountImplementation),
            abi.encodeCall(
              BlessedAccountV1.initialize,
              (platform_, userIdHash_)
            )
          )
        )
      );
    }
    // If we have received any value with this call it is a deposit for the account:
    if (msg.value != 0) {
      entryPoint().depositTo{value: msg.value}(address(account_));
    }
    // Return the account, either the newly created one or the existing address:
    return (account_);
  }

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
  ) public view returns (address account_, bytes32 salt_) {
    bytes32 salt = keccak256(
      abi.encodePacked(keccak256(abi.encodePacked(platform_)), userIdHash_)
    );
    return (
      Create2.computeAddress(
        salt,
        keccak256(
          abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(
              address(_accountImplementation),
              abi.encodeCall(
                BlessedAccountV1.initialize,
                (platform_, userIdHash_)
              )
            )
          )
        )
      ),
      salt
    );
  }
}
