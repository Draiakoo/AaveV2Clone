// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract LendingPoolAddressesProvider is Ownable{

    event AddressSet(bytes32 id, address newAddress);
    event MarketNameSet(string newMarketId);

    string private _marketName;
    mapping(bytes32 => address) private _addresses;

    bytes32 private constant LENDING_POOL = 'LENDING_POOL';
    bytes32 private constant LENDING_POOL_CONFIGURATOR = 'LENDING_POOL_CONFIGURATOR';
    bytes32 private constant POOL_ADMIN = 'POOL_ADMIN';
    bytes32 private constant EMERGENCY_ADMIN = 'EMERGENCY_ADMIN';
    bytes32 private constant LENDING_POOL_COLLATERAL_MANAGER = 'COLLATERAL_MANAGER';
    bytes32 private constant PRICE_ORACLE = 'PRICE_ORACLE';
    bytes32 private constant LENDING_RATE_ORACLE = 'LENDING_RATE_ORACLE';

    constructor(string memory marketName) Ownable(msg.sender){
        _marketName = marketName;
    }

    function getMarketName() external view returns(string memory marketName){
        marketName = _marketName;
    }

    function setMarketName(string memory newMarketName) external onlyOwner{
        _marketName = newMarketName;
        emit MarketNameSet(newMarketName);
    }

    function setAddress(bytes32 key, address newAddress) external onlyOwner{
        _addresses[key] = newAddress;
        emit AddressSet(key, newAddress);
    }

    function getAddress(bytes32 key) external view returns(address keyAddress){
        keyAddress = _addresses[key];
    }
}