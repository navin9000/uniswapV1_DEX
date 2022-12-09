//SPDX-License-Identifier:MIT
pragma solidity 0.8.7;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

//creating a contract for ERC20 token

contract Token is ERC20{
    constructor(
        string memory name,
        string memory symbol,
        uint256 intialSupply)
        ERC20(name,symbol){
            _mint(msg.sender,intialSupply);
        }
}
