//SPDX-License-Identifier:MIT
pragma solidity 0.8.7;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

//This contract is for creating ETH-Token pair in uniswap v1
//NOTE: Exchange contract is nothing but pool

interface IExchange{
    function ethToTokenSwap(uint256 _tokenAmt)external payable returns(uint256 swapped);
}

//This the inferace to wrap the factory address to access the getExchange() function
interface Ifactory{
    function getExchange(address _tokenAddr)external view returns(address);
}

contract Exchange is ERC20{
    address public tokenAddress;   //to get the token contract address
    address public factoryAddress; //linking the exchange contract with the factory contract

    //Step 1: getting the token contract address
    constructor(address _tokenAddresss)ERC20("PurpleSwap","PS"){
        require(_tokenAddresss != address(0),"invalid token address");
        tokenAddress=_tokenAddresss;
        factoryAddress=msg.sender;
    }

    //Step 2: adding the liquidity to the pool
    //NOTE: payable to accept ether and _tokenAmt to get how much tokens to transfer into pool
    // where here ERC20 tokens should approve the exchange contract to use the _tokenAmt given 
    //Now the addLiquidity is divided into two branches 
    //1.when intial supply of token and eth is 0
    //2.if any supply is present should use the previous ratios to add liquidity,
    // because not to all any prices differences after adding the liquidity which allows
    // arbitregures 
    // Uniswap V1 uses the PS tokens are minted proportion to the Ether they liquidate
    // ex: if intially adding liquidity
    //     10 eth ---> 10 PS tokens
    // else: PSTokens= (NEW_eth*totalSupply_of_PS)/Eth_reserves

    function addLiquidity(uint256 _tokenAmt)public payable{
        uint256 tokenBal=tokenBalance();
       if(tokenBal==0){
            IERC20 token = IERC20(tokenAddress);
            token.transferFrom(msg.sender,address(this),_tokenAmt);    //which gives ownership to exchange
            _mint(msg.sender,address(this).balance);
       }
       else{
          uint256 requiredTokens=(msg.value * tokenBal)/address(this).balance;
          require(_tokenAmt>=requiredTokens,"insuffecient tokens sent");
          IERC20(tokenAddress).transferFrom(msg.sender,address(this),_tokenAmt);  //caller gives permission use approved token amount
          uint256 PSTokens=(msg.value*totalSupply())/address(this).balance;
          _mint(msg.sender,PSTokens);
       }
    }

    //Step 3: To get the tokenBalance in the contract
    function tokenBalance()public view returns(uint256 ){
        return IERC20(tokenAddress).balanceOf(address(this));
    }

    //Step 4: function to get price for one per another
    // this function gets easily manipulated because the garph may passed by 0,
    function getPrice(uint256 _inputReserves,uint256 _outputReserves)public pure returns(uint256 ){
        require(_inputReserves>0 && _outputReserves>0,"invalid reserves");
        return (_inputReserves/_outputReserves);
    }

    //Step 5: amount of token or ether
    function getAmount(uint256 inputAmt,uint256 inputReserves,uint256 outputReserves)private pure returns(uint256 ){
        require(inputReserves>0 && outputReserves>0,"invalid reserves");
        return (outputReserves*inputAmt)/(inputAmt+inputReserves);
    } 

    //step 6: to get the token amount when i give ether amt
    function toGetTokenAmt(uint256 _ethSold)public view returns(uint256 ){
        require(_ethSold>0,"ethSold is too small amount");
        uint256 tokenReserves = tokenBalance();
        return getAmount(_ethSold,address(this).balance,tokenReserves);
    }
    
    
    //to get the ether amount when i give tokens amt
    function toGetEthAmt(uint256 _tokenAmt)public view returns(uint256 ){
        require(_tokenAmt>0,"_tokenAmt is too small ");
        uint256 tokenReserves = tokenBalance();
        return getAmount(_tokenAmt,tokenReserves,address(this).balance);
    }



    //step 7:ethToToken swap function
    function ethToTokenSwap(uint256 _minTokens)public payable returns(uint256 _swapped){
        uint256 tokenReserves = tokenBalance();
        uint256 swappedTokens = getAmount(msg.value,address(this).balance-msg.value,tokenReserves);
        require(swappedTokens >= _minTokens,"insufficient tokens");
        IERC20(tokenAddress).transfer(msg.sender,swappedTokens);
        return swappedTokens;
    }




    //step 8:tokenToEth swap function
    function tokenToEthSwap(uint256 _tokens,uint256 _minEth)public{
        uint256 tokenReserves = tokenBalance();
        uint256 swappedEth = getAmount(_tokens,tokenReserves,address(this).balance);
        require(swappedEth >= _minEth,"insufficient eth");
        //before transfering the tokens , the caller should approve to add the tokens to pool
        //therefore giving permission to the contr
        IERC20(tokenAddress).transferFrom(msg.sender,address(this),_tokens);
        payable(msg.sender).transfer(swappedEth);
    }



   //step 9: remove liquidty from the exchange
   function removeLiquidity(uint256 _tokens)public{
    require(_tokens<= balanceOf(msg.sender),"u cant removeLiquidity");
    //To get the eth reserves
    uint256 ethAmt=(address(this).balance*_tokens)/totalSupply();
    //To get the token reserves
    uint256 tokenAmt = (tokenBalance()*_tokens)/totalSupply();

    //transfer this funds to the liquidity provider
    //1.eth transfer
    //2.token transfer
    // 3.the PS tokens are backed by the liquidity so,Burn the PS tokens
    _burn(msg.sender,_tokens);
    payable(msg.sender).transfer(ethAmt);
    IERC20(tokenAddress).transfer(msg.sender,tokenAmt);
   }


   //STEP - 10: Token to Token swap 
   // follow :
   // 1.token to ether swap 
   // 2.checks for the desired token swap exchange exits or not
   // 3.give ether to it and take back the required tokens

   function TokenToTokenSwap(
    uint256 _soldTokens,uint256 _minAmtTokens,address _tokenAddress
    )public{
        address exchangeAddr = Ifactory(factoryAddress).getExchange(_tokenAddress);
        require(
            exchangeAddr!=address(this) && exchangeAddr !=address(0),
            "invalid/not registered exchange address"
        );

        //token to ether amount
        uint256 tokenReserves = tokenBalance();
        uint256 receivedEth = getAmount(_soldTokens,tokenReserves,address(this).balance);


        //_soldTokens transfers to the contract 
        IERC20(_tokenAddress).transferFrom(msg.sender,address(this),_soldTokens); 


        //eth to tokens swap with required token exchange contract
        //when ethTotokenSwap() called by exchange contract, it becomes the msg.msg.sender
        // in the ethToTokenSwap() contract transfer() sends funds to the this Exchange contract
        //so, we are taking taking that funds to and transfer to the user
        uint256 swappedTokens = IExchange(exchangeAddr).ethToTokenSwap{value:receivedEth}(_minAmtTokens);
        IERC20(_tokenAddress).transfer(msg.sender,swappedTokens);
   }
}