// SPDX-License-Identifier: MIT
/**
 * @title BlessedAccountV1.sol. Blessnet abstracted account, version 1.
 *
 * @author abraxas https://abraxaslabs.io
 *         for
 *         blessnet https://bless.net
 *
 *         version 0.1.0
 */

pragma solidity 0.8.23;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {BaseAccount, IEntryPoint, PackedUserOperation} from "../../core/BaseAccount.sol";
import "../../core/Helpers.sol";
import {TokenCallbackHandler} from "../../samples/callback/TokenCallbackHandler.sol";
import {IBlessnetBeacon} from "../beacon/IBlessnetBeacon.sol";

/**
 * Minimal account.
 *  has execute, eth handling methods
 *  has a single signer (relay) that can send requests through the entryPoint.
 */
contract BlessedAccountV1 is BaseAccount, TokenCallbackHandler, Initializable {
  uint256 public constant VERSION = 1;

  IBlessnetBeacon private immutable _beacon;
  IEntryPoint private immutable _entryPoint;

  string public platform;
  string public userId;

  event BlessedAccountInitialized(
    IEntryPoint indexed entryPoint,
    string indexed platform,
    string indexed userId
  );

  modifier onlyThisAddress() {
    require(msg.sender == address(this), "Only self E01");
    _;
  }

  constructor(IEntryPoint anEntryPoint, IBlessnetBeacon beacon_) {
    _entryPoint = anEntryPoint;
    _beacon = beacon_;
    _disableInitializers();
  }

  /**
   * @param platform_ the platform for this blessed account.
   * @param userId_ the userId for this blessed account.
   */
  function initialize(
    string calldata platform_,
    string calldata userId_
  ) public virtual initializer {
    _initialize(platform_, userId_);
  }

  function _initialize(
    string calldata platform_,
    string calldata userId_
  ) internal virtual {
    platform = platform_;
    userId = userId_;
    emit BlessedAccountInitialized(_entryPoint, platform_, userId_);
  }

  function entryPoint() public view virtual override returns (IEntryPoint) {
    return _entryPoint;
  }

  function beacon() public view virtual returns (IBlessnetBeacon) {
    return _beacon;
  }

  receive() external payable {}

  /**
   * execute a transaction
   * @param dest destination address to call
   * @param value the value to pass in this call
   * @param func the calldata to pass in this call
   */
  function execute(address dest, uint256 value, bytes calldata func) external {
    _requireFromEntryPoint();
    _call(dest, value, func);
  }

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
  ) external {
    _requireFromEntryPoint();
    require(
      dest.length == func.length &&
        (value.length == 0 || value.length == func.length),
      "wrong array lengths"
    );
    if (value.length == 0) {
      for (uint256 i = 0; i < dest.length; i++) {
        _call(dest[i], 0, func[i]);
      }
    } else {
      for (uint256 i = 0; i < dest.length; i++) {
        _call(dest[i], value[i], func[i]);
      }
    }
  }

  /// implement template method of BaseAccount
  /// @notice
  /// Validate that the message has been signed by the relayer. In this implementation the relayer
  /// service is trusted to check that the origin of the message is from the platform and userId
  /// indicated. In future implementations this will be replaced with a call to a WASM contract
  /// that validates the JWT has been signed by the specified account on the external platform.
  function _validateSignature(
    PackedUserOperation calldata userOp,
    bytes32 userOpHash
  ) internal virtual override returns (uint256 validationData) {
    bytes32 hash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
    address relayer = _beacon.getCurrentRelayer();
    address signer = ECDSA.recover(hash, userOp.signature);
    if (relayer != signer) {
      revert("relay only");
    } else {
      return SIG_VALIDATION_SUCCESS;
    }
  }

  function _call(address target, uint256 value, bytes memory data) internal {
    (bool success, bytes memory result) = target.call{value: value}(data);
    if (!success) {
      assembly {
        revert(add(result, 32), mload(result))
      }
    }
  }

  /**
   * check current account deposit in the entryPoint
   */
  function getDeposit() public view returns (uint256) {
    return entryPoint().balanceOf(address(this));
  }

  /**
   * deposit more funds for this account in the entryPoint
   */
  function addDeposit() public payable {
    entryPoint().depositTo{value: msg.value}(address(this));
  }

  /**
   * withdraw value from the account's deposit
   * @param withdrawAddress target to send to
   * @param amount to withdraw
   */
  function withdrawDepositTo(
    address payable withdrawAddress,
    uint256 amount
  ) public onlyThisAddress {
    entryPoint().withdrawTo(withdrawAddress, amount);
  }
}
