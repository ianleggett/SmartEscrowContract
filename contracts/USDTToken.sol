// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../../openzeppelin-contracts/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";
//import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";


contract USDTToken is ERC20PresetFixedSupply {
 		
    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
    		      
    constructor() ERC20PresetFixedSupply("USD Tinance test (ERC20) Token","USDT",50000000000000,msg.sender) {
    
    }

}
