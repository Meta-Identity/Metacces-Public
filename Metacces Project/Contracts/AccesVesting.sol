// SPDX-License-Identifier: MIT

/************************
Metacces Vesting Wallet
************************/

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

pragma solidity = 0.8.15;

contract AccesVesting {
    using SafeMath for uint256;

    address public constant zeroAddress = address(0x0);
    address public constant deadAddress = 0x000000000000000000000000000000000000dEaD;
    
    ERC20 public Acces;
    address private owner;
    uint256 public constant monthly = 30 days;
    uint256 public investorCount;
    uint256 private investorID;
    uint256 public investorsVault;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 public constant hPercent = 100; //100%
    uint256 private _status;
    uint256 public mP = 5; /* Monthy percentage */
    

    event InvestorAdded(address Investor, uint256 Amount);
    event AccesClaimed(address Investor, uint256 Amount);
    event ChangeOwner(address NewOwner);
    event WithdrawalBNB(uint256 _amount, uint256 decimal, address to); 
    event WithdrawalAcces(uint256 _amount,uint256 decimal, address to);
    event WithdrawalBEP20(address _tokenAddr, uint256 _amount,uint256 decimals, address to);
    
    struct InvestorSafe{
        uint256 investorID;
        uint256 falseAmount; //represents the actual amount locked in order to keep track of monthly percentage to unlock
        uint256 amount;
        uint256 monthLock;
        uint256 lockTime;
        uint256 timeStart;
    }
 
    mapping(address => bool) public Investor;
    mapping(address => InvestorSafe) public investor;


    mapping(address => bool) public blackList; 
    

    modifier onlyOwner (){
        require(msg.sender == owner, "Only Acces owner can add Investors");
        _;
    }

    modifier isInvestor(address _investor){
        require(Investor[_investor] == true, "Not an Investor!");
        _;
    }

    modifier isNotBlackListed(address _investor){
        require(blackList[_investor] != true, "Your wallet is Blacklisted!");
        _;
    }
    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
    constructor(ERC20 _Acces) {
        owner = msg.sender;
        investorCount = 0;
        investorID = 0;
        Acces = _Acces;
        _status = _NOT_ENTERED;
    }
    function transferOwnership(address _newOwner)external onlyOwner{
        require(_newOwner != zeroAddress,"Zero Address");
        emit ChangeOwner(_newOwner);
        owner = _newOwner;
    }
    function setMonthlyPercentage(uint256 _mP) external onlyOwner{
        require(_mP > 0 && mP <= 30,"Min 1% Max 30%");
        mP = _mP;
    }
    function addToBlackList(address _investor) external onlyOwner{
        blackList[_investor] = true;
    }
    function removeFromBlackList(address _investor) external onlyOwner{
        blackList[_investor] = false;
    }
    function addInvestor(address _investor, uint256 _amount, uint256 _lockTime) external onlyOwner{
        require(_investor != zeroAddress && _investor != deadAddress,"Zero Address Dead!");
        uint256 availableAmount = Acces.balanceOf(address(this)).sub(investorsVault);
        require(availableAmount >= _amount,"No Acces");
        uint256 lockTime = _lockTime.mul(1 days);
        require(_amount > 0, "Amount!");
        if(investor[_investor].amount > 0){
            investor[_investor].amount += _amount;
            investor[_investor].falseAmount = investor[_investor].amount;
            investorsVault += _amount;
            return;
        }
        require(lockTime > monthly.mul(3), "Please set a time in the future more than 90 days!");
        emit InvestorAdded(msg.sender, _amount);
        investorID++;
        investor[_investor].investorID = investorID;
        investor[_investor].falseAmount = _amount;
        investor[_investor].amount = _amount;
        investor[_investor].lockTime = lockTime.add(block.timestamp);
        investor[_investor].timeStart = block.timestamp;
        investor[_investor].monthLock = lockTime.add(block.timestamp);
        Investor[_investor] = true;
        investorsVault += _amount;
        investorCount++;
    }
    function claimMonthlyAmount() external isInvestor(msg.sender) isNotBlackListed(msg.sender) nonReentrant{
        uint256 totalTimeLock = investor[msg.sender].monthLock;
        uint256 mainAmount = investor[msg.sender].falseAmount;
        uint256 remainAmount = investor[msg.sender].amount;
        require(totalTimeLock <= block.timestamp, "Not yet");
        require(remainAmount > 0, "No Acces");  
        uint256 amountAllowed = mainAmount.mul(mP).div(hPercent);
        investor[msg.sender].amount = remainAmount.sub(amountAllowed);
        investor[msg.sender].monthLock += monthly;
        investorsVault -= amountAllowed;
        if(investor[msg.sender].amount == 0){
            Investor[msg.sender] = false;
            delete investor[msg.sender]; 
            investorCount--;
        }
        emit AccesClaimed(msg.sender, amountAllowed);
        Acces.transfer(msg.sender, amountAllowed);
    }
    function claimRemainings() external isInvestor(msg.sender) isNotBlackListed(msg.sender) nonReentrant{
        uint256 fullTime = hPercent.div(mP).mul(monthly);
        uint256 totalTimeLock = investor[msg.sender].lockTime.add(fullTime);
        require(totalTimeLock <= block.timestamp, "Not yet");
        uint256 remainAmount = investor[msg.sender].amount;
        investor[msg.sender].amount = 0;
        investorsVault -= remainAmount;
        Investor[msg.sender] = false;
        delete investor[msg.sender];
        emit AccesClaimed(msg.sender, remainAmount);
        Acces.transfer(msg.sender, remainAmount);
        investorCount--;
    }
    function withdrawalAcces(uint256 _amount, uint256 decimal, address to) external onlyOwner() {
        uint256 amount = Acces.balanceOf(address(this)).sub(investorsVault);
        uint256 dcml = 10 ** decimal;
        require(amount > 0 && _amount&dcml >= amount, "No Acces!");// can only withdraw what is not locked for investors.
        emit WithdrawalAcces( _amount, decimal, to);
        Acces.transfer(to, _amount*dcml);
    }
    function withdrawalBEP20(address _tokenAddr, uint256 _amount, uint256 decimal, address to) external onlyOwner() {
        uint256 dcml = 10 ** decimal;
        ERC20 token = ERC20(_tokenAddr);
        require(token != Acces, "No!"); //Can't withdraw Acces using this function!
        emit WithdrawalBEP20(_tokenAddr, _amount, decimal, to);
        token.transfer(to, _amount*dcml); 
    }  
    function withdrawalBNB(uint256 _amount, uint256 decimal, address to) external onlyOwner() {
        require(address(this).balance >= _amount,"Balanace"); //No BNB balance available
        uint256 dcml = 10 ** decimal;
        emit WithdrawalBNB(_amount, decimal, to);
        payable(to).transfer(_amount*dcml);      
    }
    receive() external payable {}
}


/**********************************
 Proudly Developed by Metacces Team
***********************************/
