import { loadFixture, ethers, expect } from "../setup";

describe("AmetistToken", function() {
    async function deploy() {        
        const [user0, user1, user2] = await ethers.getSigners();
        
        const Ame_Factory = await ethers.getContractFactory("AmetistToken");
        const Ame_Token = await Ame_Factory.deploy();
        await Ame_Token.waitForDeployment();        

        return { user0, user1, user2, Ame_Token }
    }

    describe("deployment tеsts", function() {
        it("should be deployed", async function() {
            const { Ame_Token } = await loadFixture(deploy);        
            
            expect(Ame_Token.target).to.be.properAddress;        
            expect(await Ame_Token.name()).eq("Ametist");
            expect(await Ame_Token.symbol()).eq("AME");
    
        });
    
        it("should have 0 eth by default", async function() {
            const { Ame_Token } = await loadFixture(deploy);
    
            const balance = await ethers.provider.getBalance(Ame_Token.target);        
            expect(balance).eq(0);
            
        });     

    });
})