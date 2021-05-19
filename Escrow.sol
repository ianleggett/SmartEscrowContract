// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import "./../../openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "./../../openzeppelin-contracts/contracts/access/Ownable.sol";

contract Escrow is Ownable {

    event PaymentCreation(uint indexed orderId, address indexed buyer, uint value);
    event PaymentAgreed(uint indexed orderId,Payment payment);
    event PaymentDeposit(uint indexed orderId,Payment payment);
    event PaymentFail(uint indexed orderId,Payment payment);
    event PaymentGoodsReceived(uint indexed orderId,Payment payment);
    event PaymentComplete(uint indexed orderId, Payment payment);

    enum PaymentStatus { Unknown, Created, Agreed, Deposit, GoodsSent, GoodsReceived, Completed, RequestCancel, CancelAgreed, Refunded, Arbitration, Error }

    /// Only the buyer can call this function.
    //error OnlyBuyer();
    /// Only the seller can call this function.
    //error OnlySeller();
    /// The function cannot be called at the current state.
    error InvalidState();

    error FailedPayment(string);

    uint256 public feesAvailable;  // summation of fees that can be withdrawn

    struct Payment {
        address payable buyer;
        address payable seller;
        uint256 value;
        uint128 additionalGasFees;
        uint16 fee;
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
        Payment storage _payment = agrements[_orderId];
        return _payment.status;
    }

    function getContractBalance() public view returns (uint256){
        return currency.balanceOf(address(this));
    }

    function getAllowance(uint _orderId) public view returns (uint256){
        Payment storage _payment = agrements[_orderId];
        return currency.allowance(_payment.buyer,address(this));
    }

    function getVersion() public pure returns (string memory){
        return "Escrow V1.05";
    }

    mapping(uint => Payment) public agrements;
    IERC20 public currency;

    constructor(IERC20 _currency) Ownable() {
        currency = _currency;
    }

    function createPayment(uint _orderId, address payable _buyer, address payable _seller, uint _value, uint16 _fee, uint32 _expiry) external onlyOwner {
        Payment storage _payment = agrements[_orderId];
        require(_payment.status==PaymentStatus.Unknown, "Agreement already exists");
        agrements[_orderId] = Payment(_buyer, _seller, _value, /*addtl gas*/0, _fee, _expiry, PaymentStatus.Created, false);
        emit PaymentCreation(_orderId, _buyer, _value);
    }
/**
    Buyer agrees and deposits the amount of funds agreed
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
    function deposit(uint _orderId) external payable onlyBuyer(_orderId) {
        Payment storage _payment = agrements[_orderId];
        require(_payment.status!=PaymentStatus.Unknown, "Agreement does not exist");
        // buyer must approve the value amount beforehand in Dapp
        // how much has the buyer allowed us to get
        require(currency.allowance(_payment.buyer,address(this)) >= _payment.value,"Buyer needs to approve funds to Escrow first !!");
        if (currency.transferFrom(_payment.buyer,payable(address(this)),_payment.value)){
            _payment.status =  PaymentStatus.Deposit;
            emit PaymentDeposit(_orderId, _payment);
        }else{
            emit PaymentFail(_orderId, _payment);
            revert FailedPayment("Failed");
        }
    }

    function goodsSent(uint _orderId) external onlySeller(_orderId){
        Payment storage _payment = agrements[_orderId];
        require(_payment.status == PaymentStatus.Deposit,"Need to deposit funds first !!");
        _payment.status = PaymentStatus.GoodsSent;
        emit PaymentGoodsReceived(_orderId, _payment);
    }

    function goodsReceived(uint _orderId) external onlyBuyer(_orderId){
        Payment storage _payment = agrements[_orderId];
        require(_payment.status == PaymentStatus.GoodsSent,"Goods have not been sent");
        _payment.status = PaymentStatus.GoodsReceived;
        // here we tell the curreny that the seller can ONLY have 'value' funds.
        require(currency.approve(_payment.seller,_payment.value),"Can not approve sellers funds !!");
        emit PaymentGoodsReceived(_orderId, _payment);
    }

     /// release funds to the seller
    function paySeller(uint _orderId) external payable {
        Payment storage _payment = agrements[_orderId];
        require(msg.sender == owner(),"Only Owner can release funds ");
        require( _payment.status == PaymentStatus.GoodsReceived,"Goods have not been received");
        uint256 _totalFees = _payment.fee; // + _payment.additionalGasFees;
        feesAvailable += _totalFees;
        currency.transfer(_payment.seller, _payment.value - _totalFees);
        _payment.status = PaymentStatus.Completed;
        emit PaymentComplete(_orderId, _payment);
    }

    function withdrawFees(address payable _to, uint256 _amount) external payable {
        // This check also prevents underflow
        require(_amount <= feesAvailable, "Amount is higher than amount available");
        feesAvailable -= _amount;
        payable(_to).transfer(_amount);
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
