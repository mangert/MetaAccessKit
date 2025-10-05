// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/**
 * @title IAccessControl
 * @author openzeppelin
 * @notice интерфейс для ролевой системы в контракте ERC20
 */

interface IAccessControl {
    
    /**
     * @notice событие сообщающее о выдаче роли
     * @param role - выданная роль
     * @param account - адрес, получивший роль
     * @param sender - адрес, выдавший роль
     */
    event  RoleGranted(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );
    
    /**
     * @notice событие сообщающее об отзыве роли
     * @param role - отозванная роль
     * @param account - адрес, с которого была отозвана роль
     * @param sender - адрес, отозваший роль
     */
    event RoleRevoked(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );

    /**
     * @notice событие сообщее об изменении админа роли
     * @param role - роль, для которой изменена админская роль
     * @param previousAdminRole - предыдущая админская роль
     * @param newAdminRole - выданная админская роль
     */
    event RoleAdminChanged(
        bytes32 indexed role,
        bytes32 indexed previousAdminRole,
        bytes32 indexed newAdminRole
    );

    /**
     * @notice ошибка индицирует, что у адреса нет полномочий (роли) для вызова функции
     * @param account - проверяемый адрес
     * @param role - требуемая роль
     */
    error UnauthorizedAccount(address account, bytes32 role);
    
    /**
     * @notice функция выдает роль на адрес
     * @param role - выдаваемая роль
     * @param account - адрес, которому выдается роль
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @notice функция отзывает у адреса роль
     * @param role - отзываемая роль
     * @param account - адрес, у которого отзывается роль
     */
    function revokeRole(bytes32 role, address account) external;     

    /**
     * @notice функция возвращает админскую роль для заданной роли
     * @param role - роль, для которой делаем запрос
     * @return bytes32 админская роль
     */
    function getRoleAdmin(bytes32 role) external view returns(bytes32);  
    
}