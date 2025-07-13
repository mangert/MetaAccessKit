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

<details>
<summary><strong>contracts/</strong> — исходные контракты

├── commonInterfaces
│ └── IETHAccount.sol # Интерфейс контракта-счета
│
├── erc20 # ERC20 токен с Permit и контролем доступа
│ ├── AmetistToken.sol # Основной токен (0x9758...)
│ ├── AccessControl.sol # Контроль ролей
│ ├── ERC20Permit.sol # Permit (EIP-2612)
│ ├── IAccessControl.sol
│ └── IERC20Permit.sol
│
├── factory # Простая фабрика клонов
│ ├── AccountBox.sol # Фабрика (0xb7A2...)
│ └── ETHAccountV2.sol # Шаблон счёта (0x9030...)
│
├── libs
│ └── IDGenerator.sol # Хеширование ID аккаунта
│
├── meta # Meta-транзакции (ERC2771)
│ ├── ERC2771Context.sol
│ ├── ERC2771Forwarder.sol # Форвардер (0xd8A7...)
│ └── ETHAccountV1.sol # Счет с поддержкой мета-транзакций (0x36Ff...)
│
├── test-helpers
│ └── ERC20Proxy.sol # Хелпер для Permit-тестов
│
└── UUPS # UUPS-фабрика с поддержкой апгрейдов
# Прокси фабрики: 0x4bb6...
# Шаблон счёта: 0x1328...
├── AccountBoxV1.sol # V1 (0xb3f5...)
└── AccountBoxV2.sol # V2 (0x9bc4...)
</summary>

<summary><strong>test/</strong> — тесты на Hardhat + Chai</summary>
</details>

├── setup.ts # Общая фикстура
├── erc20
│ ├── AmetistToken.test.ts
│ └── helpers.ts
├── factory
│ └── Factory.test.ts
├── meta
│ ├── meta.test.ts
│ └── helpers.ts
└── UUPS
└── uups.test.ts
<details>

<summary><strong>scripts/</strong> — скрипты деплоя и верификации</summary>
</details>

├── deployERC20.ts # Деплой токена с Permit
├── deployMeta.ts # Деплой счёта + форвардера
├── deployFactory.ts # Деплой обычной фабрики (AccountBox)
├── deployUUPS.ts # Деплой UUPS-прокси фабрики с апгрейдом
└── logs
├── addresses.json # Текущие адреса (форвардер и т.д.)
└── deploy-log.txt # Адреса всех деплоев (не коммитится)

<details>

</details>

---

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






