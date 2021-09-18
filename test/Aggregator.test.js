const Aggregator = artifacts.require("./Aggregator");

require('chai')
    .use(require('chai-as-promised'))
    .should()

contract('Aggregator', () => {
    const test = "Contract Smoke Test"
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
})