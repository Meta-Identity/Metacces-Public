// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @dev Interface of the child ERC20 token, for use on sidechains and L2 networks.
interface IERC20Child is IERC20 {
  /**
   * @notice called by bridge gateway when tokens are deposited on root chain
   * Should handle deposits by minting the required amount for the recipient
   *
   * @param recipient an address for whom minting is being done
   * @param amount total amount to mint
   */
  function mint(
    address recipient,
    uint256 amount
  )
    external;

  /**
   * @notice called by bridge gateway when tokens are withdrawn back to root chain
   * @dev Should burn recipient's tokens.
   *
   * @param amount total amount to burn
   */
  function burn(
    uint256 amount
  )
    external;

  /**
   *
   * @param account an address for whom burning is being done
   * @param amount total amount to burn
   */
  function burnFrom(
    address account,
    uint256 amount
  )
    external;
}

contract PolygonBridge {
    
    event NewGateway(address newGateway);
    event BridgeInitialized(uint indexed timestamp);
    event TokensBridged(address indexed requester, bytes32 indexed mainDepositHash, uint amount, uint timestamp);
    event TokensReturned(address indexed requester, bytes32 indexed sideDepositHash, uint amount, uint timestamp);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    
    IERC20Child private BTKToken;
    bool bridgeInitState;
    address public owner;
    address public gateway;


    constructor (address _gateway) {
        gateway = _gateway;
        owner = msg.sender;
    }

    function initializeBridge (address _childTokenAddress) onlyOwner external {
        BTKToken = IERC20Child(_childTokenAddress);
        bridgeInitState = true;
        emit BridgeInitialized(block.timestamp);
    }
    function transferOwnership(address _newOwner) external onlyOwner{
        require(_newOwner != address(0),"address zero!");
        owner = _newOwner;
        emit OwnershipTransferred(owner, _newOwner);
    }

    function bridgeTokens (address _requester, uint _bridgedAmount, bytes32 _mainDepositHash) verifyInitialization onlyGateway  external {
        BTKToken.mint(_requester,_bridgedAmount);
        emit TokensBridged(_requester, _mainDepositHash, _bridgedAmount, block.timestamp);
    }

    function returnTokens (address _requester, uint _bridgedAmount, bytes32 _sideDepositHash) verifyInitialization onlyGateway external {
        BTKToken.burn(_bridgedAmount);
        emit TokensReturned(_requester, _sideDepositHash, _bridgedAmount, block.timestamp);
    }

    function setGateway (address _newGateway) onlyOwner external {
        gateway = _newGateway;
        emit NewGateway(_newGateway);
    }

    modifier verifyInitialization {
      require(bridgeInitState, "Bridge has not been initialized");
      _;
    }
    
    modifier onlyGateway {
      require(msg.sender == gateway, "Only gateway can execute this function");
      _;
    }

    modifier onlyOwner {
      require(msg.sender == owner, "Only owner can execute this function");
      _;
    }
    

}

/**********************************
 Proudly Developed by Metacces Team
***********************************/