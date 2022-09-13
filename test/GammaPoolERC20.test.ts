import { ethers } from 'hardhat'
import { expect } from 'chai'

const UNISWAPV2_PROTOCOL = 1
const TEST_AMOUNT = 1000

describe("GammaPoolERC20", function () {
    let TestERC20: any
    let TestAddressCalculator: any
    let TestAbstractProtocol: any
    let TestLongStrategy: any
    let TestShortStrategy: any
    let GammaPool: any
    let TestGammaPoolFactory: any
    let factory: any
    let addressCalculator: any
    let tokenA: any
    let tokenB: any
    let cfmm: any
    let owner: any
    let addr1: any
    let addr2: any
    let addr3: any
    let longStrategy: any
    let shortStrategy: any
    let gammaPool: any
    let protocol: any

    beforeEach(async function () {
        // instantiate a GammaPool
        TestERC20 = await ethers.getContractFactory("TestERC20")
        TestAddressCalculator = await ethers.getContractFactory("TestAddressCalculator")
        TestGammaPoolFactory = await ethers.getContractFactory("TestGammaPoolFactory")
        TestAbstractProtocol = await ethers.getContractFactory("TestAbstractProtocol")
        GammaPool = await ethers.getContractFactory("GammaPool");
        [owner, addr1, addr2, addr3] = await ethers.getSigners()

        TestLongStrategy = await ethers.getContractFactory("TestLongStrategy");
        TestShortStrategy = await ethers.getContractFactory("TestShortStrategy");    

        tokenA = await TestERC20.deploy("Test Token A", "TOKA");
        tokenB = await TestERC20.deploy("Test Token B", "TOKB");
        cfmm = await TestERC20.deploy("Test CFMM", "CFMM");
        longStrategy = await TestLongStrategy.deploy();
        shortStrategy = await TestShortStrategy.deploy();
        addressCalculator = await TestAddressCalculator.deploy();
        
        factory = await TestGammaPoolFactory.deploy(
            cfmm.address,
            UNISWAPV2_PROTOCOL,
            [tokenA.address, tokenB.address],
            ethers.constants.AddressZero
        )

        protocol = await TestAbstractProtocol.deploy(
            factory.address,
            UNISWAPV2_PROTOCOL,
            longStrategy.address,
            shortStrategy.address,
            2,
            3
        )

        await factory.setProtocol(protocol.address)
        
        // deploy the gamma pool
        await (await factory.createPool()).wait()

        const key = await addressCalculator.getGammaPoolKey(cfmm.address, UNISWAPV2_PROTOCOL)
        const pool = await factory.getPool(key) // returns address

        gammaPool = await GammaPool.attach(pool)
    })

    describe("base functions are working", function () {

        describe("read functions", function () {

            it("name is called correctly", async function () {
                const res = await gammaPool.name()
                console.log(await gammaPool.tokenBalances())
                expect(res).to.equal("GAMA-V1")
            })

            it("symbol is called correctly", async function () {
                const res = await gammaPool.symbol()

                expect(res).to.equal("GAMA-V1")
            })

            it("decimals is called correctly", async function () {
                const res = await gammaPool.decimals()
                
                expect(res).to.equal(18)
            })

            it("totalSupply is called correctly", async function () {
                // increase totalSupply of GammaPool
                await (await gammaPool.deposit(TEST_AMOUNT, owner.address)).wait()
                const poolBal = await gammaPool.balanceOf(owner.address)
                
                expect(poolBal).to.equal(TEST_AMOUNT)
            })

            it("balanceOf is called correctly", async function () {

            })

            it("allowance is called correctly", function () {
                
            })
        })

        describe("write functions", function () {
            
            it("approve is called correctly", function () {
                
            })
            
            it("LP tokens are transferred correctly", function () {
                
            })

            it("transferFrom is called correctly", function () {
                
            })

        })
    })
})