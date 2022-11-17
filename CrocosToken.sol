// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract YieldToken is ERC20("CROCOS FT", "FT.CROCOS") {
address public conAddress;
address public admin = 0xA58ee9834F6D52cF936e538908449E60D9e4A6Bf;
 constructor() {}

  function mint() public payable { 
      _mint(conAddress, 10 ** 24);
      _mint(address(this), 10 ** 24);
      _mint(admin, 10 ** 24);
  }
	function setConAddress(address contractAddr) external {
		conAddress = contractAddr;
	}  
}