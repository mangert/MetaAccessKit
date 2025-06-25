//Вспомогательные интерфейсы и функции для тестирования функционала  permit
import { SignerWithAddress } from "../setup";

export const tokenName = "Ametist"; //константа для имени токена

//тип для сообщения permit
interface ERC2612PermitMessage {
    owner: string;
    spender: string;
    value: number | string;
    nonce: number | string;
    deadline: number | string;
}

//тип для компонентов подписи
interface RSV {
    r: string;
    s: string;
    v: number;
}

//тип для домена
interface Domain {
    name: string,
    version: string,
    chainId: number;
    verifyingContract: string;
}

//вспомогательные функции
//формирует структуру сообщения по стандарту EIP-712 для функции permit (ERC2612)
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

//функция, разбивающия подпись на компоненты
function splitSignatureToRSV(signature: string): RSV {
    
    const r = '0x' + signature.substring(2).substring(0, 64);
    const s = '0x' + signature.substring(2).substring(64, 128);
    const v = parseInt(signature.substring(2).substring(128, 130), 16);

    return {r, s, v};
}

//формирует и подписывает permit-сообщение по ERC2612 (для тестов)
//возвращает подпись (r, s, v) + параметры permit (message)
export async function signERC2612Permit(
    tokenAddress: string, 
    owner: string,
    spender: string,
    value: string | number,
    deadline: number,
    nonce: number,
    signer: SignerWithAddress                
): Promise<ERC2612PermitMessage & RSV> { 
    
    const message: ERC2612PermitMessage = { //формируем "содержание" сообщения
        owner,
        spender,
        value,
        nonce,
        deadline,
    };

    const domain: Domain =  { //формируем "домен" по стандарту 
        name : tokenName,
        version: "1",
        chainId: 1337,
        verifyingContract: tokenAddress
    };

    const typedData = createTypedERC2612Data(message, domain); //формируем "структурированное" по стандарту сообщение
    
    const rawSignature = await signer.signTypedData( 
        typedData.domain,
        typedData.types,
        typedData.message
    ); //формируем подпись сообщения
    
    const sig = splitSignatureToRSV(rawSignature); //разбиваем подпись на компоненты
    
    return {...sig, ...message};    
}