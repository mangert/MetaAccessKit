//Вспомогательные интерфейсы и функции для тестирования функционала meta- транзакций
import { SignerWithAddress } from "../setup";
import { TypedDataDomain, TypedDataSigner } from "@ethersproject/abstract-signer"; 

export const forwarderName = "accountForwarder"; //имя для деплоя форвардера


//структура для сообщения-запроса на выполнение
export interface ForwardRequest {
  from: string;
  to: string;
  value: number | bigint;
  gas: number;
  nonce: number;
  data: string;
  deadline: number;
} 

/**
 * Формирует и подписывает EIP-712 мета-транзакцию
 */
export async function signMetaTx(
  forwarderAddress: string,
  chainId: number,
  signer: SignerWithAddress & TypedDataSigner,
  request: ForwardRequest
) {
  const domain: TypedDataDomain = {
    name: forwarderName,
    version: "1",
    chainId,
    verifyingContract: forwarderAddress,
  };

  const types = {
    ForwardRequest: [
      { name: "from", type: "address" },
      { name: "to", type: "address" },
      { name: "value", type: "uint256" },
      { name: "gas", type: "uint256" },
      { name: "nonce", type: "uint256" },
      { name: "data", type: "bytes" },
      { name: "deadline", type: "uint48" },
    ],
  };

  const signature = await signer._signTypedData(domain, types, request);

  return signature;
}



