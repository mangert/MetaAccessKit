import { network } from "hardhat";
import { loadFixture, ethers, expect  } from "../setup";
import { signERC2612Permit, tokenName } from "./helpers";

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

    describe("deployment tеsts", function() { //примитивный тест на деплой - просто проверить, что общая часть работает
        it("should be deployed", async function() {
            const { ame_Token } = await loadFixture(deploy);        
            
            expect(ame_Token.target).to.be.properAddress;        
            expect(await ame_Token.name()).eq(tokenName);
            expect(await ame_Token.symbol()).eq("AME");    
        });
    });
    
    describe("permit tеsts", function() { //блок тестов для тестирования функционала "Permit"
        it("should permit", async function(){
            
            const {user0, user1, ame_Token, proxy} = await loadFixture(deploy);
            const mintTx = await ame_Token.mint(user0, 100n); //наимнтим немного, чтобы было что передавать

            //исходные данные для передачи разрешений
            const tokenAddress = await ame_Token.getAddress(); //сам токен
            const owner = user0.address; //адрес владельца токенов
            const spender = user1.address; //адрес транжиры токенов
            
            const amount = 15; //сумма, которую разрешим потратить
            const deadline = Math.floor(Date.now() / 1000) + 1000; //делдлайн - 1000 секунд
            const nonce = Number((await ame_Token.nonces(owner))); //берем начальный nonce владельца и обрезаем до number (чтобы с BigInt не возиться)

            const result = await signERC2612Permit( //получааем подписанное сообщение
                tokenAddress, 
                owner, 
                spender,
                amount,
                deadline,
                nonce,
                user0
            );            
            
            //отравляем транзацкцию permit на выдачу разрешения от user1 через стронний proxy-контракт
            //(прокси-контракт через doSend вызывает функцию permit)
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
            //проверяем, что получилось после permit approve
            await expect(tx).to.emit(ame_Token, "Approval").withArgs(owner, spender, amount)
            expect(await ame_Token.nonces(user0)).eq(1);
            expect(await ame_Token.allowance(owner, spender)).eq(amount);            
            
            //пробуем истратить токены user0 (owner) от имени user1 (spender)
            const spentAmount = 10;
            const transferTx = await ame_Token.connect(user1).transferFrom(owner, spender, spentAmount);
            await transferTx.wait(1);
            //смотрим, что получилось после перевода
            await expect(transferTx).to.changeTokenBalance(ame_Token, user1, spentAmount);
            await expect(transferTx).to.changeTokenBalance(ame_Token, user0, -spentAmount);
            expect(await ame_Token.allowance(owner, spender)).eq(amount-spentAmount);

        })    

        it("should revert permit expired time", async function(){
        const {user0, user1, ame_Token } = await loadFixture(deploy);
            const mintTx = await ame_Token.mint(user0, 100n); //наимнтим немного, чтобы было что передавать

            //исходные данные для передачи разрешений
            const tokenAddress = await ame_Token.getAddress(); //сам токен
            const owner = user0.address; //адрес владельца токенов
            const spender = user1.address; //адрес транжиры токенов
            
            const amount = 15; //сумма, которую разрешим потратить
            const deadline = Math.floor(Date.now() / 1000) + 1000; //делдлайн - 1000 секунд
            const nonce = Number((await ame_Token.nonces(owner))); //берем начальный nonce владельца и обрезаем до number (чтобы с BigInt не возиться)

            const result = await signERC2612Permit( //получааем подписанное сообщение
                tokenAddress, 
                owner, 
                spender,
                amount,
                deadline,
                nonce,
                user0
            );            

            //пропускаем время
            const now = (await ethers.provider.getBlock("latest"))!.timestamp;
            const timeToAdd = 12 * 60 * 60; // 12 часов
            const futureTime = now + timeToAdd;
            await network.provider.send("evm_setNextBlockTimestamp", [futureTime]);
            await network.provider.send("evm_mine");
            
            //формируем транзакцию permit на выдачу разрешения от user1 (promise, пока не отравляем)
            const tx = ame_Token.connect(user1).permit(                
                owner, 
                spender,
                amount,
                deadline,                
                result.v,
                result.r,
                result.s
            );            
            await expect(tx).revertedWithCustomError(ame_Token, "ERC2612ExpiredSignature").withArgs(deadline);        
        });

        it("should revert permit not an owner", async function(){
        const {user0, user1, user2, ame_Token} = await loadFixture(deploy);
            const mintTx = await ame_Token.mint(user0, 100n); //наимнтим немного, чтобы было что передавать

            //исходные данные для передачи разрешений
            const tokenAddress = await ame_Token.getAddress(); //сам токен
            const owner = user2.address; //адрес владельца токенов
            const spender = user1.address; //адрес транжиры токенов
            const signer = user0; //aдрес, подписывающий транзу 
            
            const amount = 15; //сумма, которую разрешим потратить
            const deadline = Math.floor(Date.now() / 1000) + 1000; //делдлайн - 1000 секунд
            const nonce = Number((await ame_Token.nonces(owner))); //берем начальный nonce владельца и обрезаем до number (чтобы с BigInt не возиться)

            const result = await signERC2612Permit( //получааем подписанное сообщение
                tokenAddress, 
                owner, 
                spender,
                amount,
                deadline,
                nonce,
                signer
            );                        
            
            //формируем  транзакцию permit на выдачу разрешения от user1 
            //потратить токены user2 с подписью от user0 (signer) (promise, пока не отравляем)
            const tx = ame_Token.connect(user1).permit(                
                owner, 
                spender,
                amount,
                deadline,                
                result.v,
                result.r,
                result.s
            );                   

            await expect(tx).revertedWithCustomError(ame_Token, "ERC2612InvalidSigner").withArgs(signer, user2);
        });

        it("should revert permit with invalid nonce", async function(){
        const {user0, user1, user2, ame_Token} = await loadFixture(deploy);
            const mintTx = await ame_Token.mint(user0, 100n); //наимнтим немного, чтобы было что передавать

            //исходные данные для передачи разрешений
            const tokenAddress = await ame_Token.getAddress(); //сам токен
            const owner = user0.address; //адрес владельца токенов
            const spender = user1.address; //адрес транжиры токенов
            const signer = user0; //aдрес, подписывающий транзу 
            
            const amount = 15; //сумма, которую разрешим потратить
            const deadline = Math.floor(Date.now() / 1000) + 1000; //делдлайн - 1000 секунд
            const nonce = Number((await ame_Token.nonces(owner))); //берем начальный nonce владельца и обрезаем до number (чтобы с BigInt не возиться)

            const result = await signERC2612Permit( //получааем подписанное сообщение
                tokenAddress, 
                owner, 
                spender,
                amount,
                deadline,
                nonce,
                signer
            );                        
            
            //формируем и запускаем транзакцию permit на выдачу разрешения от user1 
            //потратить токены user2 с подписью от user0 (signer) (корректная транзация, должна пройти)
            const tx = await ame_Token.connect(user1).permit(                
                owner, 
                spender,
                amount,
                deadline,                
                result.v,
                result.r,
                result.s
            );                   

            //формируем точно такую же транзакцию, не переподписывая заново
            //так как nonce некорретный, при запуске отвалится
            const txFailed = ame_Token.connect(user1).permit(                
                owner, 
                spender,
                amount,
                deadline,                
                result.v,
                result.r,
                result.s
            );                 
            //транзакция отвалится, так как signer будет рассчитан от правильного nonce, а не 
            //от того, который зашит в сообщение. Поэтому аргументы не проверишь, signer не совпадет
            await expect(txFailed).revertedWithCustomError(ame_Token, "ERC2612InvalidSigner");
        });
        
    });
})