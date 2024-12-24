import { Wallet } from 'ethers'
import { ethers } from 'hardhat'
import { expect } from 'chai'
import {
  ERC1967Proxy__factory,
  BlessedAccountV1,
  BlessedAccountFactoryV1__factory,
  BlessedAccountV1__factory,
  TestUtil,
  TestUtil__factory,
  EntryPoint,
  BlessnetBeaconMock
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
import { fillUserOpDefaults, getUserOpHash, fillSignAndPack, signUserOp, packUserOp } from './UserOp'
import { parseEther } from 'ethers/lib/utils'
import { UserOperation } from './UserOperation'

describe.only('BlessedAccount', function () {
  let entryPointContract: EntryPoint
  let entryPoint: string
  let beaconContract: BlessnetBeaconMock
  let mockEntryPoint: EntryPoint
  let accounts: string[]
  let testUtil: TestUtil
  let accountOwner: Wallet
  let platform: string
  let platform2: string
  let userId: string
  let relayer: string

  platform = "telegram"
  userId = "omnus"

  platform2 = "x"

  const ethersSigner = ethers.provider.getSigner()

  before(async function () {
    entryPointContract = await deployEntryPoint()
    entryPoint = entryPointContract.address
    accounts = await ethers.provider.listAccounts()
    // ignore in geth.. this is just a sanity test. should be refactored to use a single-account mode..
    if (accounts.length < 2) this.skip()
    testUtil = await new TestUtil__factory(ethersSigner).deploy()
    accountOwner = createAccountOwner()
    relayer = accounts[9]
  })

  describe('#validateUserOp', () => {
    let account: BlessedAccountV1
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

      beaconContract = await beacon.deploy(relayer)

      const implementation = await new BlessedAccountV1__factory(ethersSigner).deploy(entryPointEoa, beaconContract.address)

      const proxy = await new ERC1967Proxy__factory(ethersSigner).deploy(implementation.address, '0x')
      account = BlessedAccountV1__factory.connect(proxy.address, epAsSigner)

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
      
      preBalance = await getBalance(account.address)
      const packedOp = packUserOp(userOp)

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
    let deployer: any
    let target: any

    it('check deployer', async () => {
      deployer = await new BlessedAccountFactoryV1__factory(ethersSigner).deploy(entryPoint, beaconContract.address)
      target = await deployer.callStatic.createAccount(platform, userId)
      expect(await isDeployed(target)).to.eq(false)
      await deployer.createAccount(platform, userId)
      expect(await isDeployed(target)).to.eq(true)
    })

    it('deploy with balance', async () => {
      deployer = await new BlessedAccountFactoryV1__factory(ethersSigner).deploy(entryPoint, beaconContract.address)
      target = await deployer.callStatic.createAccount(platform2, userId, {
        value: ethers.utils.parseEther("0.1"), 
      })
      expect(await isDeployed(target)).to.eq(false)
      await deployer.createAccount(platform2, userId, {
        value: ethers.utils.parseEther("0.1"), 
      })
      expect(await isDeployed(target)).to.eq(true)
    })

    it('balance of account is zero', async () => {
      const balance = await getBalance(target);
      expect(balance).to.eq(0)
    })

    it('entrypoint deposit balance is non-zero', async () => {
      const contractInstance = BlessedAccountV1__factory.connect(target, ethersSigner);
      const deposit = await contractInstance.getDeposit()
      expect(deposit).to.eq(ethers.utils.parseEther("0.1"))
    })

    it('user can withdraw via call through entrypoint', async () => {
      const withdrawalAddress = "0x0000000000000000000000000000000000000011"

      const contractInstance = BlessedAccountV1__factory.connect(target, ethersSigner)
      const withdrawCalldata = contractInstance.interface.encodeFunctionData('withdrawDepositTo', [withdrawalAddress, ethers.utils.parseEther("0.05")])
      const callData = contractInstance.interface.encodeFunctionData('execute', [target, 0, withdrawCalldata])

      const preBalance = BigInt(await getBalance(withdrawalAddress))
      const preDeposit = (await entryPointContract.getDepositInfo(target))[0]

      console.log(preBalance)
      console.log(preDeposit)

      const callGasLimit = 200000
      const verificationGasLimit = 100000
      const maxFeePerGas = 3e9
      const chainId = await ethers.provider.getNetwork().then(net => net.chainId)

      const userOp = signUserOp(fillUserOpDefaults({
        sender: target,
        callData: callData,
        callGasLimit,
        verificationGasLimit,
        maxFeePerGas
      }), accountOwner, entryPoint, chainId)

      const packedOp = packUserOp(userOp)
      await entryPointContract.handleOps([packedOp], target)

      const postBalance = BigInt(await getBalance(withdrawalAddress))
      const postDeposit = (await entryPointContract.getDepositInfo(target))[0]

      console.log(postBalance)
      console.log(postDeposit)
      expect(postBalance).to.eq(ethers.utils.parseEther("0.05"))
    })

    it('user cannot withdraw via call through entrypoint if not signed by relayer', async () => {
      const withdrawalAddress = "0x0000000000000000000000000000000000000011"
      const contractInstance = BlessedAccountV1__factory.connect(target, ethersSigner)
      const withdrawCalldata = contractInstance.interface.encodeFunctionData('withdrawDepositTo', [withdrawalAddress, ethers.utils.parseEther("0.05")])
      const callData = contractInstance.interface.encodeFunctionData('execute', [target, 0, withdrawCalldata])

      const callGasLimit = 200000
      const verificationGasLimit = 100000
      const maxFeePerGas = 3e9
      const chainId = await ethers.provider.getNetwork().then(net => net.chainId)

      const notAccountOwner = createAccountOwner()

      const userOp2 = signUserOp(fillUserOpDefaults({
        sender: target,
        nonce: 1,
        callData: callData,
        callGasLimit,
        verificationGasLimit,
        maxFeePerGas
      }), notAccountOwner, entryPoint, chainId)

      const packedOp2 = packUserOp(userOp2)

      await expect(entryPointContract.handleOps([packedOp2], target))
      .to.be.revertedWith('AA23 reverted')
    })
  })
})
