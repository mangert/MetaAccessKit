# MetaAccessKit

**MetaAccessKit** — учебный проект на Solidity, реализующий расширенные возможности аккаунтов и взаимодействий в Ethereum:
- поддержка **meta-транзакций** (через `ERC2771`)
- **клонируемые аккаунты** через фабрику
- **обновляемые (UUPS)** фабрики
- поддержка **ERC20 Permit** (EIP-2612)
- контроль доступа

Проект собран и тестировался в среде [Hardhat](https://hardhat.org/). Все ключевые компоненты протестированы, реализована верификация на Etherscan. Проект разбит по логическим папкам.

---

## 📦 Структура проекта

<pre lang="markdown">
```
contracts/
├── commonInterfaces/
│   └── IETHAccount.sol                  # Интерфейс контракта-счета
│
├── erc20/                               # Токен с Permit и контролем доступа
│   ├── AccessControl.sol
│   ├── AmetistToken.sol                # Основной токен (0x97582ae3f90CC3d35c6c3f1838b0F5b2A79757C9)
│   ├── ERC20Permit.sol
│   ├── IAccessControl.sol
│   └── IERC20Permit.sol
│
├── factory/
│   ├── AccountBox.sol                  # Простая фабрика клонов (0xb7A288e48c3c3B05F209E2d07274A50d8179AF04)
│   └── ETHAccountV2.sol                # Шаблон аккаунта (0x90306DA1df984Fb36AF138BCA13cEA66F4Fe603A)
│
├── libs/
│   └── IDGenerator.sol                 # Библиотека для расчета ID
│
├── meta/
│   ├── ERC2771Context.sol
│   ├── ERC2771Forwarder.sol           # Контракт-форвардер (0xd8A7886Afb35AF66be0bAFC40096c258Ce67d72E)
│   └── ETHAccountV1.sol               # Счет с поддержкой метатранзакций (0x36Ff21969D4E95f6eDafd265f6067D8d57E427b3)
│
├── test-helpers/
│   └── ERC20Proxy.sol                 # Хелпер для тестов permit
│
└── UUPS/                               # Обновляемая фабрика и функционал
    ├── AccountBoxV1.sol               # Фабрика V1 (0xb3f5a086e1929aa29fd4cda520dff82b845d3196)
    └── AccountBoxV2.sol               # Фабрика V2 (0x9bc4640596b43e777bd3ee827ceef1d1bb47cacc)
                                        # Прокси (0x4bb63E544046f128317D3C2e22d81a9575F189bb)
                                        # Шаблон аккаунта (0x1328c658D8b03de5a602D638abE4Cf876217d48b)

test/
├── setup.ts
│
├── erc20/
│   ├── AmetistToken.test.ts
│   └── helpers.ts
│
├── factory/
│   └── Factory.test.ts
│
├── meta/
│   ├── meta.test.ts
│   └── helpers.ts
│
└── UUPS/
    └── uups.test.ts

scripts/
├── deployERC20.ts
├── deployFactory.ts
├── deployMeta.ts
├── deployUUPS.ts

```
</pre>


🔗 Адреса задеплоенных контрактов (Sepolia)
| Компонент                         | Имя контракта      | Адрес на Etherscan                                                                                  |
| --------------------------------- | ------------------ | --------------------------------------------------------------------------------------------------- |
| **ERC20 токен**                   | `AmetistToken`     | [`0x9758...57C9`](https://sepolia.etherscan.io/address/0x97582ae3f90CC3d35c6c3f1838b0F5b2A79757C9)  |
| **Форвардер**                     | `ERC2771Forwarder` | [`0xd8A7...72E`](https://sepolia.etherscan.io/address/0xd8A7886Afb35AF66be0bAFC40096c258Ce67d72E)   |
| **Счет с метатранзакциями**       | `ETHAccountV1`     | [`0x36Ff...27b3`](https://sepolia.etherscan.io/address/0x36Ff21969D4E95f6eDafd265f6067D8d57E427b3)  |
| **Фабрика (простая)**             | `AccountBox`       | [`0xb7A2...AF04`](https://sepolia.etherscan.io/address/0xb7A288e48c3c3B05F209E2d07274A50d8179AF04)  |
| **Шаблон аккаунта (клонируемый)** | `ETHAccountV2`     | [`0x9030...03A`](https://sepolia.etherscan.io/address/0x90306DA1df984Fb36AF138BCA13cEA66F4Fe603A)   |
| **Прокси (UUPS)**                 | `Proxy`            | [`0x4bb6...89bb`](https://sepolia.etherscan.io/address/0x4bb63E544046f128317D3C2e22d81a9575F189bb)  |
| **Фабрика (UUPS V1)**             | `AccountBoxV1`     | [`0xb3f5...3196`](https://sepolia.etherscan.io/address/0xb3f5A086e1929aa29Fd4Cda520dFf82b845D3196)  |
| **Фабрика (UUPS V2)**             | `AccountBoxV2`     | [`0x9bc4...7cacc`](https://sepolia.etherscan.io/address/0x9bc4640596b43e777bd3ee827ceef1d1bb47cacc) |
| **Шаблон аккаунта (UUPS)**        | `ETHAccountV2`     | [`0x1328...748b`](https://sepolia.etherscan.io/address/0x1328c658D8b03de5a602D638abE4Cf876217d48b)  |



## 🛠 Используемые технологии

- [Solidity ^0.8.x](https://docs.soliditylang.org/)
- [Hardhat](https://hardhat.org/)
- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts)
- [Ethers.js](https://docs.ethers.org/)
- [Chai](https://www.chaijs.com/) для тестирования

---

## 🧪 Ключевые возможности

| Раздел            | Описание                                                                 |
|-------------------|--------------------------------------------------------------------------|
| `ERC20Permit`     | Поддержка Permit по EIP-2612, тестирование подписей                      |
| `ERC2771`         | Метатранзакции через кастомный форвардер                                 |
| `Factory`         | Клонирование контрактов и управление ID                                  |
| `UUPS`            | Обновляемая фабрика с сохранением прокси-адреса                          |
| `Верификация`     | Все контракты прошли проверку на [Etherscan Sepolia](https://sepolia.etherscan.io) |

---

## 🧾 Примечания

- Проект **учебный** и служит для демонстрации различных паттернов разработки смарт-контрактов.
- Контракты снабжены тестами, покрытие можно расширять.

---

## 📍 Пример вызова

```bash
npx hardhat run scripts/deployUUPS.ts --network sepolia






