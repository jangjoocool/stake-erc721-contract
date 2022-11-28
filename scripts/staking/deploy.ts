import { ethers, upgrades } from "hardhat";
import { writeFileSync } from 'fs'

async function main() {
    const contractFactory = await ethers.getContractFactory("ERC721Staking");
    const contract = await upgrades.deployProxy(
        contractFactory,
        ["0x16AB966157655Bc5Dc6Ed7C64b1964A8ba342fC8", "0xe8AbeBB3f8FB59CbefD292aECF06361611D7A63F"],
        {kind: "uups"}
    );
    await contract.deployed();
    
    const implementation = await upgrades.erc1967.getImplementationAddress(contract.address);
    console.log("Implementation Contract", implementation)
    console.log("Proxy Contract:", contract.address);

    writeFileSync(__dirname + '/../../.proxy-staking', contract.address);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});