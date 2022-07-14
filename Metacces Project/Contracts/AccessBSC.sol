// SPDX-License-Identifier: MIT


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
pragma solidity = 0.8.15;

// Metacces Starts here!

contract Metacces is ERC20 {
    using SafeMath for uint256;
    address private owner;

    address public Bridge;
    address public constant theCompany = 0xc6e5347D1A5FE685160429705E9e26bD3BBa8fEa;
    address public deadAddress = 0x000000000000000000000000000000000000dEaD;

    uint256 internal sSBlock;uint256 internal sEBlock;uint256 internal sTot;
    uint256 internal sPrice;
    uint256 public Path = 10** decimals();
    uint256 public max = 20 * Path;
    uint256 public min = max.div(100);
    uint256 public privateLimit = 1000000;
    uint256 public maxSupply = 500000000 * Path;

    event WithdrawalBNB(uint256 _amount, uint256 decimal, address to); 
    event WithdrawalToken(address _tokenAddr, uint256 _amount,uint256 decimals, address to);
    event SetBridge(address newBridge);
    event PrivateSale(uint256 Amount, uint256 Price);
    event saleStarted(uint256 blockNumber);
    event saleEnded(uint256 Time);
    event minMax(uint256 Min, uint256 Max);
    event PrivateLimit(uint256 newLimit);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    modifier onlyOwner(){
        require(msg.sender == owner, "caller not owner");
        _;
    }

constructor () ERC20("Metacces", "Acces") payable {
    owner = msg.sender;
    _mint (address(this), maxSupply.mul(5).div(100)); // 5%
    _mint (theCompany, maxSupply.mul(95).div(100)); // 95%
      //Send required amount of tokens to bridge for each chain to be linked  
}

   function transferOwnership(address _newOwner) external onlyOwner{
       require(_newOwner != address(0),"Zero address");
       owner = _newOwner;
       emit OwnershipTransferred(owner, _newOwner);
   } 
   function privateSale(address) external payable returns (bool success){
    require(balanceOf(address(msg.sender)) <= privateLimit * Path , "You reached your private sale limit");  
    require(sSBlock <= block.number && block.number <= sEBlock, "Private Sale has ended or did not start yet");

    uint256 _eth = msg.value;
    uint256 _tkns;
    
    require ( _eth >= min && _eth <= max , "Less than Minimum or More than Maximum");
    _tkns = (sPrice.mul(_eth)).div(1 ether);
    sTot ++;
    
    _transfer(address(this), msg.sender, _tkns); 
    emit PrivateSale(_tkns, sPrice);
    return true;
  }

  function viewSale() public view returns(uint256 StartBlock, uint256 EndBlock, uint256 SaleCount, uint256 SalePrice){
    return(sSBlock, sEBlock, sTot,  sPrice);
  }
  
  function startSale(uint256 _sEBlock, uint256 _sPrice) external onlyOwner{
    require(_sEBlock != 0 && _sPrice !=0,"Zero!");
    sEBlock = _sEBlock; 
    sPrice =_sPrice;
    emit saleStarted(_sEBlock);
  }
  
  function endSale () external onlyOwner{
    sEBlock = block.number;
    emit saleEnded(block.timestamp);
  }

  function changeMinMaxPrivateSale(uint256 minAmount, uint256 maxAmount) external onlyOwner {
      require(minAmount != 0 && maxAmount !=0,"Zero!");
      min = minAmount;
      max = maxAmount * Path;
      emit minMax(min, max);
  }

  function setPrivateLimit(uint256 _limit) external onlyOwner {
      require(_limit !=0,"Zero!");
      privateLimit = _limit;
      emit PrivateLimit(_limit);
  }

/*@dev this function is only used if users send tokens by mistake
to contract address.
only the owner can send the tokens back to them
*/
  function withdrawalToken(address _tokenAddr, uint256 _amount, uint256 decimal, address to) external onlyOwner() {
        require(_tokenAddr != address(0),"address zero!");
        uint256 dcml = 10 ** decimal;
        ERC20 token = ERC20(_tokenAddr);
        emit WithdrawalToken(_tokenAddr, _amount, decimal, to);
        token.transfer(to, _amount*dcml); 
    }

/* @dev this function is used to withdraw BNB
collected by the private sale. it can also retrive 
mistaken sent tokens to investors.
*/    
  function withdrawalBNB(uint256 _amount, uint256 decimal, address to) external onlyOwner() {
        require(address(this).balance >= _amount,"No BNB!");
        require(to != address(0),"Zero address");
        uint256 dcml = 10 ** decimal;
        emit WithdrawalBNB(_amount, decimal, to);
        payable(to).transfer(_amount*dcml);      
    }

  function setBridge (address payable newBridge) external onlyOwner{
      emit SetBridge(newBridge);
      Bridge = newBridge;
  }

    receive() external payable {}

}

/**********************************
 Proudly Developed by Metacces Team
***********************************/