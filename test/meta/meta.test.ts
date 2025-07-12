import { network } from "hardhat";
import { loadFixture, ethers, expect  } from "../setup";
import { forwarderName, ForwardRequest, signMetaTx } from "./helpers";

describe("meta ERC2771 tests", function() {
    async function deploy() {        
        const [user0, user1, user2] = await ethers.getSigners();
        
        //деплоим форвардер-контракт        
        const forwarder_Factory = await ethers.getContractFactory("ERC2771Forwarder");
        const forwarder = await forwarder_Factory.deploy(forwarderName);
        await forwarder.waitForDeployment();        
        

        //деплоим контракт счета
        const accountETH_Factory = await ethers.getContractFactory("ETHAccountV1");
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

    describe("contract functions simple tests", function() { //тест функций контракта без мета-транзакций
        it("should deposit and withdraw", async function() {
            const {user0, accountETH } = await loadFixture(deploy);
            const amount = 100_000_000_000n;

            const txDeposit = await accountETH.deposit({value: amount});
            txDeposit.wait(1);

            const txWithdraw = await accountETH.withdraw(user0.address, amount);
            txWithdraw.wait(1);

            await expect(txDeposit).changeEtherBalance(user0, -amount);
            await expect(txDeposit).changeEtherBalance(accountETH, amount);
            await expect(txWithdraw).changeEtherBalance(user0, amount);
            await expect(txWithdraw).changeEtherBalance(accountETH, -amount);
            
        });

        it("should revert withdraw", async function() { //тест проверки реверта функции вывода
            const {user0, user1, accountETH } = await loadFixture(deploy);
            const amount = 100_000_000_000n;

            //сначала забросим деньги
            const txDeposit = await accountETH.deposit({value: amount});
            txDeposit.wait(1);

            //пробуем вывести слишком большую сумму
            const balance = ethers.provider.getBalance(accountETH.target); 
            const txWithdrawTooMuch = accountETH.withdraw(user0.address, amount * 2n); 
            await expect(txWithdrawTooMuch).revertedWithCustomError(accountETH, "InsufficientFunds")
              .withArgs(amount * 2n, balance);           

            //пробуем вывести от постороннего кошелька
            const txWithdrawUnAuth = accountETH.connect(user1).withdraw(user0.address, amount); 
            await expect(txWithdrawUnAuth).revertedWithCustomError(accountETH, "UnauthorizedAccount")
              .withArgs(user1);           
        });
    });

    describe("meta transaction tests", function() { //тестируем работу мета-транзакций
      
      it("should meta-withdraw works", async function() {
        
        const {user0, user1, user2, forwarder, accountETH } = await loadFixture(deploy);             
        const {chainId}  = await ethers.provider.getNetwork(); 

        //сначала забросим деньги
        const amount = 100_000_000_000n;    
        const txDeposit = await accountETH.deposit({value: amount});
        txDeposit.wait(1);
        
        //подготавливаем данные для транзакции
        const owner = user0.address; 
        const relayer = user1; //просто для удобства
        const recipient = user2.address; //отправлять будем на адрес user2
        const targetContract = await accountETH.getAddress();
        const forwarderAddress = await forwarder.getAddress();

        const request: ForwardRequest = { //формируем запрос
              from: owner,
              to: targetContract,
              value: 0,
              gas: 100000,              
              deadline: Math.floor(Date.now() / 1000) + 3600,
              //"заворачиваем" функцию с аргументами через функцию encodeFunctionData, чтобы правильно упаковалось
              data: accountETH.interface.encodeFunctionData("withdraw", [recipient, amount]),              
        };        

        const nonce = await forwarder.nonces(owner); //получаем nonce подписанта

        //подписываем запрос
        const signature = await signMetaTx(
              forwarderAddress,
              Number(chainId),
              user0,
              nonce,              
              request
        );        

        const requestWithSignature = { //собираем в кучу запрос с подписью
          ...request,
          signature,
        };                       
        
        //запускаем транзакцию от user2 (relayer) через функцию execute форвардера
        const metaTx = await forwarder.connect(relayer).execute(requestWithSignature);
        //проверям событие и как изменились балансы
        expect(metaTx).to.emit(forwarder, "ExecutedForwardRequest").withArgs(user0, 0, true);
        expect(metaTx).changeEtherBalances([accountETH, user0, user1, user2], [-amount, 0, 0, amount]);

      });

      it("should revert meta-withdraw with not owner", async function() {
        
        const {user0, user1, user2, forwarder, accountETH } = await loadFixture(deploy);             
        const {chainId}  = await ethers.provider.getNetwork();

        //сначала забросим деньги
        const amount = 100_000_000_000n;    
        const txDeposit = await accountETH.deposit({value: amount});
        txDeposit.wait(1);
        
        //подготавливаем данные для транзакции
        const owner = user0.address; 
        const relayer = user1; //просто для удобства
        const recipient = user2.address; //отправлять будем на адрес user2
        const targetContract = await accountETH.getAddress();
        const forwarderAddress = await forwarder.getAddress();

        const request: ForwardRequest = { //формируем запрос
              from: owner,
              to: targetContract,
              value: 0,
              gas: 100000,              
              deadline: Math.floor(Date.now() / 1000) + 3600,
              data: accountETH.interface.encodeFunctionData("withdraw", [recipient, amount]),              
        };        

        const nonce = await forwarder.nonces(owner); //получаем nonce подписанта

        //подписываем запрос
        const signature = await signMetaTx(
              forwarderAddress,
              Number(chainId),
              user2, //заменим подписанта
              nonce,              
              request
        );        

        const requestWithSignature = { //собираем в кучу запрос с подписью
          ...request,
          signature,
        };                       
        
        //формируем транзакцию с некорректной подписью (пока не отправляем - отвалится)
        const badSignerTx = forwarder.connect(relayer).execute(requestWithSignature);
        //отправляем и проверяем, с какой ошибкой отвалилась
        await expect(badSignerTx).revertedWithCustomError(forwarder, "ERC2771ForwarderInvalidSigner")
          .withArgs(user2, user0);

      });

      it("should revert meta-withdraw with expired time", async function() {
        
        const {user0, user1, user2, forwarder, accountETH } = await loadFixture(deploy);             
        const {chainId}  = await ethers.provider.getNetwork();

        //сначала забросим деньги
        const amount = 100_000_000_000n;    
        const txDeposit = await accountETH.deposit({value: amount});
        txDeposit.wait(1);
        
        //подготавливаем данные для транзакции
        const owner = user0.address; 
        const relayer = user1; //просто для удобства
        const recipient = user2.address; //отправлять будем на адрес user2
        const targetContract = await accountETH.getAddress();
        const forwarderAddress = await forwarder.getAddress();

        const request: ForwardRequest = { //формируем запрос
              from: owner,
              to: targetContract,
              value: 0,
              gas: 100000,              
              deadline: Math.floor(Date.now() / 1000) + 3600,
              data: accountETH.interface.encodeFunctionData("withdraw", [recipient, amount]),              
        };        

        const nonce = await forwarder.nonces(owner); //получаем nonce подписанта

        //подписываем запрос
        const signature = await signMetaTx(
              forwarderAddress,
              Number(chainId),
              user0, 
              nonce,              
              request
        );        

        const requestWithSignature = { //собираем в кучу запрос с подписью
          ...request,
          signature,
        };
        
        //пропускаем время
            const now = (await ethers.provider.getBlock("latest"))!.timestamp;
            const timeToAdd = 12 * 60 * 60; // 12 часов
            const futureTime = now + timeToAdd;
            await network.provider.send("evm_setNextBlockTimestamp", [futureTime]);
            await network.provider.send("evm_mine");
        
        //формируем транзакцию за пределами срока действия
        const expiredTimeTx = forwarder.connect(relayer).execute(requestWithSignature);
        
        await expect(expiredTimeTx).revertedWithCustomError(forwarder, "ERC2771ForwarderExpiredRequest")
          .withArgs(request.deadline);

      });

      it("should revert meta-withdraw invalid nonce", async function() {
        
        const {user0, user1, user2, forwarder, accountETH } = await loadFixture(deploy);             
        const {chainId}  = await ethers.provider.getNetwork(); 

        //сначала забросим деньги
        const amount = 100_000_000_000n;    
        const txDeposit = await accountETH.deposit({value: amount});
        txDeposit.wait(1);
        
        //подготавливаем данные для транзакции
        const owner = user0.address; 
        const relayer = user1; //просто для удобства
        const recipient = user2.address; //отправлять будем на адрес user2
        const targetContract = await accountETH.getAddress();
        const forwarderAddress = await forwarder.getAddress();

        const request: ForwardRequest = { //формируем запрос
              from: owner,
              to: targetContract,
              value: 0,
              gas: 100000,              
              deadline: Math.floor(Date.now() / 1000) + 3600,
              data: accountETH.interface.encodeFunctionData("withdraw", [recipient, amount]),              
        };        

        const nonce = await forwarder.nonces(owner); //получаем nonce подписанта

        //подписываем запрос
        const signature = await signMetaTx(
              forwarderAddress,
              Number(chainId),
              user0,
              nonce,              
              request
        );        

        const requestWithSignature = { //собираем в кучу запрос с подписью
          ...request,
          signature,
        };                       
        
        //запускаем транзакцию от user2 (relayer) через функцию execute форвардера
        const metaTx = await forwarder.connect(relayer).execute(requestWithSignature);
        
        //сделаем еще одну точно такую же транзакцию 
        // не будем переподписывать, то есть nonce в подписи будет 0, а в форвадере уже 1        
        const metaTx2 = forwarder.connect(relayer).execute(requestWithSignature);
        //так как nonce неверный, транзакция отвалится с ошибкой подписанта, какие будут параметры - неочевидно, не проверям
        await expect(metaTx2).revertedWithCustomError(forwarder, "ERC2771ForwarderInvalidSigner");       

      });

      it("should revert meta-withdraw with expired time", async function() {
        
        const {user0, user1, user2, forwarder, accountETH } = await loadFixture(deploy);             
        const {chainId}  = await ethers.provider.getNetwork();

        //сначала забросим деньги
        const amount = 100_000_000_000n;    
        const txDeposit = await accountETH.deposit({value: amount});
        txDeposit.wait(1);
        
        //подготавливаем данные для транзакции
        const owner = user0.address; 
        const relayer = user1; //просто для удобства
        const recipient = user2.address; //отправлять будем на адрес user2
        const targetContract = await accountETH.getAddress();
        const forwarderAddress = await forwarder.getAddress();

        const request: ForwardRequest = { //формируем запрос
              from: owner,
              to: targetContract,
              value: 0,
              gas: 100000,              
              deadline: Math.floor(Date.now() / 1000) + 3600,
              data: accountETH.interface.encodeFunctionData("withdraw", [recipient, amount]),              
        };        

        const nonce = await forwarder.nonces(owner); //получаем nonce подписанта

        //подписываем запрос
        const signature = await signMetaTx(
              forwarderAddress,
              Number(chainId),
              user0, 
              nonce,              
              request
        );        

        const requestWithSignature = { //собираем в кучу запрос с подписью
          ...request,
          signature,
        };
        
        //пропускаем время
            const now = (await ethers.provider.getBlock("latest"))!.timestamp;
            const timeToAdd = 12 * 60 * 60; // 12 часов
            const futureTime = now + timeToAdd;
            await network.provider.send("evm_setNextBlockTimestamp", [futureTime]);
            await network.provider.send("evm_mine");
        
        //формируем транзакцию за пределами срока действия
        const expiredTimeTx = forwarder.connect(relayer).execute(requestWithSignature);
        
        await expect(expiredTimeTx).revertedWithCustomError(forwarder, "ERC2771ForwarderExpiredRequest")
          .withArgs(request.deadline);

      });

      it("should revert meta-trans untrusted forwarder", async function() {
        
        const {user0, user1, user2, accountETH } = await loadFixture(deploy);             
        const {chainId}  = await ethers.provider.getNetwork();         

        //передеплоим форвардера и будем от него работать
        const forwarder_Factory = await ethers.getContractFactory("ERC2771Forwarder");
        const forwarderNew = await forwarder_Factory.deploy(forwarderName);
        await forwarderNew.waitForDeployment();        
        
        //подготавливаем данные для транзакции
        const owner = user0.address; 
        const relayer = user1; //просто для удобства
        const recipient = user2.address; //отправлять будем на адрес user2
        const targetContract = await accountETH.getAddress();
        const forwarderAddress = await forwarderNew.getAddress(); //адрес от заново задеплоенного форвардера

        const request: ForwardRequest = { //формируем запрос
              from: owner,
              to: targetContract,
              value: 50, 
              gas: 100000,              
              deadline: Math.floor(Date.now() / 1000) + 3600,
              data: accountETH.interface.encodeFunctionData("deposit",)  
        };        
        
        const nonce = await forwarderNew.nonces(owner); //получаем nonce подписанта

        //подписываем запрос
        const signature = await signMetaTx(
              forwarderAddress,
              Number(chainId),
              user0,
              nonce,              
              request
        );        

        const requestWithSignature = { //собираем в кучу запрос с подписью
          ...request,
          signature,
        };                    
                
        const metaTx = forwarderNew.connect(relayer).execute(requestWithSignature, {value: 50});
        //запускаем транзакцию и ждем, что она отвалится, так как наш forwarderNew в контракте не прописан
        await expect(metaTx).revertedWithCustomError(forwarderNew, "ERC2771UntrustfulTarget")
          .withArgs(accountETH, forwarderNew);       
      });     

    });

})