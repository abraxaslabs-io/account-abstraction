// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "./BlessedAccount.sol";

/**
 * A sample factory contract for BlessedAccount
 * A UserOperations "initCode" holds the address of the factory, and a method call (to createAccount, in this sample factory).
 * The factory's createAccount returns the target account address even if it is already installed.
 * This way, the entryPoint.getSenderAddress() can be called either before or after the account is created.
 */
contract BlessedAccountFactory {
  BlessedAccount public immutable accountImplementation;
  IBlessnetBeacon public immutable _beacon;

  constructor(IEntryPoint entryPoint_, IBlessnetBeacon beacon_) {
    accountImplementation = new BlessedAccount(entryPoint_, beacon_);
    _beacon = beacon_;
  }

  function beacon() public view virtual returns (IBlessnetBeacon) {
    return _beacon;
  }

  /**
   * create an account, and return its address.
   * returns the address even if the account is already deployed.
   * Note that during UserOperation execution, this method is called only if the account is not deployed.
   * This method returns an existing account address so that entryPoint.getSenderAddress() would work even after account creation
   */
  function createAccount(
    string calldata platform_,
    string calldata userId_
  ) public returns (BlessedAccount ret) {
    // The salt is a hash of the concatenated hashes of the platform and user id, so that each
    // unique platform/userId pair creates a single account address, and so we don't get
    // multiple platform/userId pairs that would create the same salt (e.g. twitter omnus would
    // produce the same hash as twitt eromnus if we just hashed the concatenated strings).
    (address addr, bytes32 salt) = getAddress(platform_, userId_);
    uint256 codeSize = addr.code.length;
    if (codeSize > 0) {
      return BlessedAccount(payable(addr));
    }
    ret = BlessedAccount(
      payable(
        new ERC1967Proxy{salt: bytes32(salt)}(
          address(accountImplementation),
          abi.encodeCall(BlessedAccount.initialize, (platform_, userId_))
        )
      )
    );
  }

  /**
   * calculate the counterfactual address of this account as it would be returned by createAccount()
   */
  function getAddress(
    string calldata platform_,
    string calldata userId_
  ) public view returns (address, bytes32) {
    bytes32 salt = keccak256(
      abi.encodePacked(
        keccak256(abi.encodePacked(platform_)),
        keccak256(abi.encodePacked(userId_))
      )
    );
    return (
      Create2.computeAddress(
        salt,
        keccak256(
          abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(
              address(accountImplementation),
              abi.encodeCall(BlessedAccount.initialize, (platform_, userId_))
            )
          )
        )
      ),
      salt
    );
  }
}
