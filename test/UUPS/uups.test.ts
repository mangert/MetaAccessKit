import { loadFixture, ethers, expect  } from "../setup";
import { IETHAccount, AccountBoxV1, AccountBoxV2 } from "../../typechain-types";
import { signMetaTx } from "../meta/helpers"; 
import { upgrades } from "hardhat";

describe("UUPS-upgradable tests", function() {
    async function deploy() {        
        const [user0, user1, user2] = await ethers.getSigners();
        
        //деплоим форвардер-контракт - чтобы был (используется при создании фабрики)       
        const forwarderName = "ERC2771Forwarder"
        const forwarder_Factory = await ethers.getContractFactory("ERC2771Forwarder");
        const forwarder = await forwarder_Factory.deploy(forwarderName);
        await forwarder.waitForDeployment();    
        
        //деплоим контракт фабрики через прокси
        const forwarderAddr = await forwarder.getAddress();        
        const Box = await ethers.getContractFactory("AccountBoxV1");
        const proxyBox = await upgrades.deployProxy(Box, [forwarderAddr, user0.address], {
        kind: "uups",
        });
        await proxyBox.waitForDeployment();
        
        return {user0, user1, user2, forwarder, proxyBox};
       
    }

    describe("deployment tеsts", function() { //примитивный тест на деплой - просто проверить, что общая часть работает
        it("should be deployed", async function() {
            const { user0, user1, forwarder, proxyBox} = await loadFixture(deploy);            

            const implAddr = await proxyBox.implementation(); //получаем адрес задеплоенный шаблон контракта-счета            
            const impl = await ethers.getContractAt("ETHAccountV2", implAddr); //сделаем из него контракт

            const forwarderAddress = await impl.trustedForwarder(); //посмотрим, с каким форвардером нам фабрика записала шаблон           
            expect(forwarderAddress).to.equal(forwarder.target);  //и убедимся, что с верным      

        });
    });

    describe("upgrade tests", function() { //тесты на обновляемость
        it("should create clones before upgrade factory ", async function() {//тест проверяет, что через обновляемую фабирку клон создается, умеет выполнять транзакции и записывается в хранилище
            
            const { user0, user1, proxyBox} = await loadFixture(deploy); 

            //для начала запустим создание аккаунта на первой версии фабрики
            //сначала сделаем симуляцию и получим адрес контракта-клона для юзера0
            const predictedClone0 = proxyBox.getFunction("createClone");
            const clone0Addr0 = (await predictedClone0.staticCallResult())[0]; //получаем возвращаемое значение - адрес нового акканута            
            
            //а теперь запустим транзакцию
            const tx0 = await proxyBox.createClone();
            await tx0.wait(1);
            
            //получим адрес созданного клона из хранилища accountBox
            const account0Address = await proxyBox.getAccountByIndex(user0, 0);
            
            //теперь получим контракт-аккаунт из адреса
            const account0 = await ethers.getContractAt("ETHAccountV2", account0Address);
            const accountID = await account0.accountID(); //и узнаем id аккаунта
            
            //и проверим, что наша транзакция правильное событие эмитировала
            await expect(tx0).to.emit(proxyBox, "AccountCreated").withArgs(user0, accountID, account0Address);
            
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
        
        it("should upgrade accountBox", async function() { //тест проверяет, что мы можем обновить фабрику и она нормально сохранит данные, сохранившиеся с первой версии
            
            const { user1, proxyBox} = await loadFixture(deploy); 
            //запомним адрес, с которым у нас задеплоилась сама имплементация фабрики
            const implAddressBeforeUp = await upgrades.erc1967.getImplementationAddress(await proxyBox.getAddress());           
                       
            //создадим для юзера1 счет и забросим на него деньги
            const tx1 = await proxyBox.connect(user1).createClone();
            await tx1.wait(1);                 
            
            const accountAddr0 = await proxyBox.getAccountByIndex(user1, 0);
            const account0 = await ethers.getContractAt("ETHAccountV2", accountAddr0);
            const accountID = await account0.accountID(); //получим ID, чтобы было, с чем сравнить
                        
            const amount = 1000n;
            const dep = await account0.deposit({value: amount});            
            
            //А теперь обновим фабрику
            const BoxV2 = await ethers.getContractFactory("AccountBoxV2");
            const proxyBoxV2 = await upgrades.upgradeProxy(proxyBox, BoxV2);
            //новый адрес реализации
            const implAddressAfterUp = await upgrades.erc1967.getImplementationAddress(await proxyBox.getAddress());           

            //а теперь попоробуем получить из новой фабрики адрес аккаунта, сделанный на первой версии
            const account0AddrV2 = await proxyBoxV2.getAccountById(user1, accountID); //вызываем функцию, которой не было в версии 1      
            //и проверим его баланс
            const balance = await ethers.provider.getBalance(account0AddrV2);  
            expect(balance).eq(amount);
            
            //проверим, что у нас с адресами 
            expect(implAddressAfterUp).not.eq(implAddressBeforeUp); //адреса реализаций не должны совпадать
            expect(proxyBoxV2).eq(proxyBox); //а адрес прокси наоборот, не должен измениться            
                     
        });

        it("should revert unauthorized upgrade", async function() { //тест проверяет, что мы не можем обновить фабрику от левого адреса
            
            const {user0, user1, proxyBox, forwarder} = await loadFixture(deploy);             
            
            //Пробуем обновить фабрику с постороннего аккаунта
            const newImpl = await ethers.deployContract("AccountBoxV2"); //задеплоим реализацию
            const newImplAddress = await newImpl.getAddress(); //возьмем адрес реализации

            //соберем данные для вызова функции инициализации
            const iface = new ethers.Interface([
                "function initialize(address trustedForwarder, address initialOwner)"
            ]); //сигнатура
            const data = iface.encodeFunctionData("initialize", [
                await forwarder.getAddress(),  // адрес форвардера
                user0.address      // правильный владелец
            ]); //запаковываем в нужный формат

            //и ожидаем, что вызов upgradeToAndCall отвалится
            await expect(
                proxyBox.connect(user1).upgradeToAndCall(newImplAddress, data)
                ).to.be.revertedWithCustomError(proxyBox, "OwnableUnauthorizedAccount");
                     
        });
        //smoke-тест для проверки работоспособности клонов с метатранзакциями после обновления фабрики
        it("should allow meta-withdraw via forwarder", async function () { 
            
            const { user0, user1, forwarder, proxyBox } = await loadFixture(deploy);

            const BoxV2 = await ethers.getContractFactory("AccountBoxV2");
            const proxyBoxV2 = await upgrades.upgradeProxy(proxyBox, BoxV2);

            // создаём аккаунт
            await proxyBoxV2.connect(user0).createClone();
            const accAddr = await proxyBoxV2.getAccountByIndex(user0, 0);
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