import { network } from "hardhat";
import { loadFixture, ethers, expect  } from "../setup";


describe("meta ERC2771 tests", function() {
    async function deploy() {        
        const [user0, user1, user2] = await ethers.getSigners();
        
        //деплоим форвардер-контракт
        const forwarderName = "accountForwarder"
        const forwarder_Factory = await ethers.getContractFactory("ERC2771Forwarder");
        const forwarder = await forwarder_Factory.deploy(forwarderName);
        await forwarder.waitForDeployment();        
        

        //деплоим контракт счета
        const accountETH_Factory = await ethers.getContractFactory("ETHAccount2771");
        const accountETH = await accountETH_Factory.deploy("1", forwarder.getAddress());
        await accountETH.waitForDeployment();

        return { user0, user1, user2, forwarder, accountETH }
    }

    describe("deployment tеsts", function() { //примитивный тест на деплой - просто проверить, что общая часть работает
        it("should be deployed", async function() {
            const { forwarder, accountETH } = await loadFixture(deploy); 
            
            //проверим, что к текущему счету прицепится верный trustedForwarder
            expect(await accountETH.trustedForwarder()).eq(await forwarder.getAddress());            
        });
    });
})