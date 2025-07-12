import fs from "fs";
import path from "path";
import hre, { ethers, run } from "hardhat";
//скрипт для деплоя и верификации
async function main() {
    
    const addressesPath = path.join(__dirname, "logs", "addresses.json");
    const addresses = JSON.parse(fs.readFileSync(addressesPath, "utf-8"));
    const forwarderAddress = addresses.forwarder;    
    const contractName = "AccountBox";       
    const [deployer, owner] = await ethers.getSigners();    

    //деплоим фaбрику
    console.log("AccountBox DEPLOYING...");
        
    const accountBox_Factory = await ethers.getContractFactory(contractName);
    const accountBox = await accountBox_Factory.deploy(forwarderAddress);
    await accountBox.waitForDeployment();        

    const accountBoxAddress = await accountBox.getAddress();
    console.log("AccountBox deployed at:", accountBoxAddress);

    //ждем подтверждения, чтобы верификация не отвалилась
    const tx = accountBox.deploymentTransaction();
    if (tx) {
        await tx.wait(5); // ← ждем 5 подтверждений
    }  

    const implAddress = await accountBox.implementation(); //смотрим, куда фабрика задеплоила имплементацию
    console.log("Implementation deployed at:", implAddress);    

    // Логируем в файл    
    const logPath = path.join(__dirname, "logs", "deploy-log.txt");
    fs.mkdirSync(path.dirname(logPath), { recursive: true });
    fs.appendFileSync(
        logPath,
        `[${new Date().toISOString()}] ${contractName} deployed at ${accountBoxAddress} by ${deployer.address}\n`
    );            
    fs.appendFileSync(
        logPath,
        `[${new Date().toISOString()}] implementation sample deployed at ${implAddress} by ${deployer.address}\n`
    );                   
       
    //верификация    
    console.log("VERIFY...");    
    //сначала фабрику
    try {
       await run("verify:verify", {
         address: accountBoxAddress,
         constructorArguments: [forwarderAddress],
       });
       console.log("AccountBox Verification successful!");
     } catch (error: any) {
       if (error.message.toLowerCase().includes("already verified")) {
         console.log("Already verified");
       } else {
         console.error("Verification failed:", error);
       }
     }
    //а теперь имплементацию 
    try {
       await run("verify:verify", {
        address: implAddress,
        constructorArguments: [],  
        });
       console.log("AccountBox Verification successful!");
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