// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/token/ERC20/utils/SafeERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/access/Ownable.sol";

// local build
//import "../../openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
//import "../../openzeppelin-contracts/contracts/access/Ownable.sol";


contract TinanceEscrow is Ownable {
    
    event EscrowCreation(uint indexed orderId, address indexed buyer, uint value);
    event EscrowAgreed(uint indexed orderId,Escrow escrow);
    event EscrowDeposit(uint indexed orderId,Escrow escrow);
    event EscrowFail(uint indexed orderId,Escrow escrow);
    event EscrowTokenSent(uint indexed orderId,Escrow escrow);
    event EscrowTokenReceived(uint indexed orderId,Escrow escrow);
    event EscrowComplete(uint indexed orderId, Escrow escrow);
    event EscrowDisputeResovled(uint indexed orderId);

    enum EscrowStatus { Unknown, Funded, TokenApproved, FiatReceived, Completed, RequestCancel, CancelAgreed, Refunded, Arbitration, Error }

    uint256 public feesAvailable;  // summation of fees that can be withdrawn
    
     struct Escrow {
        address payable buyer;
        address payable seller;
        uint256 value;
        uint128 additionalGasFees;
        uint256 fee;
        uint32 expiry;
        EscrowStatus status;
        bool refundApproved;
    }
    
    mapping(uint => Escrow) public escrows;
    
    using SafeERC20 for IERC20;
    
    IERC20 immutable private tokenccy;
    
    constructor(IERC20 _currency) {
        tokenccy = _currency;
        feesAvailable = 0;
    }
    
   // Buyer defined as who buys usdt
    modifier onlyBuyer(uint _orderId){
        require(msg.sender == escrows[_orderId].buyer,"Only Buyer can call this");
        _;
    }

    // Seller defined as who sells usdt
    modifier onlySeller(uint _orderId) {
       require(msg.sender == escrows[_orderId].seller,"Only Seller can call this");
        _;
    }
    
   function getState(uint _orderId) public view returns (EscrowStatus){
        Escrow memory _escrow = escrows[_orderId];
        return _escrow.status;
    }

    function getContractBalance() public view returns (uint256){
        return tokenccy.balanceOf(address(this));
    }

    function getValue(uint _orderId) public view returns (uint256){
        Escrow memory _escrow = escrows[_orderId];
        return _escrow.value;
    }
    
    function getFee(uint _orderId) public view returns (uint256){
        Escrow memory _escrow = escrows[_orderId];
        return _escrow.fee;
    }
    
    function getAllowance(uint _orderId) public view returns (uint256){
        Escrow memory _escrow = escrows[_orderId];
        return tokenccy.allowance(_escrow.seller,address(this));
    }

    function getVersion() public pure returns (string memory){
        return "Escrow V1.196";
    }

    function createEscrow(uint _orderId, address payable _buyer, address payable _seller, uint _value, uint _fee, uint32 _expiry) external onlyOwner {
        require(escrows[_orderId].status == EscrowStatus.Unknown, "Escrow already exists");
        
       // require(msg.value >= getValue(_orderId), "The amount and the value sent to deposit do not match");
        Escrow memory _escrow =  Escrow(_buyer, _seller, _value, /*gas*/0, _fee, _expiry, EscrowStatus.Funded, false);
        escrows[_orderId] = _escrow;
        
         //Transfer USDT to contract after escrow creation
        require( tokenccy.allowance( _seller, address(this)) >= (_value),"Seller needs to approve funds to Escrow first !!");
        tokenccy.safeTransferFrom(_seller, address(this) , (_value) );
        tokenccy.safeApprove(_escrow.buyer,0); // reset any allowances
         
        emit EscrowDeposit(_orderId, _escrow);
     }

    function releaseEscrow(uint _orderId) external onlySeller(_orderId){
        Escrow memory _escrow = escrows[_orderId];
        require(_escrow.status == EscrowStatus.Funded,"USDT has not been deposited");
       
        _escrow.status = EscrowStatus.TokenApproved;
        
        uint256 _totalFees = _escrow.fee + _escrow.additionalGasFees;
        feesAvailable += _totalFees;
        
        // here we tell the curreny that the buyer can ONLY have 'value' funds.
        tokenccy.safeApprove(_escrow.buyer,(_escrow.value - _totalFees));
        //emit EscrowComplete(_orderId, _escrow);
        
        require(_escrow.status == EscrowStatus.TokenApproved,"USDT has not been approved!");
        _escrow.status = EscrowStatus.Completed;
        
        tokenccy.safeTransfer( _escrow.buyer, (_escrow.value - _totalFees) );
        delete escrows[_orderId];
        emit EscrowComplete(_orderId, _escrow);
 
    }

     /// release funds to the buyer in case of dispute
    function refundEscrow(uint _orderId, uint8 _buyerPercent) external onlyOwner {
        Escrow memory _escrow = escrows[_orderId];
        require( _escrow.status == EscrowStatus.FiatReceived,"Fiat money have not been received on seller side!");
        uint256 _totalFees = _escrow.fee  + _escrow.additionalGasFees;
        feesAvailable += _totalFees;
        
        delete escrows[_orderId];
        emit EscrowDisputeResovled(_orderId);
        
        if (_buyerPercent > 0)
            tokenccy.safeTransfer(_escrow.buyer, (_escrow.value - _totalFees) * _buyerPercent / 100);
        if (_buyerPercent < 100)
            tokenccy.safeTransfer(_escrow.seller, (_escrow.value - _totalFees) * (100 - _buyerPercent) / 100);
     }

    function withdrawFees(address payable _to, uint256 _amount) external payable onlyOwner {
        // This check also prevents underflow
        require(_amount <= feesAvailable, "Amount is higher than amount available");
        feesAvailable -= _amount;
        tokenccy.safeTransfer( _to, _amount );
    }

    /// TO DO: Implement this, remove 'pure' and require() to stop compiler warnings
    function refund(uint _orderId) pure external {
        require(_orderId!=_orderId,"Not Implemented Yet!!"); // stop compiler warning until we implement
        //Payment storage _payment = agrements[_orderId];
        //refundPayment(_orderId, msg.sender, PaymentStatus.Refunded);
    }

    /// TO DO: Implement this, remove 'pure' and require() to stop compiler warnings
    function approveRefund(uint _orderId) pure external {
        require(_orderId!=_orderId,"Not Implemented Yet!!"); // stop compiler warning until we implement
        // Payment storage _payment = agrements[_orderId];
        // require(msg.sender == _payment.seller);
        // _payment.refundApproved = true;
    }

    function increaseGasCosts(uint _orderId, uint128 _gas) private {
        escrows[_orderId].additionalGasFees += _gas * uint128(tx.gasprice);
    }

    function notImplementedYet() pure private {
        require(1!=2,"Not Implemented Yet!!"); // stop compiler warning until we implement
    }

}
