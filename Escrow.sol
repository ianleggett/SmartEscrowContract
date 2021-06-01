// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/token/ERC20/utils/SafeERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/access/Ownable.sol";

contract Escrow is Ownable {

   // using SafeERC20 for IERC20;
    using SafeERC20 for ERC20;
    
    event PaymentCreation(uint indexed orderId, address indexed buyer, uint value);
    event PaymentAgreed(uint indexed orderId,Payment payment);
    event PaymentDeposit(uint indexed orderId,Payment payment);
    event PaymentFail(uint indexed orderId,Payment payment);
    event PaymentGoodsSent(uint indexed orderId,Payment payment);
    event PaymentGoodsReceived(uint indexed orderId,Payment payment);
    event PaymentComplete(uint indexed orderId, Payment payment);

    enum PaymentStatus { Unknown, Created, Agreed, Deposit, GoodsSent, GoodsReceived, Completed, RequestCancel, CancelAgreed, Refunded, Arbitration, Error }

    /// Only the buyer can call this function.
    //error OnlyBuyer();
    /// Only the seller can call this function.
    //error OnlySeller();
    /// The function cannot be called at the current state.
    //error InvalidState();

    //error FailedPayment(string);
    
    uint256 public feesAvailable;  // summation of fees that can be withdrawn
    
    mapping(uint => Payment) public agrements;
    ERC20 immutable private tokenccy;

    constructor(ERC20 _currency) Ownable() {
        tokenccy = _currency;
        feesAvailable = 0;
    }
    
    struct Payment {
        address payable buyer;
        address payable seller;
        uint256 value;
        uint128 additionalGasFees;
        uint256 fee;
        uint32 expiry;
        PaymentStatus status;
        bool refundApproved;
    }

    modifier onlyBuyer(uint _orderId){
        require(msg.sender == agrements[_orderId].buyer,"Only Buyer can call this");
        _;
    }

    modifier onlySeller(uint _orderId) {
       require(msg.sender == agrements[_orderId].seller,"Only Seller can call this");
        _;
    }

    function getState(uint _orderId) public view returns (PaymentStatus){
        Payment memory _payment = agrements[_orderId];
        return _payment.status;
    }

    function getContractBalance() public view returns (uint256){
        return tokenccy.balanceOf(address(this));
    }

    function getValue(uint _orderId) public view returns (uint256){
        Payment memory _payment = agrements[_orderId];
        return _payment.value;
    }
    
    function getFee(uint _orderId) public view returns (uint256){
        Payment memory _payment = agrements[_orderId];
        return _payment.fee;
    }
    
    function getAllowance(uint _orderId) public view returns (uint256){
        Payment memory _payment = agrements[_orderId];
        return tokenccy.allowance(_payment.buyer,address(this));
    }

    function getVersion() public pure returns (string memory){
        return "Escrow V1.193";
    }

    function createPayment(uint _orderId, address payable _buyer, address payable _seller, uint _value, uint _fee, uint32 _expiry) external onlyOwner {
        Payment storage _payment = agrements[_orderId];
        require(_payment.status==PaymentStatus.Unknown, "Agreement already exists");
        agrements[_orderId] = Payment(_buyer, _seller, _value, /*gas*/0, _fee, _expiry, PaymentStatus.Created, false);
        emit PaymentCreation(_orderId, _buyer, _value);
    }
/**
    Buyer agrees and then approves funds transfer the amount of funds agreed
**/
    function agreePurchase(uint _orderId) external onlyBuyer(_orderId) {
        Payment storage _payment = agrements[_orderId];
        require(_payment.status!=PaymentStatus.Unknown, "Agreement does not exist");
        _payment.status =  PaymentStatus.Agreed;
        emit PaymentAgreed(_orderId, _payment);
    }
    /**
       Fund transferred in from Buyer
    **/
    function deposit(uint _orderId) external onlyBuyer(_orderId) {
        Payment storage _payment = agrements[_orderId];
        require(_payment.status!=PaymentStatus.Unknown, "Agreement does not exist");
        // buyer must approve the value amount beforehand in Dapp
        // how much has the buyer allowed us to get
        require( tokenccy.allowance( _payment.buyer, address(this)) >= (_payment.value + _payment.fee),"Buyer needs to approve funds to Escrow first !!");
        tokenccy.safeTransferFrom(  _payment.buyer, address(this) , (_payment.value + _payment.fee) );
       // require(msg.value >= getValue(_orderId), "The amount and the value sent to deposit do not match");
        _payment.status =  PaymentStatus.Deposit;
        emit PaymentDeposit(_orderId, _payment);
    }

    function goodsSent(uint _orderId) external onlySeller(_orderId){
        Payment storage _payment = agrements[_orderId];
        require(_payment.status == PaymentStatus.Deposit,"Need to deposit funds first !!");
        _payment.status = PaymentStatus.GoodsSent;
        emit PaymentGoodsSent(_orderId, _payment);
    }

    function goodsReceived(uint _orderId) external onlyBuyer(_orderId){
        Payment storage _payment = agrements[_orderId];
        require(_payment.status == PaymentStatus.GoodsSent,"Goods have not been sent");
        _payment.status = PaymentStatus.GoodsReceived;
        // here we tell the curreny that the seller can ONLY have 'value' funds.
        tokenccy.safeApprove(_payment.seller,_payment.value);//,"Can not approve sellers funds !!");
        emit PaymentGoodsReceived(_orderId, _payment);
        
        uint256 _totalFees = _payment.fee  + _payment.additionalGasFees;
        feesAvailable += _totalFees;
        tokenccy.safeTransfer( _payment.seller, _payment.value );
        _payment.status = PaymentStatus.Completed;
        emit PaymentComplete(_orderId, _payment);
    }

     /// release funds to the seller
    function paySeller(uint _orderId) external {
        Payment storage _payment = agrements[_orderId];
        require(msg.sender == owner(),"Only Owner can release funds ");
        require( _payment.status == PaymentStatus.GoodsReceived,"Goods have not been received");
        uint256 _totalFees = _payment.fee  + _payment.additionalGasFees;
        feesAvailable += _totalFees;
        tokenccy.safeTransfer( _payment.seller, _payment.value );
        _payment.status = PaymentStatus.Completed;
        emit PaymentComplete(_orderId, _payment);
    }

    function withdrawFees(address payable _to, uint256 _amount) external payable {
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
        agrements[_orderId].additionalGasFees += _gas * uint128(tx.gasprice);
    }

    function notImplementedYet() pure private {
        require(1!=2,"Not Implemented Yet!!"); // stop compiler warning until we implement
    }

}

