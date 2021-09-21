const Aggregator = artifacts.require("./Aggregator")
const daiABI = require("../mint-dai/dai-abi.json")

require('chai')
    .use(require('chai-as-promised'))
    .should()

const DAI = '0x6b175474e89094c44da98b954eedeac495271d0f' // ERC20 DAI Address
const cDAI = '0x5d3a536e4d6dbd6114cc1ead35777bab948e3643' // Compound's cDAI Address
const aDAI = '0x028171bCA77440897B824Ca71D1c56caC55b68A3' // Aave's aDAI Address
const aaveLendingPool = '0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9' // Aave's Lending Pool Contract

const EVM_REVERT = 'VM Exception while processing transaction: revert'

contract('Aggregator', ([deployer]) => {
    const test = "Contract Smoke Test"

    const daiContract = new web3.eth.Contract(daiABI, DAI);
    let aggregator

    beforeEach(async () => {
        // Fetch contract
        aggregator = await Aggregator.new()
    })

    describe('deployment', () => {

        it('passes the smoke test', async () => {
            const result = await aggregator.test()
            result.should.equal(test)
        })
    })

    describe('exchange rates', async () => {

        it('fetches compound exchange rate', async () => {
            const result = await aggregator.getCompoundExchangeRate.call(cDAI)
            console.log(result.toString())
            result.should.not.equal(0)
        })

        it('fetches aave exchange rate', async () => {
            const result = await aggregator.getAaveExchangeRate.call(aaveLendingPool, DAI)
            console.log(result.toString())
            result.should.not.equal(0)
        })
    })

    describe('deposits', async () => {

        let amount = 10
        let amountInWei = web3.utils.toWei(amount.toString(), 'ether')
        let result

        describe('success', async () => {
            beforeEach(async () => {
                // Approve
                await daiContract.methods.approve(aggregator.address, amountInWei).send({ from: deployer })

                // Initiate deposit
                result = await aggregator.deposit(DAI, cDAI, aaveLendingPool, amountInWei, { from: deployer })
            })

            it('tracks the dai amount', async () => {
                // Check dai balance in smart contract
                let balance
                balance = await aggregator.balanceOf.call({ from: deployer })
                console.log(balance.toString())
                balance.toString().should.equal(amountInWei.toString())
            })

            it('tracks where dai is stored', async () => {
                result = await aggregator.balanceWhere.call({ from: deployer })
                console.log(result)
            })

            it('emits deposit event', async () => {
                const log = result.logs[0]
                log.event.should.equal('Deposit')
            })
        })

        describe('failure', async () => {

            it('fails when transfer is not approved', async () => {
                await aggregator.deposit(DAI, cDAI, aaveLendingPool, amountInWei, { from: deployer }).should.be.rejectedWith(EVM_REVERT)
            })

            it('fails when amount is 0', async () => {
                await aggregator.deposit(DAI, cDAI, aaveLendingPool, 0, { from: deployer }).should.be.rejectedWith(EVM_REVERT)
            })

        })

    })

    describe('withdraws', async () => {

        let amount = 10
        let amountInWei = web3.utils.toWei(amount.toString(), 'ether')
        let result

        describe('success', async () => {
            beforeEach(async () => {
                // Approve
                await daiContract.methods.approve(aggregator.address, amountInWei).send({ from: deployer })

                // Initiate deposit
                await aggregator.deposit(DAI, cDAI, aaveLendingPool, amountInWei, { from: deployer })
            })

            it('emits withdraw event', async () => {
                result = await aggregator.withdraw(DAI, cDAI, aaveLendingPool, { from: deployer })
                const log = result.logs[0]
                log.event.should.equal('Withdraw')
            })

        })

        describe('failure', async () => {

            it('fails if user has no balance', async () => {
                await aggregator.withdraw(DAI, cDAI, aaveLendingPool, { from: deployer }).should.be.rejectedWith(EVM_REVERT)
            })

        })

    })

    describe('rebalance', async () => {

        let amount = 10
        let amountInWei = web3.utils.toWei(amount.toString(), 'ether')
        let result

        describe('success', async () => {
            beforeEach(async () => {
                // Approve
                await daiContract.methods.approve(aggregator.address, amountInWei).send({ from: deployer })

                // Initiate deposit
                await aggregator.deposit(DAI, cDAI, aaveLendingPool, amountInWei, { from: deployer })
            })

            it('emits rebalance event', async () => {
                result = await aggregator.rebalance(DAI, cDAI, aaveLendingPool, { from: deployer })
                const log = result.logs[0]
                log.event.should.equal('Rebalance')
            })

        })

        describe('failure', async () => {

            it('fails if user has no balance', async () => {
                await aggregator.rebalance(DAI, cDAI, aaveLendingPool, { from: deployer }).should.be.rejectedWith(EVM_REVERT)
            })

        })

    })

})