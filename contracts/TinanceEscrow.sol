// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

//import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/token/ERC20/utils/SafeERC20.sol";
//import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/access/Ownable.sol";

// local build
import "../../openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../openzeppelin-contracts/contracts/access/Ownable.sol";


contract TinanceEscrow is Ownable {
    
    event EscrowCreation(uint indexed orderId, address indexed buyer, uint value);
    event EscrowAgreed(uint indexed orderId,Escrow escrow);
    event EscrowDeposit(uint indexed orderId,Escrow escrow);
    event EscrowFail(uint indexed orderId,Escrow escrow);
    event EscrowTokenSent(uint indexed orderId,Escrow escrow);
    event EscrowTokenReceived(uint indexed orderId,Escrow escrow);
    event EscrowComplete(uint indexed orderId, Escrow escrow);
    event EscrowRefund(uint indexed orderId);
    event EscrowDisputeResovled(uint indexed orderId);

    enum EscrowStatus { Unknown, Funded, TokenApproved, Completed, Refund, Arbitration }

    uint256 public feesAvailable;  // summation of fees that can be withdrawn
    
     struct Escrow {
        address payable buyer;
        address payable seller;
        uint256 value;
        uint128 additionalGasFees;
        uint256 sellerfee;
        uint256 buyerfee;
        EscrowStatus status;              
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
    
    function getSellerFee(uint _orderId) public view returns (uint256){
        Escrow memory _escrow = escrows[_orderId];
        return _escrow.sellerfee;
    }
    
    function getBuyerFee(uint _orderId) public view returns (uint256){
        Escrow memory _escrow = escrows[_orderId];
        return _escrow.buyerfee;
    }
    
    function getAllowance(uint _orderId) public view returns (uint256){
        Escrow memory _escrow = escrows[_orderId];
        return tokenccy.allowance(_escrow.seller,address(this));
    }

    function getVersion() public pure returns (string memory){
        return "Escrow V1.199";
    }

    function getCCY() public view returns (IERC20){
        return tokenccy;
    }
    
    function getFeesAvailable() public view onlyOwner returns (uint256){
        return feesAvailable;
    }

    function createEscrow(uint _orderId, address payable _buyer, address payable _seller, uint _value, uint _sellerfee, uint _buyerfee) external onlyOwner {
        require(escrows[_orderId].status == EscrowStatus.Unknown, "Escrow already exists");
        
        //Transfer USDT to contract after escrow creation
        require( tokenccy.allowance( _seller, address(this)) >= (_value + _sellerfee),"Seller needs to approve funds to Escrow first !!");
        
        tokenccy.safeTransferFrom(_seller, address(this) , (_value + _sellerfee) );
        Escrow memory _escrow =  Escrow(_buyer, _seller, _value, /*gas*/0, _sellerfee, _buyerfee, EscrowStatus.Funded);         
        escrows[_orderId] = _escrow;
        tokenccy.safeApprove(_escrow.buyer,0); // reset any allowances

        emit EscrowDeposit(_orderId, _escrow);
     }

    function releaseEscrow(uint _orderId) external onlySeller(_orderId){ 
         Escrow memory _escrow = escrows[_orderId];     
        require(escrows[_orderId].status == EscrowStatus.Funded,"USDT has not been deposited");         
        _escrow.status = EscrowStatus.TokenApproved;
        
        uint256 _totalFees = _escrow.buyerfee + _escrow.additionalGasFees; // _escrow.sellerfee already taken
        feesAvailable += _totalFees;
        
        // here we tell the curreny that the buyer can ONLY have 'value' funds.
        tokenccy.safeApprove(_escrow.buyer,(_escrow.value - _totalFees));
        
        require(_escrow.status == EscrowStatus.TokenApproved,"USDT has not been approved!");
        _escrow.status = EscrowStatus.Completed;
        
        tokenccy.safeTransfer( _escrow.buyer, (_escrow.value - _totalFees) );
        delete escrows[_orderId];
        emit EscrowComplete(_orderId, _escrow);
    }

    function approveRefund(uint _orderId) external onlyOwner {
        Escrow memory _escrow = escrows[_orderId];
        require(_escrow.status == EscrowStatus.Funded,"USDT has not been deposited");
         _escrow.status = EscrowStatus.Refund;
         escrows[_orderId] = _escrow;
    }

     /// release funds to the seller - cancelled contract
    function refundSeller(uint _orderId) external onlyOwner {
        Escrow memory _escrow = escrows[_orderId];
        require(_escrow.status == EscrowStatus.Refund,"Refund not approved");        
                
        // dont charge seller any fees - because its a refund
        uint256 _totalFees = _escrow.additionalGasFees;
        feesAvailable += _totalFees; // arb deduct fees , full refund no fees // arbfee 0.2%
        uint256 amtReturn = (_escrow.value + _escrow.sellerfee - _totalFees);
         
        if (amtReturn > 0){
            tokenccy.safeTransfer(_escrow.seller, amtReturn);
        }
        delete escrows[_orderId];
        emit EscrowDisputeResovled(_orderId);
     }

    function setArbitration(uint _orderId) external onlyOwner {
        Escrow memory _escrow = escrows[_orderId];
        require(_escrow.status == EscrowStatus.Funded,"Can not Arbitrate, USDT has not been deposited");
         _escrow.status = EscrowStatus.Arbitration;
        escrows[_orderId] = _escrow;
    }

     /// release funds to the seller/buyer in case of dispute
    function arbitrationEscrow(uint _orderId, uint8 _buyerPercent) external onlyOwner {
        require( (_buyerPercent >= 0 && _buyerPercent <= 100),"Buyer percent out of range");
        Escrow memory _escrow = escrows[_orderId];
        require(_escrow.status == EscrowStatus.Arbitration,"Must be in Arbitrate state");
        
        uint256 _totalFees = _escrow.buyerfee + _escrow.additionalGasFees; // _escrow.sellerfee already taken
        feesAvailable += _totalFees; // arb deduct fees , full refund no fees
        
        uint256 amtReturn = (_escrow.value - _totalFees);
        uint256 amtBuyer = (amtReturn * _buyerPercent) / 100;
        uint256 amtSeller = amtReturn - amtBuyer;
        if (amtBuyer > 0){
            tokenccy.safeTransfer(_escrow.buyer, amtBuyer);
        }
        if (amtSeller > 0){
            tokenccy.safeTransfer(_escrow.seller, amtSeller);
        }
        delete escrows[_orderId];
        emit EscrowDisputeResovled(_orderId);
     }

    function withdrawFees(address payable _to, uint256 _amount) external onlyOwner {
        // This check also prevents underflow
        require(_amount <= feesAvailable, "Amount is higher than feesAvailable");
        feesAvailable -= _amount;
        tokenccy.safeTransfer( _to, _amount );
    }

    /// TO DO: Implement this, remove 'pure' and require() to stop compiler warnings
    // function refund(uint _orderId) pure external {
    //     require(_orderId!=_orderId,"Not Implemented Yet!!"); // stop compiler warning until we implement
    //     //Payment storage _payment = agrements[_orderId];
    //     //refundPayment(_orderId, msg.sender, PaymentStatus.Refunded);
    // }

    /// TO DO: Implement this, remove 'pure' and require() to stop compiler warnings
    // function approveRefund(uint _orderId) pure external {
    //     require(_orderId!=_orderId,"Not Implemented Yet!!"); // stop compiler warning until we implement
    //     // Payment storage _payment = agrements[_orderId];
    //     // require(msg.sender == _payment.seller);
    //     // _payment.refundApproved = true;
    // }

    function increaseGasCosts(uint _orderId, uint128 _gas) private {
        escrows[_orderId].additionalGasFees += _gas * uint128(tx.gasprice);
    }

    function notImplementedYet() pure private {
        require(1!=2,"Not Implemented Yet!!"); // stop compiler warning until we implement
    }

}
