//Вспомогательные интерфейсы и функции для тестирования функционала meta- транзакций
import { SignerWithAddress, TypedDataSigner } from "../setup";

export const forwarderName = "ERC2771Forwarder"; //имя для деплоя форвардера

//структура для сообщения-запроса на выполнение
export interface ForwardRequest {
  from: string; //адрес, подписавший транзакцию
  to: string; //целевой контракт
  value: number | bigint; //деньги
  gas: number; //лимит газа  
  deadline: number; //срок действия запроса на выполнение
  data: string; //сигнатура вызываемой функции + параметр
}

/**
 * Получает и подписывает EIP-712 мета-транзакцию
 */
export async function signMetaTx(
  forwarderAddress: string,
  chainId: number,
  signer: SignerWithAddress,
  userNonce: BigInt,
  request: ForwardRequest
) { 

  const domain = {
    name: forwarderName,
    version: "1",
    chainId,
    verifyingContract: forwarderAddress,
  };

  const types = { //описание структуры для подписи 
    ForwardRequest: [
      { name: "from", type: "address" },
      { name: "to", type: "address" },
      { name: "value", type: "uint256" },
      { name: "gas", type: "uint256" },
      { name: "nonce", type: "uint256" }, 
      { name: "deadline", type: "uint48" },
      { name: "data", type: "bytes" }
    ]
  };

  const requestToSign = { //формируем структуру данных для подписания 
    ...request,
    nonce: userNonce //добавляем к полям запроса поле "nonce"
  };

  const signature = await signer.signTypedData(domain, types, requestToSign); //подписываем сообщение

  return signature;
}