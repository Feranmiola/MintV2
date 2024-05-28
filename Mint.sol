//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./StandardToken.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";


contract Mint{

    address immutable admin;

    uint256 public tokenCount;
    event TokenCreated(address indexed owner, address tokenaddress, string name, string symbols, uint8 decimals, uint totalSupply, string tokenType);


    constructor(){
        admin = msg.sender;
    }

    function createNewToken(address user, string calldata tokenName, string calldata tokenSymbols, uint8 decimals__, uint totalSupply, address router) external returns(address){
        PurpleToken01 newToken = new PurpleToken01(user, tokenName, tokenSymbols, decimals__, totalSupply, router);

        tokenCount++;

        emit TokenCreated(user, address(newToken), tokenName, tokenSymbols,  decimals__,  totalSupply, "Standard");
        
        return(address(newToken));

    }


    function createNewFeeToken(address user, string calldata tokenName, string calldata tokenSymbols, uint8 decimals__, uint totalSupply, fessAndWallets memory _feesStruct) external returns(address){

        require((_feesStruct.marketingFeeBps_ + _feesStruct.burnFee_) <= 1000, "Fee Limit reached");
        
        PurpleToken02 newToken = new PurpleToken02(user, tokenName, tokenSymbols, decimals__, totalSupply, _feesStruct);
        
        tokenCount++;
        
        emit TokenCreated(user, address(newToken), tokenName, tokenSymbols,  decimals__,  totalSupply, "FeeToken");

        return(address(newToken));


    }

    function getTotalNumberOfTokensCreated() external view returns(uint){
        return tokenCount;
    }
}