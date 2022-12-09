//SPDX-License-Identifier:MIT
pragma solidity 0.8.7;

import "./exchange.sol";

//The Factory contract is registry for the exchange contracts
//Any exchange can be found by quering the registery
//By having registery exchanges hepls to make token-tokens swaps
//Factory contract deploys the exchange contract

//STEPS
//1. A mapping(TokenAddress => exchangeAddr) is required for register
//2. createExchange() function creates the exchange registers the addresses
//3. GetExchange() function retreives the function is registered or not


contract Factory{

    //step -1 :
    mapping (address => address) public registeredTknExg;

    //Step - 2:
    function createExchange(address _tokenAddr)public returns(address addr){
        require(_tokenAddr!=address(0),"invalid token address");
        require(registeredTknExg[_tokenAddr]==address(0),"aleardy registered");

        Exchange exchange= new Exchange(_tokenAddr);
        registeredTknExg[_tokenAddr]=address(exchange);
        
        return address(exchange);
    }

    //step - 3:
    function getExchange(address _tokenAddr)public view returns(address exg){
        return registeredTknExg[_tokenAddr];
    }

}