// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

//import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/token/ERC20/utils/SafeERC20.sol";
//import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/access/Ownable.sol";

// local build
import "../../openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../openzeppelin-contracts/contracts/access/Ownable.sol";


contract TinanceEscrowV2 is Ownable {
    
    event EscrowDeposit(uint indexed orderId,Escrow escrow);
    event EscrowComplete(uint indexed orderId, Escrow escrow);
    event EscrowDisputeResovled(uint indexed orderId);

    enum EscrowStatus { Unknown, Funded, NOT_USED, Completed, Refund, Arbitration }

    uint256 public feesAvailable;  // summation of fees that can be withdrawn
    
     struct Escrow {
        address payable buyer;
        address payable seller;
        uint256 value;        
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
        return "Escrow V2.0";
    }
    
    function getFeesAvailable() public view onlyOwner returns (uint256){
        return feesAvailable;
    }
    /* This is called by the server / contract owner */
    function createEscrow(uint _orderId, address payable _buyer, address payable _seller, uint _value, uint _sellerfee, uint _buyerfee) external onlyOwner {
        require(escrows[_orderId].status == EscrowStatus.Unknown, "Escrow already exists");
        
        //Transfer USDT to contract after escrow creation
        require( tokenccy.allowance( _seller, address(this)) >= (_value),"Seller approve to Escrow first");
        
        tokenccy.safeTransferFrom(_seller, address(this) , (_value) );
        escrows[_orderId] = Escrow(_buyer, _seller, _value, _sellerfee, _buyerfee, EscrowStatus.Funded);

        emit EscrowDeposit(_orderId, escrows[_orderId]);
     }
    /* This is called by the sellers wallet */
    function releaseEscrow(uint _orderId) external onlySeller(_orderId){            
        require(escrows[_orderId].status == EscrowStatus.Funded,"USDT has not been deposited");                
        
        uint256 _totalFees = escrows[_orderId].sellerfee + escrows[_orderId].buyerfee;
        feesAvailable += _totalFees;  // needed for transfer value below

        // write as complete, in case transfer fails              
        escrows[_orderId].status = EscrowStatus.Completed;
        
        tokenccy.safeTransfer( escrows[_orderId].buyer, (escrows[_orderId].value - _totalFees) );
        emit EscrowComplete(_orderId,  escrows[_orderId]);
        delete escrows[_orderId];        
    }

    function approveRefund(uint _orderId) external onlyOwner {        
        require(escrows[_orderId].status == EscrowStatus.Funded,"USDT has not been deposited");
         escrows[_orderId].status = EscrowStatus.Refund;        
    }

     /// release funds to the seller - cancelled contract
    function refundSeller(uint _orderId) external onlyOwner {       
        require(escrows[_orderId].status == EscrowStatus.Refund,"Refund not approved");        
                
        // dont charge seller any fees - because its a refund
         
        tokenccy.safeTransfer(escrows[_orderId].seller, escrows[_orderId].value);
        
        delete escrows[_orderId];
        emit EscrowDisputeResovled(_orderId);
     }

    function setArbitration(uint _orderId) external onlyOwner {        
        require(escrows[_orderId].status == EscrowStatus.Funded,"Can not Arbitrate, USDT has not been deposited");
        escrows[_orderId].status = EscrowStatus.Arbitration;        
    }

     /// release funds to the seller/buyer in case of dispute
    function arbitrationEscrow(uint _orderId, uint8 _buyerPercent) external onlyOwner {
        require( (_buyerPercent >= 0 && _buyerPercent <= 100),"Buyer percent out of range");
        Escrow memory _escrow = escrows[_orderId];
        require(_escrow.status == EscrowStatus.Arbitration,"Must be in Arbitrate state");
        
        uint256 _totalFees = _escrow.sellerfee  + _escrow.buyerfee /*+ _escrow.additionalGasFees*/;
        feesAvailable += _totalFees; // deduct fees for arbitration
        
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
        require(_amount <= feesAvailable, "Amount > feesAvailable");
        feesAvailable -= _amount;
        tokenccy.safeTransfer( _to, _amount );
    }

}
