// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "/home/ian/work/crypto/openzeppelin-contracts/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";

contract USDTToken is ERC20PresetFixedSupply {
 		
    function decimals() public view virtual override returns (uint8) {
        return 2;
    }
    		      
    constructor() ERC20PresetFixedSupply("USDT clone local ver","USDT",500000,msg.sender) {
    
    }

}
