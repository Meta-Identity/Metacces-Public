// SPDX-License-Identifier: MIT

/************************
Metacces Vesting Contract
************************/

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

pragma solidity = 0.8.15;

contract AccesVesting {
    using SafeMath for uint256;

    address public constant zeroAddress = address(0x0);
    address public constant deadAddress = 0x000000000000000000000000000000000000dEaD;
    //address private feeReceiver;
    
    ERC20 public Acces;
    address private owner;
    uint256 public constant monthly = 30;//30 days;
    uint256 public constant yearly = 365;//365 days;
    uint256 public investorCount;
    uint256 public investorsVault;
    uint256 public teamVault;
    uint256 public teamCount;
    uint256 public totalLocked;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 public constant hPercent = 100; //100%
    uint256 private _status;
    uint256 public mP = 5; /* Monthy percentage */
    bool public samePercentage = false;
    

    event InvestorAdded(address Investor, uint256 Amount, string investorType, uint256 yearsLocked);
    event TeamAdded(address Team, uint256 Amount);
    event AccesClaimed(address Investor, uint256 Amount);
    event ChangeOwner(address NewOwner);
    event addressBlacklisted(address);
    event removedFromBlacklist(address);
    event fixedLock(address Investor);
    event MonthlyPercentageChanged(uint256 NewPercentage);
    event WithdrawalBNB(uint256 _amount, uint256 decimal, address to); 
    event WithdrawalAcces(uint256 _amount,uint256 decimal, address to);
    event WithdrawalBEP20(address _tokenAddr, uint256 _amount,uint256 decimals, address to);
    
    struct InvestorSafe{
        uint256 amount;
        uint256 yP;
        uint256 mP;
        uint256 yearlyAllowance;
        uint256 yearLock;
        uint256 monthLock;
        uint256 lockTime;
        uint256 firstUnlock;
        uint256 timeStart;
        bool isTeam;
    }
    struct amountCalculation{
        uint256 yearlyAllowed;
        uint256 monthlyAllowed;
        uint256 yearsCount;
        uint256 monthsCount;
        uint256 endYear;
    }
 
    mapping(address => bool) public Investor;
    mapping(address => InvestorSafe) public investor;
    mapping(address => amountCalculation) public investorAllowance;


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
    constructor(ERC20 _Acces){ //, address _feeReceiver) {
        owner = msg.sender;
        //feeReceiver = _feeReceiver;
        investorCount = 0;
        Acces = _Acces;
        _status = _NOT_ENTERED;
    }
    function transferOwnership(address _newOwner)external onlyOwner{
        require(_newOwner != zeroAddress,"Zero Address");
        emit ChangeOwner(_newOwner);
        owner = _newOwner;
    }
    /*function changeFeeReceiver(address _newReceiver) external onlyOwner{
        feeReceiver = _newReceiver;
    }*/
    function setMonthlyPercentage(uint256 _mP) external onlyOwner{
        require(_mP > 0 && mP <= 30,"Min 1% Max 30%");
        mP = _mP;
        
        emit MonthlyPercentageChanged(_mP);
    }
    function addToBlackList(address _investor) external onlyOwner{
        require(_investor != zeroAddress,"Zero address");
        blackList[_investor] = true;
        emit addressBlacklisted(_investor);
    }
    function removeFromBlackList(address _investor) external onlyOwner{
        require(_investor != zeroAddress,"Zero address");
        blackList[_investor] = false;
        emit removedFromBlacklist(_investor);
    }
    function allVaults() internal{
        totalLocked = investorsVault.add(teamVault);
    }
    function activateSamePercentage() external onlyOwner{
        samePercentage = true;
    }
    function disableSamePercentage() external onlyOwner{
        samePercentage = false;
    }
    function editInvestorLock(address _investor, uint256 _yPercent, uint256 _mPercent) external onlyOwner{
        require(_investor != zeroAddress && Investor[_investor] == true,"Zero address or address is not investor");
        require(_yPercent > 10 && _yPercent < 20,"Yearly percent limit!");
        require(_mPercent > 5 && _mPercent < 10,"Monthly percent limit");
        investor[_investor].yP = _yPercent;
        investor[_investor].mP = _mPercent;
        setAllowance(_investor);
    }
    function setAllowance(address _investor) internal{
        investor[_investor].yearlyAllowance = investor[_investor].amount.mul(investor[_investor].yP).div(hPercent);
        investorAllowance[_investor].yearlyAllowed = investor[_investor].yearlyAllowance;
        require(investorAllowance[_investor].yearlyAllowed > 0,"Year error");
        investorAllowance[_investor].monthlyAllowed = investorAllowance[_investor].yearlyAllowed.div(12);//.mul(investor[_investor].mP).div(hPercent);
    }
    function addInvestor(address _investor, bool _isTeam, uint256 _amount, uint256 _yPercent, uint256 _lockTime, uint256 _firstUnlock) external onlyOwner{
        require(_investor != zeroAddress && _investor != deadAddress,"Zero Address Dead!");
        //require(_yPercent >=10 && _mPercent >=5,"Percentage!");
        string memory investorType;
        uint256 availableAmount = Acces.balanceOf(address(this)).sub(investorsVault);
        require(availableAmount >= _amount,"No Acces");
        uint256 lockTime = _lockTime.mul(monthly);
        uint256 firstUnlock = _firstUnlock.mul(monthly);
        require(_amount > 0, "Amount!");
        if(investor[_investor].amount > 0){
            investor[_investor].amount += _amount;
            investorsVault += _amount;
            return;
        }
        //require(lockTime >= monthly.mul(3), "Please set a time in the future more than 90 days!");
        require(firstUnlock < lockTime,"lock error");
        investor[_investor].amount = _amount;
        investor[_investor].yP = _yPercent;
        investor[_investor].mP = hPercent.div(12);
        setAllowance(_investor);
        investor[_investor].lockTime = lockTime.add(block.timestamp);
        investor[_investor].timeStart = block.timestamp;
        if(lockTime >= yearly){
            uint256 lockYears = (lockTime / yearly).mul(yearly);
            investor[_investor].yearLock = lockYears.add(block.timestamp);
            investorAllowance[_investor].endYear = yearly.add(firstUnlock).add(block.timestamp);
        }
        
        investor[_investor].monthLock = monthly.add(block.timestamp);
        investor[_investor].firstUnlock = firstUnlock.add(block.timestamp);
        investor[_investor].isTeam = _isTeam;
        Investor[_investor] = true;
        if(_isTeam == true){
            teamVault += _amount;
            teamCount++;
            investorType = "Team";
        }
        else{
           investorsVault += _amount;
           investorCount++;
           investorType = "Investor";
        }
        allVaults();
        emit InvestorAdded(msg.sender, _amount, investorType, _lockTime.div(12));
    }
    function claimMonthlyAmount() external isInvestor(msg.sender) isNotBlackListed(msg.sender) nonReentrant{
        require(investor[msg.sender].firstUnlock < block.timestamp,"Unlock in not available yet");
        require(investorAllowance[msg.sender].yearlyAllowed > 0, "Insufficient allowance, until next year!");
        //uint256 _mP;
        uint256 monthlyAmount;// = investorAllowance[msg.sender].monthlyAllowed;
        if(investorAllowance[msg.sender].endYear <= block.timestamp){
             if(investor[msg.sender].yearlyAllowance > investor[msg.sender].amount){
                investor[msg.sender].yearlyAllowance = investor[msg.sender].amount;
             }
            uint256 leftOver = investorAllowance[msg.sender].yearlyAllowed;
            investorAllowance[msg.sender].yearlyAllowed = investor[msg.sender].yearlyAllowance;
            investorAllowance[msg.sender].yearsCount ++;
            investorAllowance[msg.sender].endYear = block.timestamp.add(yearly);
            investorAllowance[msg.sender].yearlyAllowed += leftOver;
            investorAllowance[msg.sender].monthlyAllowed = investorAllowance[msg.sender].yearlyAllowed.div(12);
        }
        if(samePercentage == true){
            monthlyAmount = investor[msg.sender].yearlyAllowance.mul(mP).div(hPercent); //_mP = mP;
        }
        else{
            monthlyAmount = investorAllowance[msg.sender].monthlyAllowed; //_mP = investor[msg.sender].mP;
        }
        uint256 monthLock = investor[msg.sender].monthLock;
        //uint256 yearlyAmount = investorAllowance[msg.sender].yearlyAllowed;
        require(monthLock <= block.timestamp, "Not yet");
        require(monthlyAmount > 0, "No Acces");  
        //uint256 amountAllowed = yearlyAmount.mul(_mP).div(hPercent);
        investor[msg.sender].amount -= monthlyAmount;
        investor[msg.sender].monthLock = block.timestamp.add(monthly);
        if(investor[msg.sender].isTeam == true){
            teamVault -= monthlyAmount;
        }
        else{
            investorsVault -= monthlyAmount;
        }
        
        investorAllowance[msg.sender].yearlyAllowed -= monthlyAmount;
        if(investor[msg.sender].amount == 0){
            Investor[msg.sender] = false;
            delete investor[msg.sender];
            if(investor[msg.sender].isTeam == true){
                teamCount--;
            }
            else{
                investorCount--;
            } 
        }
        allVaults();
        emit AccesClaimed(msg.sender, monthlyAmount);
        Acces.transfer(msg.sender, monthlyAmount);
        investorAllowance[msg.sender].monthsCount ++;
    }
    function claimRemainings() external isInvestor(msg.sender) isNotBlackListed(msg.sender) nonReentrant{
        //uint256 fullTime = hPercent.div(mP).mul(monthly);
        uint256 totalTimeLock = investor[msg.sender].lockTime.add(yearly);
        require(totalTimeLock <= block.timestamp, "Not yet");
        uint256 remainAmount = investor[msg.sender].amount;
        investor[msg.sender].amount = 0;
        if(investor[msg.sender].isTeam == true){
            teamVault -= remainAmount;
            teamCount--;
        }
        else{
            investorsVault -= remainAmount;
            investorCount--;
        }
        Investor[msg.sender] = false;
        delete investor[msg.sender];
        emit AccesClaimed(msg.sender, remainAmount);
        Acces.transfer(msg.sender, remainAmount);
    }
    function fixInvestorLock() isInvestor(msg.sender) external{
        if(investorAllowance[msg.sender].endYear <= block.timestamp){
            uint256 leftOver = investorAllowance[msg.sender].yearlyAllowed;
            investorAllowance[msg.sender].yearlyAllowed = investor[msg.sender].yearlyAllowance;
            investorAllowance[msg.sender].yearsCount ++;
            investorAllowance[msg.sender].endYear = block.timestamp.add(yearly);
            investorAllowance[msg.sender].yearlyAllowed += leftOver;
            investorAllowance[msg.sender].monthlyAllowed = investorAllowance[msg.sender].yearlyAllowed.div(12);
        }
        emit fixedLock(msg.sender);
    }
    function withdrawalAcces(uint256 _amount, uint256 _path, address to) external onlyOwner() {
        require(to != zeroAddress,"zero address");
        allVaults();
        uint256 amount = Acces.balanceOf(address(this)).sub(totalLocked);
        uint256 dcml = 10 ** _path;
        // can only withdraw what is not locked for investors.
        require(amount > 0 && _amount&dcml >= amount, "No Acces!");
        emit WithdrawalAcces( _amount, _path, to);
        Acces.transfer(to, _amount*dcml);
    }
    function withdrawalBEP20(address _tokenAddr, uint256 _amount, uint256 decimal, address to) external onlyOwner() {
        require(to != zeroAddress,"zero address");
        uint256 dcml = 10 ** decimal;
        ERC20 token = ERC20(_tokenAddr);
        require(token != Acces, "No!"); //Can't withdraw Acces using this function!
        emit WithdrawalBEP20(_tokenAddr, _amount, decimal, to);
        token.transfer(to, _amount*dcml); 
    }  
    function withdrawalBNB(uint256 _amount, uint256 decimal, address to) external onlyOwner() {
        require(to != zeroAddress,"zero address");
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
