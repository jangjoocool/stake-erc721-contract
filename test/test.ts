import { expect } from "chai";
import { Contract } from "ethers";
import { ethers, upgrades } from "hardhat";

describe("ERC721Staking", async () => {
    let ERC20: Contract;
    let ERC721: Contract;
    let staking: Contract;


    beforeEach(async () => {
        const [owner] = await ethers.getSigners();        
        const ERC20Factory = await ethers.getContractFactory("RewardToken");
        ERC20 = await upgrades.deployProxy(ERC20Factory, ["test-ERC20", "t20"], {kind: "uups"});
        await ERC20.addMinter(owner.address);
        
        const ERC721Factory = await ethers.getContractFactory("StakingNFT");
        ERC721 = await upgrades.deployProxy(ERC721Factory, ["test-ERC721", "t721"], {kind: "uups"});

        const contractFactory = await ethers.getContractFactory("ERC721Staking");
        staking = await upgrades.deployProxy(contractFactory, [ERC20.address, ERC721.address], {kind: "uups"});
    });

    context('Deployment', async () => {
        it("ERC20", async () => {
            expect(await ERC20.name()).to.equal("test-ERC20");
        });

        it("ERC721", async () => {
            expect(await ERC721.name()).to.equal("test-ERC721");
        });

        it("staking", async () => {
            expect(await staking.rewardsToken()).to.equal(ERC20.address);
            expect(await staking.stakingToken()).to.equal(ERC721.address);
        });
    });

    context('Staking', async () => {
        beforeEach(async () => {
            await ERC20.mint(staking.address, 10000000);
        });

        it("balance of", async () => {
            expect(await ERC20.balanceOf(staking.address)).to.equal(10000000);
        });

        it("setup staking pool", async () => {
            await staking.setStakingPool(3000, 10000000);
            expect(await staking.isOnStaking()).to.equal(true);
        });
    });

});