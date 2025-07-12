import { loadFixture, ethers, expect  } from "../setup";
import { IETHAccount, AccountBox } from "../../typechain-types";
import { signMetaTx } from "../meta/helpers"; 

describe("Clone factory tests", function() {
    async function deploy() {        
        const [user0, user1, user2] = await ethers.getSigners();
        
        //деплоим форвардер-контракт - чтобы был (используется при создании фабрики)       
        const forwarderName = "ERC2771Forwarder"
        const forwarder_Factory = await ethers.getContractFactory("ERC2771Forwarder");
        const forwarder = await forwarder_Factory.deploy(forwarderName);
        await forwarder.waitForDeployment();    
        //деплоим контракт фабрики
        
        const accountBox = (await ethers.deployContract("AccountBox", [forwarder])) as AccountBox;
        
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

    describe("clone tests", function() { //тесты создания клонов
        it("should create clones", async function() {//тест проверяет, что клон создается, умеет выполнять транзакции и записывается в хранилище
            
            const { user0, user1, accountBox} = await loadFixture(deploy); 

            //сначала сделаем симуляцию и получим адрес контракта-клона для юзера0
            const predictedClone0 = accountBox.getFunction("createClone");
            const clone0Addr0 = (await predictedClone0.staticCallResult())[0]; //получаем возвращаемое значение - адрес нового акканута            
            
            //а теперь запустим транзакцию
            const tx0 = await accountBox.createClone();
            await tx0.wait(1);
            
            //получим адрес созданного клона из хранилища accountBox
            const account0Address = await accountBox.getAccountByIndex(user0, 0);

            //проверим на всякий случай, что адреса совпали
            expect(clone0Addr0).eq(account0Address);            
            
            //теперь получим контракт-аккаунт из адреса
            const account0 = await ethers.getContractAt("ETHAccountV2", account0Address);
            const accountID = await account0.accountID(); //и узнаем id аккаунта
            
            //и проверим, что наша транзакция правильное событие эмитировала
            await expect(tx0).to.emit(accountBox, "AccountCreated").withArgs(user0, accountID, account0Address);
            
            //проверим, сможем ли мы работать с нашим вновь созданным аккаунтом
            //сначала закинем деньги
            const txDeposit = await account0.deposit({value: 100n});
            txDeposit.wait(1);
            await expect(txDeposit).changeEtherBalance(account0Address, 100n);

            //и попробуем вывести половину обратно
            const txWithdraw = await account0.connect(user0).withdraw(user0, 50n);
            txWithdraw.wait(1);
            await expect(txWithdraw).changeEtherBalances([account0Address, user0], [-50n, 50n]);            
        });

        it("should create several clones", async function() { //тест проверяет, что мы можем несколько клонов создавать для разных юзеров
            
            const { user0, user1, user2, accountBox, forwarder} = await loadFixture(deploy); 

            const users = [user0, user1, user2]; //запихнула в массив, чтобы циклы можно было крутить            
            
            //создадим для каждого юзера по 2 счета
            for(let i=0; i!=3; ++i) {                
                
                const tx1 = await accountBox.connect(users[i]).createClone();
                await tx1.wait(1);                 
                
                const tx2 = await accountBox.connect(users[2 - i]).createClone();
                await tx2.wait(1);                                 
            }
            //проверим для каждого юзера создались 2 аккаунта, с нужным trustedForwarder и непустым ID
            for(let i=0; i != 3; ++i) {                                
                
                const counter = await accountBox.userCounters(users[i]); //сначала посмотрим счетчик
                expect(counter).eq(2); //и проверим, что их 2
                
                for(let j = 0; j != 2; ++j) { //теперь для каждого счета
                    //получим контракт кошелька
                    const address = await accountBox.getAccountByIndex(users[i], j);
                    const account = (await ethers.getContractAt("ETHAccountV2", address));                                
                    //и проверим...
                    expect(await account.trustedForwarder()).eq(await forwarder.target); //что форвардер тот, с которым деплоили фабрику
                    expect(await account.accountID()).not.eq(""); //и идентификатор не пустой (какой - не знаем, но это не суть важно)
                }                
            }          
        });

        it("should allow meta-withdraw via forwarder", async function () { //smoke-тест для проверки работоспособности клонов с метатранзакциями
            
            const { user0, user1, forwarder, accountBox } = await loadFixture(deploy);

            // создаём аккаунт
            await accountBox.connect(user0).createClone();
            const accAddr = await accountBox.getAccountByIndex(user0, 0);
            const account = await ethers.getContractAt("ETHAccountV2", accAddr);

            // депонируем немного средств
            await account.deposit({ value: 1_000_000n });

            // собираем metaTx с помощью helper-функции signMetaTx (забрали из тестов-мета-транзакций)            
            const amount = 500_000n;
            const deadline = Math.floor(Date.now() / 1000) + 3600;
            const data = account.interface.encodeFunctionData("withdraw", [user1.address, amount]);
            const request = { from: user0.address, to: accAddr, value: 0, gas: 100_000, deadline, data };

            const nonce = await forwarder.nonces(user0); //получаем nonce подписанта
            const {chainId}  = await ethers.provider.getNetwork(); //идентификатор чейна
            
            const signature = await signMetaTx( //подписываем запрос
                await forwarder.getAddress(),
                Number(chainId),
                user0,
                nonce,              
                request               
            );
            const fullRequest = { ...request, signature }; //объединяем запрос с подписью

            const tx = await forwarder.connect(user1).execute(fullRequest); //запускаем транзу от user1
            await expect(tx).to.changeEtherBalances([accAddr, user1.address], [-amount, amount]);
            });
    });

});