import fs from "fs";
import path from "path";
import hre, { ethers, run } from "hardhat";
//скрипт для деплоя и верификации
async function main() {   
    
    const forwarderContractName = "ERC2771Forwarder";
    const contractName = "ETHAccountV1";       
    const [deployer, owner] = await ethers.getSigners();    

    //деплоим форвардер-контракт        
    console.log("Forwarder DEPLOYING...");
        
    const forwarder_Factory = await ethers.getContractFactory(forwarderContractName);
    const forwarder = await forwarder_Factory.deploy(forwarderContractName);
    await forwarder.waitForDeployment();        

    const forwarderAddress = await forwarder.getAddress();
    console.log("Forwarder deployed at:", forwarderAddress);

    //ждем подтверждения, чтобы верификация не отвалилась
    const forwardertx = forwarder.deploymentTransaction();
    if (forwardertx) {
        await forwardertx.wait(5); // ← ждем 5 подтверждений
    }  

    // Логируем в файл форвардер
    const logPath = path.join(__dirname, "logs", "deploy-log.txt");
    fs.mkdirSync(path.dirname(logPath), { recursive: true });
    fs.appendFileSync(
        logPath,
        `[${new Date().toISOString()}] ${forwarderContractName} deployed at ${forwarderAddress} by ${deployer.address}\n`
    );            
    
    //деплоим контракт счета    
    const constructorArgs: [number, string] = [1, forwarderAddress]; // аргументы конструктора   (id=1 для примера)
    const accountETH_Factory = await ethers.getContractFactory(contractName);
    const accountETH = await accountETH_Factory.deploy(...constructorArgs);
    await accountETH.waitForDeployment();    
    
    const accountAddress = await accountETH.getAddress();
    console.log("Account deployed at:", accountAddress);
    
    //ждем подтверждения, чтобы верификация не отвалилась
    const tx = accountETH.deploymentTransaction();
    if (tx) {
        await tx.wait(5); // ← ждем 5 подтверждений
    } 

    // Логируем в файл            
    fs.appendFileSync(
        logPath,
        `[${new Date().toISOString()}] ${contractName} deployed at ${accountAddress} by ${deployer.address}\n`
    );    
    //запомним адрес форвардера - в других контрактах пригодится
    const addressesPath = path.join(__dirname, "logs", "addresses.json");
    fs.writeFileSync(addressesPath, JSON.stringify({ forwarder: forwarderAddress }, null, 2));   

    
    //верификация    
    console.log("VERIFY...");    

    //сначала форвардер    
    try {
       await run("verify:verify", {
         address: forwarderAddress,
         constructorArguments: [forwarderContractName],
       });
       console.log("Forwarder Verification successful!");
     } catch (error: any) {
       if (error.message.toLowerCase().includes("already verified")) {
         console.log("Already verified");
       } else {
         console.error("Verification failed:", error);
       }
     }

    //а потом один контракт счета
    try {
       await run("verify:verify", {
         address: accountAddress,
         constructorArguments: constructorArgs,
       });
       console.log("Account Verification successful!");
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