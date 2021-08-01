
const usdt = artifacts.require("USDTToken");
const escrow = artifacts.require("TinanceEscrow");
const truffleAssert = require('truffle-assertions');

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

    it("Test Happy path Escrow ", async() => {
     const ORDER_ID = 1234;
     let usdtInstance = await usdt.deployed();
      let escrowInstance = await escrow.deployed();
      // console.log("Seller approve funds");
      await usdtInstance.approve(escrowInstance.address,10100,{from: seller});     
      let balSell = await usdtInstance.balanceOf.call(seller);
      let balBuy = await usdtInstance.balanceOf.call(buyer);
      await escrowInstance.createEscrow(ORDER_ID,buyer,accounts[1],10100,1,1,{from: owner});      
      console.log("Created contract "+ORDER_ID+" OK");
      assert.equal(await escrowInstance.getState(ORDER_ID),1,"Contract should not exist!!");
      assert.equal(await escrowInstance.getValue(ORDER_ID),10100,"Contract value is wrong");
      // let val = await escrowInstance.getValue(ORDER_ID); 
      // console.log("Contract val "+val);

      await escrowInstance.releaseEscrow(ORDER_ID,{from: seller});

      let newBalSell = await usdtInstance.balanceOf.call(seller);
      let newBalBuy = await usdtInstance.balanceOf.call(buyer);
      console.log("Seller bal "+balSell+" new bal"+newBalSell+" diff:"+(newBalSell-balSell));
      console.log("Buyer bal "+balBuy+" new bal"+newBalBuy+" diff:"+(newBalBuy-balBuy));
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

       assert.equal(await escrowInstance.getState(ORDER_ID),0,"Contract should not exist!!");
 
       //await escrowInstance.releaseEscrow(ORDER_ID,{from: seller});
 
       let newBalSell = await usdtInstance.balanceOf.call(seller);
       let newBalBuy = await usdtInstance.balanceOf.call(buyer);
       console.log("Seller bal "+balSell+" new bal"+newBalSell+" diff:"+(newBalSell-balSell));
       console.log("Buyer bal "+balBuy+" new bal"+newBalBuy+" diff:"+(newBalBuy-balBuy));
     });

    it("Test Refund Escrow ", async() => {
      const ORDER_ID = 5555;
      let usdtInstance = await usdt.deployed();
      let escrowInstance = await escrow.deployed();
      // console.log("Seller approve funds");
      await usdtInstance.approve(escrowInstance.address,10100,{from: seller}); 
      let balSell = await usdtInstance.balanceOf.call(seller);
      let balBuy = await usdtInstance.balanceOf.call(buyer);
      await escrowInstance.createEscrow(ORDER_ID,buyer,accounts[1],10100,1,1,{from: owner});      
      console.log("Created contract "+ORDER_ID+" OK");
      let val = await escrowInstance.getValue(ORDER_ID); 
      console.log("Contract val "+val);

      // excrow is CANCELLED HERE

      await escrowInstance.approveRefund(ORDER_ID,{from: owner});
      // try to release but fail!!
      //await escrowInstance.releaseEscrow(ORDER_ID,{from: seller});

      await escrowInstance.refundSeller(ORDER_ID,{from: owner});

      let newBalSell = await usdtInstance.balanceOf.call(seller);
      let newBalBuy = await usdtInstance.balanceOf.call(buyer);
      console.log("Seller bal "+balSell+" new bal"+newBalSell+" diff:"+(newBalSell-balSell));
      console.log("Buyer bal "+balBuy+" new bal"+newBalBuy+" diff:"+(newBalBuy-balBuy));
    });

    it("Test Arbitration Escrow ", async() => {
     const ORDER_ID = 8877;
     const buyerPct = 10;
     let usdtInstance = await usdt.deployed();
     let escrowInstance = await escrow.deployed();
     // console.log("Seller approve funds");
     await usdtInstance.approve(escrowInstance.address,22200,{from: seller}); 
     let balSell = await usdtInstance.balanceOf.call(seller);
     let balBuy = await usdtInstance.balanceOf.call(buyer);
     await escrowInstance.createEscrow(ORDER_ID,buyer,accounts[1],22200,2,2,{from: owner});      
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
