// SPDX-License-Identifier: MIT
/**
 * @title BlessnetBeacon.sol. Blessnet config beacon.
 *
 * @author abraxas https://abraxaslabs.io
 *         for
 *         blessnet https://bless.net
 *
 *         version 0.1.0
 */

pragma solidity ^0.8.23;

import {IBlessnetBeacon} from "./IBlessnetBeacon.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

contract BlessnetBeaconMock is IBlessnetBeacon {
  bytes32 private constant BlessnetBeaconStorageLocation =
    0x4345db60d6d950a786289d45c5cef6c8be0f8dad64b2d21d61f4bd9ecc639200; // keccak256(abi.encode(uint256(keccak256("BlessnetBeacon")) - 1)) & ~bytes32(uint256(0xff));

  constructor(address relayer_) {
    BlessnetBeaconStorage storage $ = _getBlessnetBeaconStorage();
    $.relayerAddress = relayer_;
    $.nativeDecimals = 18;
  }

  /**
   * @notice `onlyRelayer` specifies that only the relayer address can
   * make this call.
   */
  modifier onlyRelayer() {
    BlessnetBeaconStorage storage $ = _getBlessnetBeaconStorage();
    if (msg.sender != $.relayerAddress) {
      revert("Only relayer");
    }
    _;
  }

  /**
   * @dev getVersion: Retrieve the current version
   */
  function getVersion() external pure virtual returns (string memory) {
    return ("0.1.0");
  }

  /**
   * @dev blessDecimals: Number of decimals in the bless token
   */
  function decimals() public view virtual returns (uint8) {
    return 18;
  }

  /**
   * @dev convertNativeToBless: Convert a native token amount to an amount in
   * $bless token. This receives amounts in wei, NOT whole token, and returns
   * amounts of $bless in wei (i.e. to 18dp).
   */
  function convertNativeToBless(
    uint256 native_
  ) external view virtual returns (uint256) {
    BlessnetBeaconStorage storage $ = _getBlessnetBeaconStorage();
    uint256 result = (native_ * $.integerNativeInBless) /
      10 ** $.nativeDecimals;
    return (result);
  }

  /**
   * @dev convertBlessToNative: Convert a $bless token amount to an amount in
   * native token.
   */
  function convertBlessToNative(
    uint256 bless_
  ) external view virtual returns (uint256) {
    BlessnetBeaconStorage storage $ = _getBlessnetBeaconStorage();
    uint256 result = (bless_ * $.integerBlessInNative) / 10 ** decimals();
    return (result);
  }

  /**
   * @dev getCurrentRelayer: Retrieve the current relayer
   */
  function getCurrentRelayer() public view returns (address currentRelayer_) {
    BlessnetBeaconStorage storage $ = _getBlessnetBeaconStorage();
    return ($.relayerAddress);
  }

  /**
   * @dev getPreviousRelayer: Retrieve the previous relayer, if within the buffer
   */
  function getPreviousRelayer() public view returns (address previousRelayer_) {
    BlessnetBeaconStorage storage $ = _getBlessnetBeaconStorage();
    if (block.timestamp < ($.updateTimestamp + $.bufferInSeconds)) {
      return ($.previousRelayerAddress);
    } else {
      return (address(type(uint160).max));
    }
  }

  /**
   * @dev getMessageIsValidBySignature: Return if the message is valid or not by checking an
   * accompanying signed message is from the trusted relay
   */
  function getMessageIsValidBySignature(
    bytes32 hash_,
    bytes memory sig_,
    StorageRecord calldata blessing_
  ) external view returns (bool) {
    if (!_signatureIsValid(hash_, sig_)) {
      return (false);
    }

    if (!_hashIsValid(blessing_, hash_)) {
      return (false);
    }

    return (true);
  }

  /**
   * @dev getMessageIsValidBySender: Return if the message is valid or not by checking the
   * msg.sender is the trusted relay.
   */
  function getMessageIsValidBySender(
    address sender_
  ) external view returns (bool) {
    return (_senderIsValid(sender_));
  }

  /**
   * @dev _signatureIsValid: Signature is from the relayer address
   *
   * @param hash_ The hash that has been signed.
   * @param sig_ The passed signature.
   */
  function _signatureIsValid(
    bytes32 hash_,
    bytes memory sig_
  ) internal view returns (bool) {
    BlessnetBeaconStorage storage $ = _getBlessnetBeaconStorage();
    bytes32 signedHash = keccak256(
      abi.encodePacked("\x19Ethereum Signed Message:\n32", hash_)
    );

    if (
      SignatureChecker.isValidSignatureNow($.relayerAddress, signedHash, sig_)
    ) {
      return (true);
    } else {
      if (block.timestamp < ($.updateTimestamp + $.bufferInSeconds)) {
        return
          SignatureChecker.isValidSignatureNow(
            $.previousRelayerAddress,
            signedHash,
            sig_
          );
      } else {
        return (false);
      }
    }
  }

  /**
   * @dev _hashIsValid: Clear text data matches the hash
   *
   * @param blessing_ The blessing data being processed.
   * @param hash_ The hash that has been signed.
   */
  function _hashIsValid(
    StorageRecord calldata blessing_,
    bytes32 hash_
  ) internal pure returns (bool) {
    return ((keccak256(abi.encode(blessing_)) == hash_));
  }

  /**
   * @dev _senderIsValid: Return if the message is valid or not by checking the
   * msg.sender if the trusted relay.
   */
  function _senderIsValid(address sender_) internal view returns (bool) {
    if (sender_ == getCurrentRelayer()) {
      return (true);
    }
    if (sender_ == getPreviousRelayer()) {
      return (true);
    }
    return (false);
  }

  function _getBlessnetBeaconStorage()
    private
    pure
    returns (BlessnetBeaconStorage storage $)
  {
    assembly {
      $.slot := BlessnetBeaconStorageLocation
    }
  }
}
