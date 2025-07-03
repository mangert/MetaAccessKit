import { network } from "hardhat";
import { loadFixture, ethers, expect  } from "../setup";
import { forwarderName } from "./helpers";

describe("meta ERC2771 tests", function() {
    async function deploy() {        
        const [user0, user1, user2] = await ethers.getSigners();
        
        //деплоим форвардер-контракт        
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

    /**
     const { chainId } = await ethers.provider.getNetwork();

const request: ForwardRequest = {
  from: user.address,
  to: myContract.address,
  value: 0,
  gas: 100000,
  nonce: 0,
  data: myContract.interface.encodeFunctionData("withdraw", [recipient, amount]),
  deadline: Math.floor(Date.now() / 1000) + 3600,
};

const signature = await signMetaTx(
  forwarder.address,
  chainId,
  user,
  request
);

     */
})