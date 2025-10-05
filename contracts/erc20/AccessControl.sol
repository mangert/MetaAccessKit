// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { IAccessControl } from "./IAccessControl.sol";

/**
 * @title AccessControl
 * @notice абстрактный контракт для ролевой системы в контракте ERC20
 * @author mangert
 */
abstract contract AccessControl is IAccessControl {

    ///@notice структура для хранения информации о ролях
    struct RoleData {
        mapping (address => bool) members; //адреса
        bytes32 adminRole; //информация об админской роли
    }

    ///@notice роль администратора
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00; //роль администратора

    mapping(bytes32 => RoleData) private _roles; //хранилище информации о ролях    

    modifier onlyRole(bytes32 role) { //модификатор для проверки полномочий на вызов функции
        _checkRole(role);
        _;        
    }

    //функции интерфейса

    /**
     * @notice функция выдает роль на адрес
     * @notice выдавать роль может только аккаунт с административными правами для выдаваемой роли
     * @param role - выдаваемая роль
     * @param account - адрес, которому выдается роль
     */
    function grantRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)){
        _grantRole(role, account);
    }

    /** 
     * @notice функция отзывает у адреса роль 
     * @notice отзывать роль может только аккаунт с административными правами для выдаваемой роли
     * @param role - отзываемая роль
     * @param account - адрес, у которого отзывается роль
     */
    function revokeRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)){
        _revokeRole(role, account);
    }
    
    /**
     * @notice функция возвращает админскую роль для заданной роли
     * @param role - роль, для которой делаем запрос
     * @return bytes32 админская роль
     */
    function getRoleAdmin (bytes32 role) public view returns(bytes32) {
        return _roles[role].adminRole;
    }

    //вспомогательные и служебные функции
    
    /**
     * @notice функция для проверки наличия роли
     * @param role - запрашиваемая роль 
     * @param account - проверяемый адрес
     * @return bool факт наличия (true) или остутсвие (false) соответствующей роли
     */
    function hasRole(bytes32 role, address account) public view virtual returns(bool) {
        return _roles[role].members[account];
    }
    
    /**
     * @notice внутренняя функция для назначения для роли админской роли
     * @param role - роль, для которой назначается админ
     * @param adminRole - назначаемая админская роль
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role); 
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @notice внутренняя функция для выдачи роли
     * функция не содержит проверки на полномочия, то есть может вызываться до назначения всех ролей
     * @param role - выдаваемя роль
     * @param account - аккаунт, на который выдается роль
     */
    function _grantRole(bytes32 role, address account) internal virtual {
        if(!hasRole(role, account)) { //проверка нужна, чтобы корректно порождались события
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, msg.sender);
        }        
    }
    /**
     * @notice внутренняя функция для отзыва роли
     * функция не содержит проверки на полномочия, то есть может вызываться 
     * самим контрактом без выдачи специальных полнломочй
     * @param role - отзываемя роль
     * @param account - аккаунт, у которого отзывается роль
     */
    function _revokeRole(bytes32 role, address account) internal virtual {
        if(hasRole(role, account)) { //проверка нужна, чтобы корректно порождались события
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, msg.sender);
        }        
    }    

    /**
     * @notice функция-обертка для подтверждения наличия роли
     * @param role - требуемая роль
     * @return bool факт наличия (true) или остутсвие (false) соответствующей роли
     */
    function _checkRole(bytes32 role) internal view virtual returns(bool) {
        return _checkRole(role, msg.sender);
    }

    /**
     * @notice функция для подтверждения, что у аккаунта есть соответстующия роль
     * @param role - требуемая роль
     * @param account - проверяемый адрес
     * @return bool факт наличия (true) или остутсвие (false) соответствующей роли
     */
    function _checkRole(bytes32 role, address account) internal view virtual returns(bool) {
        require(hasRole(role, account), UnauthorizedAccount(account, role));
        return true;
    }
}