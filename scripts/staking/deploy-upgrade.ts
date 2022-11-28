import { ethers, upgrades } from "hardhat";
import { readFileSync } from 'fs'
import { writeFileSync } from 'fs'

async function main() {
    const address = readFileSync(__dirname + '/../../.proxy-staking', 'utf8').toString();
    const contractFactory = await ethers.getContractFactory("ERC721Staking");
    const contract = await upgrades.upgradeProxy(address, contractFactory, 
        // {
        //     call: {fn: 'existing', args: ["0x699213E7c3bD356DF066ED05f4d01BAf021C957c"]}
        // }
    );

    // const implementation = await upgrades.erc1967.getImplementationAddress(contract.address);
    // console.log("upgrade contract: ", implementation);
    // writeFileSync(__dirname + '/../.implementation-contract', implementation);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});