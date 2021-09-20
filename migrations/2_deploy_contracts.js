var usdt = artifacts.require("USDTToken");
var escrow = artifacts.require("TinanceEscrowV2");

module.exports = async(deployer, network, accounts) => {
 // deployer.deploy(Ctr);  
  if (network=='development'){
     let dep_usdt = await deployer.deploy(usdt); 
//     console.log("Deployed usdt at "+usdt.address)    
     let dep_escr = await deployer.deploy(escrow,usdt.address);    
     console.log("Deployed USDT at "+usdt.address)
     console.log("Deployed escrow at "+escrow.address)

  }else if (network=='kovan'){
     deployer.deploy(escrow,"0x07CFFa50ab289DE260D03F24af9ba6b6560F6f40");
  }
 
};
