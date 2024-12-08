import { Wallet } from 'ethers'
import { ethers } from 'hardhat'
import { expect } from 'chai'
import {
  ERC1967Proxy__factory,
  BlessedAccount,
  BlessedAccountFactory__factory,
  BlessedAccount__factory,
  TestCounter,
  TestCounter__factory,
  TestUtil,
  TestUtil__factory
} from '../typechain'
import {
  createAccount,
  createAddress,
  createAccountOwner,
  getBalance,
  isDeployed,
  ONE_ETH,
  HashZero, deployEntryPoint
} from './z_blessnet-testutils'
import { fillUserOpDefaults, getUserOpHash, encodeUserOp, signUserOp, packUserOp } from './UserOp'
import { parseEther } from 'ethers/lib/utils'
import { UserOperation } from './UserOperation'

describe('BlessedAccount', function () {
  let entryPoint: string
  let accounts: string[]
  let testUtil: TestUtil
  let accountOwner: Wallet
  let platform: string
  let userId: string
  let relayer: string

  platform = "telegram"
  userId = "omnus"

  const ethersSigner = ethers.provider.getSigner()

  before(async function () {
    entryPoint = await deployEntryPoint().then(e => e.address)
    accounts = await ethers.provider.listAccounts()
    // ignore in geth.. this is just a sanity test. should be refactored to use a single-account mode..
    if (accounts.length < 2) this.skip()
    testUtil = await new TestUtil__factory(ethersSigner).deploy()
    accountOwner = createAccountOwner()
    relayer = accounts[9]
  })

  describe('#validateUserOp', () => {
    let account: BlessedAccount
    let userOp: UserOperation
    let userOpHash: string
    let preBalance: number
    let expectedPay: number
    let relayer: string

    const actualGasPrice = 1e9
    // for testing directly validateUserOp, we initialize the account with EOA as entryPoint.
    let entryPointEoa: string

    before(async () => {
      entryPointEoa = accounts[2]
      const epAsSigner = await ethers.getSigner(entryPointEoa)
      relayer = accountOwner.address

      const beacon = await ethers.getContractFactory("BlessnetBeaconMock")

      const hhBeacon = await beacon.deploy(relayer)

      // cant use "BlessedAccountFactory", since it attempts to increment nonce first
      const implementation = await new BlessedAccount__factory(ethersSigner).deploy(entryPointEoa, hhBeacon.address)

      const proxy = await new ERC1967Proxy__factory(ethersSigner).deploy(implementation.address, '0x')
      account = BlessedAccount__factory.connect(proxy.address, epAsSigner)

      await ethersSigner.sendTransaction({ from: accounts[0], to: account.address, value: parseEther('0.2') })
      const callGasLimit = 200000
      const verificationGasLimit = 100000
      const maxFeePerGas = 3e9
      const chainId = await ethers.provider.getNetwork().then(net => net.chainId)

      userOp = signUserOp(fillUserOpDefaults({
        sender: account.address,
        callGasLimit,
        verificationGasLimit,
        maxFeePerGas
      }), accountOwner, entryPointEoa, chainId)

      userOpHash = await getUserOpHash(userOp, entryPointEoa, chainId)

      expectedPay = actualGasPrice * (callGasLimit + verificationGasLimit)

      console.log(expectedPay)

      preBalance = await getBalance(account.address)
      const packedOp = packUserOp(userOp)

      console.log(packedOp)

      const ret = await account.validateUserOp(packedOp, userOpHash, expectedPay, { gasPrice: actualGasPrice })

      await ret.wait()
    })

    it('should pay', async () => {
      const postBalance = await getBalance(account.address)
      expect(preBalance - postBalance).to.eql(expectedPay)
    })

    it('should revert on wrong signature', async () => {
      const userOpHash = HashZero
      const packedOp = packUserOp(userOp)
      await expect(account.callStatic.validateUserOp({ ...packedOp, nonce: 1 }, userOpHash, 0))
        .to.be.revertedWith('relay only')
    })
  })

  context('BlessedAccountFactory', () => {
    it('sanity: check deployer', async () => {
      const ownerAddr = createAddress()
      const deployer = await new BlessedAccountFactory__factory(ethersSigner).deploy(entryPoint, accounts[9])
      const target = await deployer.callStatic.createAccount(platform, userId)
      expect(await isDeployed(target)).to.eq(false)
      await deployer.createAccount(platform, userId)
      expect(await isDeployed(target)).to.eq(true)
    })
  })
})
