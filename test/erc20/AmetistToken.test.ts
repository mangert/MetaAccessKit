import { version } from "hardhat";
import { loadFixture, ethers, expect, SignerWithAddress } from "../setup";

const tokenName = "Ametist";

interface ERC2612PermitMessage {
    owner: string;
    spender: string;
    value: number | string;
    nonce: number | string;
    deadline: number | string;
}

interface RSV {
    r: string;
    s: string;
    v: number;
}

interface Domain {
    name: string,
    version: string,
    chainId: number;
    verifyingContract: string;
}

function createTypedERC2612Data(message: ERC2612PermitMessage, domain: Domain){
    return{
        types: {
            Permit: [
                { name: "owner", type: "address"},
                { name: "spender", type: "address"},
                { name: "value", type: "uint256"},
                { name: "nonce", type: "uint256"},
                { name: "deadline", type: "uint256"},
            ]
        },
        primaryType: "Permit",
        domain,
        message,
    }
}

async function signERC2612Permit(
    tokenAddress: string, 
    owner: string,
    spender: string,
    value: string | number,
    deadline: number,
    nonce: number,
    signer: SignerWithAddress                
): Promise<ERC2612PermitMessage & RSV> {
    
    const message: ERC2612PermitMessage = {
        owner,
        spender,
        value,
        nonce,
        deadline,
    };

    const domain: Domain =  {
        name : tokenName,
        version: "1",
        chainId: 1337,
        verifyingContract: tokenAddress
    };

    const typedData = createTypedERC2612Data(message, domain);
    console.log(typedData);
    const rawSignature = await signer.signTypedData(
        typedData.domain,
        typedData.types,
        typedData.message
    );
    const sig = splitSignatureToRSV(rawSignature);
    
    return {...sig, ...message};
    
    }


describe("AmetistToken", function() {
    async function deploy() {        
        const [user0, user1, user2] = await ethers.getSigners();
        
        //деплоим контракт токена
        const ame_Factory = await ethers.getContractFactory("AmetistToken");
        const ame_Token = await ame_Factory.deploy();
        await ame_Token.waitForDeployment();        

        //деплоим контракт прокси
        const proxy_Factory = await ethers.getContractFactory("ERC20Proxy");
        const proxy = await proxy_Factory.deploy();
        await proxy.waitForDeployment();


        return { user0, user1, user2, ame_Token, proxy }
    }


    describe("deployment tеsts", function() {
        it("should be deployed", async function() {
            const { ame_Token } = await loadFixture(deploy);        
            
            expect(ame_Token.target).to.be.properAddress;        
            expect(await ame_Token.name()).eq(tokenName);
            expect(await ame_Token.symbol()).eq("AME");    
        });
    });
    
    describe("permit tеsts", function() {
        it("should permit", async function(){
            
            const {user0, user1, ame_Token, proxy} = await loadFixture(deploy);
            const tokenAddress = ame_Token.address;
            const owner = user0.address;
            const spender = user1.address;
            const amount = 15n;
            const deadline = Math.floor(Date.now() / 1000) + 1000;
            const nonce = 0;

            const result = signERC2612Permit(
                tokenAddress, 
                owner, 
                spender,
                amount,
                deadline,
                user0
            );







        })    
        
    });
})