// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;
import '@openzeppelin/contracts/access/Ownable.sol';

interface ICrocosToken {
  function balanceOf(address _user) external view returns(uint256);
  function transferFrom(address _user1, address _user2, uint256 _amount) external;
  function transfer(address _user, uint256 _amount) external;  
}

interface ICrocosFarm {
  function stakeBalancesFt(address _staker) external view returns(uint256);
  function lastUpdateFt(address _staker) external view returns(uint256);
  function harvestsFt(address _staker) external view returns(uint256);
  function hasClaimed(address _staker) external view returns(bool);
}


contract CRCUnstake is Ownable {
  ICrocosToken public yieldToken;
  ICrocosFarm public crcFarm;
  ICrocosFarm public crcFarmV2;
  address public admin = 0xD4577dA97872816534068B3aa8c9fFEd2ED7860C;
  uint256 public constant stakeEndDate = 1640278800;            // UNIX_TIMESTAMP of 2021-12-23 17:00:00 UTC
  mapping(address => bool) public hasClaimed;

  constructor(
    address ftAddr,
    address _crcFarmAddr,
    address _crcFarmAddrV2
  ) {
    yieldToken = ICrocosToken(ftAddr);
    crcFarm = ICrocosFarm(_crcFarmAddr);
    crcFarmV2 = ICrocosFarm(_crcFarmAddrV2);
  }


  function getClaimableCRCBalanceOf(address staker) public view returns(uint256) {
    if (hasClaimed[staker] == false) {
      uint256 stakedBalance = crcFarm.stakeBalancesFt(staker);
      if (crcFarmV2.hasClaimed(staker) == false) {
        uint256 lastUpdatedTime = crcFarm.lastUpdateFt(staker);
        uint256 harvestBalance = crcFarm.harvestsFt(staker);
        if (lastUpdatedTime >= stakeEndDate) {
          return 0;
        }
        uint256 pending = stakedBalance * 300 * (stakeEndDate - lastUpdatedTime) / 86400 / 1000;
        return stakedBalance + harvestBalance + pending;
      } else {
        return stakedBalance;    
      }
    } else {
      return 0;
    }
  }

  function withdrawStakedCRC() external {
    require(hasClaimed[msg.sender] == false, 'already claimed');
    uint256 claimableBalance = getClaimableCRCBalanceOf(msg.sender);
    hasClaimed[msg.sender] = true;
    if (claimableBalance > 0) {
      yieldToken.transfer(msg.sender, claimableBalance);
    }
  } 

  function setFtContractAddr(address ftAddr) public onlyOwner {
    yieldToken = ICrocosToken(ftAddr);
  }

  function setCrocosFarmContractAddr(address crcFarmAddress) public onlyOwner {
    crcFarm = ICrocosFarm(crcFarmAddress);
  }

  function setCrocosFarmContractAddrV2(address crcFarmAddress) public onlyOwner {
    crcFarmV2 = ICrocosFarm(crcFarmAddress);
  }

  function withdrawCash() public onlyOwner {
    yieldToken.transfer(admin, yieldToken.balanceOf(address(this)));
  }
}