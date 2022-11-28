import hre from 'hardhat';
import { readFileSync } from 'fs'

async function main() {
    const address = readFileSync(__dirname + '/../../.proxy-staking', 'utf8').toString();
    
    await hre.run("verify:verify", {
        address: address,
    });
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});