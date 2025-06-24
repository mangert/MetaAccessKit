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

function splitSignatureToRSV(signature: string): RSV {
    
    const r = '0x' + signature.substring(2).substring(0, 64);
    const s = '0x' + signature.substring(2).substring(64, 128);
    const v = parseInt(signature.substring(2).substring(128, 130), 16);

    return {r, s, v};
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
            const mint = await ame_Token.mint(user0, 100n);
                
            


            const tokenAddress = await ame_Token.getAddress();
            const owner = user0.address;
            const spender = user1.address;
            const amount = 15;
            const deadline = Math.floor(Date.now() / 1000) + 1000;
            const nonce = 0;

            const result = await signERC2612Permit(
                tokenAddress, 
                owner, 
                spender,
                amount,
                deadline,
                nonce,
                user0
            );
            console.log(result);
            
            const tx = await proxy.connect(user1).doSend(
                tokenAddress, 
                owner, 
                spender,
                amount,
                deadline,                
                result.v,
                result.r,
                result.s
            );
            await tx.wait(1);

            console.log("NONCES ", await ame_Token.nonces(user0));
            console.log("ALLOWANCE BEFORE", await ame_Token.allowance(owner, spender));

            const transferTx = await ame_Token.connect(user1).transferFrom(owner, spender, 10n);
            await transferTx.wait(1);

            await expect(transferTx).to.changeTokenBalance(ame_Token, user1, 10);
            console.log("ALLOWANCE AFTER", await ame_Token.allowance(owner, spender));



        })    
        
    });
})