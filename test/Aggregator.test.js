const Aggregator = artifacts.require("./Aggregator");

require('chai')
    .use(require('chai-as-promised'))
    .should()

contract('Aggregator', ([deployer]) => {
    const test = "Contract Smoke Test"

    const DAI = '0x6B175474E89094C44Da98b954EedeAC495271d0F' // ERC20 DAI Address
    const cDAI = '0x5d3a536e4d6dbd6114cc1ead35777bab948e3643' // Compound's cDAI Address
    const aDAI = '0x028171bCA77440897B824Ca71D1c56caC55b68A3' // Aave's aDAI Address
    let aaveLendingPool = '0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9' // Aave's Lending Pool Contract 

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

        it('emits deposit event', async () => {
            const result = await aggregator.deposit(DAI, cDAI, aaveLendingPool)
            console.log(result.logs[0].args.selectedExchange)

            const log = result.logs[0]
            log.event.should.equal('Deposit')
        })

    })
})