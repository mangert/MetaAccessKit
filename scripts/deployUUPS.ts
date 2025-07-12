import fs from "fs";
import path from "path";
import hre, { ethers, run, upgrades } from "hardhat";

//скрипт для деплоя, обновления и верификации
//деплоит фабрику через прокси, создает 1 аккаунт, обновляет фабрику, верифицирует контракты
async function main() {
    
    const addressesPath = path.join(__dirname, "logs", "addresses.json");
    const addresses = JSON.parse(fs.readFileSync(addressesPath, "utf-8"));
    const forwarderAddress = addresses.forwarder;    
    
    const contractName = "AccountBoxV1";
    const [deployer, owner] = await ethers.getSigners();    

    //деплоим фaбрику через прокси
    const Box = await ethers.getContractFactory("AccountBoxV1");
    console.log("AccountBoxV1 DEPLOYING...");
    const proxyBox = await upgrades.deployProxy(Box, [forwarderAddress, deployer.address], {
        kind: "uups",
    });
    const proxyBoxAddress = await proxyBox.getAddress();
    console.log("BoxProxy deployed at:", proxyBoxAddress);
    //ждем подтверждения, чтобы верификация не отвалилась
    await proxyBox.waitForDeployment();
    const txProxy = proxyBox.deploymentTransaction();
    if (txProxy) {
        await txProxy.wait(5); // ← ждем 5 подтверждений
    }
    //получаем адрес, с которым у нас задеплоилась сама имплементация фабрики
    const factoryAddressV1 = await upgrades.erc1967.getImplementationAddress(await proxyBox.getAddress());
    console.log("Factory V1 deployed at:", factoryAddressV1);                 
    
    //смотрим, куда фабрика задеплоила шаблон аккаунта
    const implAddress = await proxyBox.implementation(); 
    console.log("Implementation sample deployed at:", implAddress);    
    
    // Логируем в файл    
    const logPath = path.join(__dirname, "logs", "deploy-log.txt");
    fs.mkdirSync(path.dirname(logPath), { recursive: true });
    fs.appendFileSync(
        logPath,
        `[${new Date().toISOString()}] Proxy deployed at ${proxyBoxAddress} by ${deployer.address}\n`
    );            
    fs.appendFileSync(
        logPath,
        `[${new Date().toISOString()}] ${contractName} deployed at ${factoryAddressV1} by ${deployer.address}\n`
    );            
    fs.appendFileSync(
        logPath,
        `[${new Date().toISOString()}] implementation sample deployed at ${implAddress} by ${deployer.address}\n`
    );

    //верификация прокси и accountBoxV1
    // Верификация прокси (не требует constructorArgs)
    try {
        await run("verify:verify", {
            address: proxyBoxAddress,
        });
    console.log("Proxy verified!");
    } catch (e: any) {
        if (e.message.toLowerCase().includes("already verified")) {
            console.log("Proxy already verified.");
        } else {
            console.error("Proxy verification failed:", e);
        }
    }

    // Верификация реализации фабрики V1
    try {
        await run("verify:verify", {
            address: factoryAddressV1,
            constructorArguments: [], // конструктора нет, поэтому и аргументов нет
        });
        console.log("Factory V1 verified!");
    } catch (e: any) {
        if (e.message.toLowerCase().includes("already verified")) {
            console.log("Factory V1 verified.");
        } else {
            console.error("Factory V1 failed:", e);
        }
    }

    // Верификация шаблона аккаунта
    try {
        await run("verify:verify", {
            address: implAddress,
            constructorArguments: [forwarderAddress], 
        });
        console.log("Account implementation verified!");
    } catch (e: any) {
        if (e.message.toLowerCase().includes("already verified")) {
            console.log("Account implementation verified.");
        } else {
            console.error("Account implementation:", e);
        }
    }    

    //задеплоим один аккаунт
    console.log("Creating account...");    
    //сначала сделаем симуляцию и получим адрес контракта-клона
    const predictedClone0 = proxyBox.getFunction("createClone");
    const clone0Addr0 = (await predictedClone0.staticCallResult())[0]; //получаем возвращаемое значение - адрес нового акканута            
    //делаем реальную транзу
    const cloneTx = await proxyBox.createClone();
    await cloneTx.wait(5);                 
    fs.appendFileSync(
        logPath,
        `[${new Date().toISOString()}] Account deployed at ${clone0Addr0} by ${proxyBoxAddress}\n`
    );    
    
    //Делаем обновление
    console.log("Upgrading Factory...");    
    const contractNameV2 = "AccountBoxV2";
    const BoxV2 = await ethers.getContractFactory(contractNameV2);
    const proxyBoxV2 = await upgrades.upgradeProxy(proxyBox, BoxV2);
    
    const upgradeTx = proxyBoxV2.deploymentTransaction(); // может быть undefined

    if (upgradeTx) {
        await upgradeTx.wait(5); // ← ждем 5 подтверждений
        } else {
        console.warn("Не удалось получить транзакцию апгрейда. Подтверждение пропущено.");
        }
    
    //новый адрес реализации
    const factoryAddressV2 = await upgrades.erc1967.getImplementationAddress(await proxyBoxV2.getAddress());           
    console.log("Factory V2 deployed at:", factoryAddressV2);
    //смотрим, куда фабрика задеплоила шаблон аккаунта
    const implAddressV2 = await proxyBoxV2.implementation(); 
    console.log("Implementation sample deployed at:", implAddressV2);    

    // Логируем в файл            
                
    fs.appendFileSync(
        logPath,
        `[${new Date().toISOString()}] ${contractNameV2} deployed at ${factoryAddressV2} by ${deployer.address}\n`
    );            
    fs.appendFileSync(
        logPath,
        `[${new Date().toISOString()}] implementation sample deployed at ${implAddressV2} by ${deployer.address}\n`
    );

    // Верификация реализации фабрики V2
    try {
        await run("verify:verify", {
            address: factoryAddressV2,
            constructorArguments: [], // конструктора нет, поэтому и аргументов нет
        });
        console.log("Factory V2 verified!");
    } catch (e: any) {
        if (e.message.toLowerCase().includes("already verified")) {
            console.log("Factory V2 verified.");
        } else {
            console.error("Factory V2 failed:", e);
        }
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error); 
        process.exit(1);
    });