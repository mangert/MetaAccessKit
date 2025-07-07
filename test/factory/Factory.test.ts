import { network } from "hardhat";
import { loadFixture, ethers, expect  } from "../setup";
//import { forwarderName, ForwardRequest, signMetaTx } from "./helpers";

describe("Clone factory tests", function() {
    async function deploy() {        
        const [user0, user1, user2] = await ethers.getSigners();
        
        //деплоим форвардер-контракт - чтобы был (используется при создании фабрики)       
        const forwarderName = "ERC2771Forwarder"
        const forwarder_Factory = await ethers.getContractFactory("ERC2771Forwarder");
        const forwarder = await forwarder_Factory.deploy(forwarderName);
        await forwarder.waitForDeployment();    
        //деплоим контракт фабрики
        const cloneFactory_Factory = await ethers.getContractFactory("AccountBox");
        const accountBox = await cloneFactory_Factory.deploy(forwarder);
        await accountBox.waitForDeployment();

        return { user0, user1, user2, forwarder, accountBox }
    }

    describe("deployment tеsts", function() { //примитивный тест на деплой - просто проверить, что общая часть работает
        it("should be deployed", async function() {
            
            const { forwarder, accountBox } = await loadFixture(deploy); 
            
            const implAddr = await accountBox.implementation(); //получаем адрес задеплоенный шаблон контракта-счета
            const impl = await ethers.getContractAt("ETHAccountV2", implAddr); //сделаем из него контракт

            const forwarderAddress = await impl.trustedForwarder(); //посмотрим, с каким форвардером нам фабрика записала шаблон           
            expect(forwarderAddress).to.equal(forwarder.target);  //и убедимся, что с верным

        });
    });

});