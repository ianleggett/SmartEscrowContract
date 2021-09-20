
const usdt = artifacts.require("USDTToken");
const escrow = artifacts.require("TinanceEscrowV2");
const truffleAssert = require('truffle-assertions');

//enum EscrowStatus { Unknown, Funded, Completed, Refund, Arbitration }
const STATES = {UNKNOWN:0,FUNDED:1,NOT_USED:2,COMPLETED:3,REFUND:4,ARBITRATION:5}
//const STATES = {UNKNOWN:0,FUNDED:1,TOKENAPP:2,COMPLETED:3,REFUND:4,ARBITRATION:5}

contract("USDTToken", accounts => {

     let owner = accounts[0];
     let seller = accounts[1];
     let buyer = accounts[2];

  it("Test USDT Token", () =>
  usdt.deployed()
    .then(instance => instance.balanceOf.call(owner))    
    .then(balance => {
         console.log("Owner Balance :" + balance);
        })
      )

   it("Test USDT transfer", () =>
   usdt.deployed()
      .then(instance => {
           instance.transfer(seller,100000);   // move from owner to seller       
      })
   )

   it("Test Seller Token", () =>
   usdt.deployed()
    .then(instance => instance.balanceOf.call(seller))    
    .then(balance => {
         console.log("Seller Balance :" + balance);
        }) 
   )

  //  it("Test Escrow Create ", () =>
  //  usdt.deployed()    
  //   .then( instance => {
  //       escrow(instance.address).deployed().then(
  //           instance2 => console.log("Escrow deployed " + instance2.address)
  //     )        
  //    }) 
  //  )

    it("Test Happy path Escrow ", async() => {
      const ORDER_ID = 1234;
      const CTR_VAL  = 1322;
      const SELL_FEE = 21;
      const BUY_FEE  = 31;
      let usdtInstance = await usdt.deployed();
      console.log("Deployed USDT "+usdtInstance.address+" OK");
      let escrowInstance = await escrow.deployed();
      console.log("Deployed Escrow "+escrowInstance.address+" OK");
      // console.log("Seller approve funds");
      await usdtInstance.approve(escrowInstance.address,CTR_VAL + SELL_FEE,{from: seller});     
      let balSell = await usdtInstance.balanceOf.call(seller);
      let balBuy = await usdtInstance.balanceOf.call(buyer);
      await escrowInstance.createEscrow(ORDER_ID,buyer,accounts[1],CTR_VAL + SELL_FEE,SELL_FEE,BUY_FEE,{from: owner}); 
      console.log("Created contract "+ORDER_ID+" OK");
      assert.equal(await escrowInstance.getState(ORDER_ID),STATES.FUNDED,"Contract should not exist!!");
      assert.equal(await escrowInstance.getValue(ORDER_ID),CTR_VAL + SELL_FEE,"Contract value is wrong");
      // let val = await escrowInstance.getValue(ORDER_ID); 
      // console.log("Contract val "+val);

      await escrowInstance.releaseEscrow(ORDER_ID,{from: seller});

      let newBalSell = await usdtInstance.balanceOf.call(seller);
      let newBalBuy = await usdtInstance.balanceOf.call(buyer);
      console.log("Seller bal "+balSell+" new bal"+newBalSell+" diff:"+(newBalSell-balSell));
      console.log("Buyer bal "+balBuy+" new bal"+newBalBuy+" diff:"+(newBalBuy-balBuy));
      assert.equal(newBalSell-balSell,-(CTR_VAL + SELL_FEE),"Should have taken funds!!");
      assert.equal(newBalBuy-balBuy,CTR_VAL- BUY_FEE,"Should have Added funds!!");
    });

    it("Test Fail seller lack of funds", async() => {
      const ORDER_ID = 8989;
      let usdtInstance = await usdt.deployed();
       let escrowInstance = await escrow.deployed();
       // console.log("Seller approve funds");
       await usdtInstance.approve(escrowInstance.address,999901,{from: seller});     
       let balSell = await usdtInstance.balanceOf.call(seller);
       let balBuy = await usdtInstance.balanceOf.call(buyer);
       await truffleAssert.reverts( 
         escrowInstance.createEscrow(ORDER_ID,buyer,accounts[1],999900,1,1,{from: owner}),
         "ERC20: transfer amount exceeds balance"
       ); 

       assert.equal(await escrowInstance.getState(ORDER_ID),STATES.UNKNOWN,"Contract should not exist!!");
 
       //await escrowInstance.releaseEscrow(ORDER_ID,{from: seller});
 
       let newBalSell = await usdtInstance.balanceOf.call(seller);
       let newBalBuy = await usdtInstance.balanceOf.call(buyer);
       console.log("Seller bal "+balSell+" new bal"+newBalSell+" diff:"+(newBalSell-balSell));
       console.log("Buyer bal "+balBuy+" new bal"+newBalBuy+" diff:"+(newBalBuy-balBuy));
     });

    it("Test Refund Escrow ", async() => {
      const ORDER_ID = 5555;
      const CTR_VAL  = 2312;
      const SELL_FEE = 23;
      const BUY_FEE  = 54;
      let usdtInstance = await usdt.deployed();
      let escrowInstance = await escrow.deployed();
      // console.log("Seller approve funds");
      await usdtInstance.approve(escrowInstance.address,CTR_VAL+SELL_FEE,{from: seller}); 
      let balSell = await usdtInstance.balanceOf.call(seller);
      let balBuy = await usdtInstance.balanceOf.call(buyer);
      await escrowInstance.createEscrow(ORDER_ID,buyer,accounts[1],CTR_VAL + SELL_FEE,SELL_FEE,BUY_FEE,{from: owner});      
      assert.equal(await escrowInstance.getState(ORDER_ID),STATES.FUNDED,"Contract should exist!!");
      assert.equal(await escrowInstance.getValue(ORDER_ID),CTR_VAL + SELL_FEE,"Contract value is wrong");

      // excrow is CANCELLED HERE

      await escrowInstance.approveRefund(ORDER_ID,{from: owner});
      assert.equal(await escrowInstance.getState(ORDER_ID),STATES.REFUND,"Contract should be in refund");
      // try to release but fail!!
      //await escrowInstance.releaseEscrow(ORDER_ID,{from: seller});

      await escrowInstance.refundSeller(ORDER_ID,{from: owner});

      let newBalSell = await usdtInstance.balanceOf.call(seller);
      let newBalBuy = await usdtInstance.balanceOf.call(buyer);
      console.log("Seller bal "+balSell+" new bal"+newBalSell+" diff:"+(newBalSell-balSell));
      console.log("Buyer bal "+balBuy+" new bal"+newBalBuy+" diff:"+(newBalBuy-balBuy));
      assert.equal(newBalSell-balSell,0);
      assert.equal(newBalBuy-balBuy,0);
    });

    it("Test Arbitration Escrow ", async() => {
     const ORDER_ID = 8877;
     const buyerPct = 10;
     const CTR_VAL  = 1345;
     const SELL_FEE = 12;
     const BUY_FEE  = 34;
     let usdtInstance = await usdt.deployed();
     let escrowInstance = await escrow.deployed();
     // console.log("Seller approve funds");
     await usdtInstance.approve(escrowInstance.address,CTR_VAL+SELL_FEE,{from: seller}); 
     let balSell = await usdtInstance.balanceOf.call(seller);
     let balBuy = await usdtInstance.balanceOf.call(buyer);
     await escrowInstance.createEscrow(ORDER_ID,buyer,accounts[1],CTR_VAL + SELL_FEE,SELL_FEE,BUY_FEE,{from: owner});      
     console.log("Created contract "+ORDER_ID+" OK");
     let val = await escrowInstance.getValue(ORDER_ID); 
     console.log("Contract val "+val);

     // excrow is CANCELLED HERE

     await escrowInstance.setArbitration(ORDER_ID,{from: owner});
     // try to release but fail!!
    // escrowInstance.releaseEscrow(ORDER_ID,{from: seller});
     await truffleAssert.reverts( 
       escrowInstance.releaseEscrow(ORDER_ID,{from: seller}) ,
        "USDT has not been deposited"
       );     

     await escrowInstance.arbitrationEscrow(ORDER_ID,buyerPct,{from: owner});

     let newBalSell = await usdtInstance.balanceOf.call(seller);
     let newBalBuy = await usdtInstance.balanceOf.call(buyer);
     console.log("Seller bal "+balSell+" new bal"+newBalSell+" diff:"+(newBalSell-balSell));
     console.log("Buyer bal "+balBuy+" new bal"+newBalBuy+" diff:"+(newBalBuy-balBuy));
   });


});
