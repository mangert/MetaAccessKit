import fs from "fs";
import path from "path";
import hre, { ethers, run } from "hardhat";
//скрипт для деплоя и верификации
async function main() {
    
    const contractName = process.env.CONTRACT || "AmetistToken";
    const constructorArgs: string[] = []; // аргументы конструктора    

    //деплой
    
    console.log("AmetistToken DEPLOYING...");
    const [deployer, owner] = await ethers.getSigners();

    const ame_Factory = await ethers.getContractFactory(contractName);
    const ameToken = await ame_Factory.deploy();    
    await ameToken.waitForDeployment(); 

    const contractAddress = await ameToken.getAddress();
    console.log("Deployed at:", contractAddress);
    
    //ждем подтверждения, чтобы верификация не отвалилась
    const tx = ameToken.deploymentTransaction();
    if (tx) {
        await tx.wait(5); // ← ждем 5 подтверждений
    }   

    // Логируем в файл    
    const logPath = path.join(__dirname, "logs", "deploy-log.txt");
    fs.mkdirSync(path.dirname(logPath), { recursive: true });
    fs.appendFileSync(
        logPath,
        `[${new Date().toISOString()}] ${contractName} deployed at ${contractAddress} by ${deployer.address}\n`
    );
    
   
    //верификация
    console.log("VERIFY...");    
    
    try {
       await run("verify:verify", {
         address: contractAddress,
         constructorArguments: constructorArgs,
       });
       console.log("Verification successful!");
     } catch (error: any) {
       if (error.message.toLowerCase().includes("already verified")) {
         console.log("Already verified");
       } else {
         console.error("Verification failed:", error);
       }
     }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error); 
        process.exit(1);
    });