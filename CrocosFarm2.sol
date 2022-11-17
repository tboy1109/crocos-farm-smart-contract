// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;
import '@openzeppelin/contracts/access/Ownable.sol';
interface ICrocosNFT {
  function balanceOf(address _user) external view returns(uint256);
  function transferFrom(address _user1, address _user2, uint256 _tokenId) external;
  function ownerOf(uint256 _tokenId) external returns(address);
}

interface ICrocosToken {
  function balanceOf(address _user) external view returns(uint256);
  function transferFrom(address _user1, address _user2, uint256 _amount) external;
  function transfer(address _user, uint256 _amount) external;  
}

interface ICrocosFarm {
  function stakeBalancesFt(address _staker) external view returns(uint256);
  function lastUpdateFt(address _staker) external view returns(uint256);
  function harvestsFt(address _staker) external view returns(uint256);
}


contract CrocosFarm2 is Ownable {
  ICrocosNFT public crocosNft;
  ICrocosToken public yieldToken;
  ICrocosFarm public crcFarm;
  address public admin = 0xD4577dA97872816534068B3aa8c9fFEd2ED7860C;
  uint256 public constant dailyReward = 400 ether * 12 / 1000;  //1.2% of 400 ftm
  uint256 public constant stakeEndDate = 1608656400;            // UNIX_TIMESTAMP of 2021-12-23 17:00:00 UTC

  mapping(address => uint256) public harvests;
  mapping(address => uint256) public lastUpdate;
  mapping(uint => address) public ownerOfToken;
  mapping(address => uint) public stakeBalances;
  mapping(address => mapping(uint256 => uint256)) public ownedTokens;
  mapping(uint256 => uint256) public ownedTokensIndex;

  mapping(address => bool) public hasClaimed;

  constructor(
    address nftAddr,
    address ftAddr,
    address _crcFarmAddr
  ) {
    crocosNft = ICrocosNFT(nftAddr);
    yieldToken = ICrocosToken(ftAddr);
    crcFarm = ICrocosFarm(_crcFarmAddr);
  }

  function batchStake(uint[] memory tokenIds) external payable {
    updateHarvest();
    for (uint256 i = 0; i < tokenIds.length; i++) {
      require(crocosNft.ownerOf(tokenIds[i]) == msg.sender, 'you are not owner!');
      ownerOfToken[tokenIds[i]] = msg.sender;
      crocosNft.transferFrom(msg.sender, address(this), tokenIds[i]);
      _addTokenToOwner(msg.sender, tokenIds[i]);
      stakeBalances[msg.sender]++;
    }
  }

  function batchWithdraw(uint[] memory tokenIds) external payable {    
    harvest();
    for (uint i = 0; i < tokenIds.length; i++) {
      require(ownerOfToken[tokenIds[i]] == msg.sender, "CrocosFarm: Unable to withdraw");
      crocosNft.transferFrom(address(this), msg.sender, tokenIds[i]);
      _removeTokenFromOwner(msg.sender, tokenIds[i]);
      stakeBalances[msg.sender]--;
    }
  }

  function updateHarvest() internal {
    uint256 time = block.timestamp;
    uint256 timerFrom = lastUpdate[msg.sender];
    if (timerFrom > 0)
      // harvests[msg.sender] += stakeBalances[msg.sender] * dailyReward * (time - timerFrom) / 864000;
      harvests[msg.sender] += stakeBalances[msg.sender] * dailyReward * (time - timerFrom) / 86400;
    lastUpdate[msg.sender] = time;
  }

  function harvest() public payable {
    updateHarvest();
    uint256 reward = harvests[msg.sender];
    if (reward > 0) {
      yieldToken.transfer(msg.sender, harvests[msg.sender]);
      harvests[msg.sender] = 0;
    }
  }

  function stakeOfOwner(address _owner)
  public
  view
  returns(uint256[] memory)
  {
    uint256 ownerTokenCount = stakeBalances[_owner];
    uint256[] memory tokenIds = new uint256[](ownerTokenCount);
    for (uint256 i; i < ownerTokenCount; i++) {
      tokenIds[i] = ownedTokens[_owner][i];
    }
    return tokenIds;
  }

  function getTotalClaimable(address _user) external view returns(uint256) {
    uint256 time = block.timestamp;
    uint256 pending = stakeBalances[msg.sender] * dailyReward * (time - lastUpdate[_user]) / 86400;
    return harvests[_user] + pending;
  }

  function _addTokenToOwner(address to, uint256 tokenId) private {
      uint256 length = stakeBalances[to];
    ownedTokens[to][length] = tokenId;
    ownedTokensIndex[tokenId] = length;
  }

  function _removeTokenFromOwner(address from, uint256 tokenId) private {
      // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
      // then delete the last slot (swap and pop).

      uint256 lastTokenIndex = stakeBalances[from] - 1;
      uint256 tokenIndex = ownedTokensIndex[tokenId];

    // When the token to delete is the last token, the swap operation is unnecessary
    if (tokenIndex != lastTokenIndex) {
          uint256 lastTokenId = ownedTokens[from][lastTokenIndex];

      ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
      ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
    }

    // This also deletes the contents at the last position of the array
    delete ownedTokensIndex[tokenId];
    delete ownedTokens[from][lastTokenIndex];
  }

  function getClaimableCRCBalanceOf(address staker) public view returns(uint256) {
    if (hasClaimed[staker] == false) {
      uint256 stakedBalance = crcFarm.stakeBalancesFt(staker);
      uint256 lastUpdatedTime = crcFarm.lastUpdateFt(staker);
      uint256 harvestBalance = crcFarm.harvestsFt(staker);
      uint256 pending = stakedBalance * 300 * (stakeEndDate - lastUpdatedTime) / 86400 / 1000;
      return stakedBalance + harvestBalance + pending;
    } else {
      return 0;
    }
  }

  function withdrawStakedCRC() external {
    require(hasClaimed[msg.sender] == false, 'already claimed');
    uint256 claimableBalance = getClaimableCRCBalanceOf(msg.sender);
    hasClaimed[msg.sender] = true;
    yieldToken.transfer(msg.sender, claimableBalance);
  } 

  function setNftContractAddr(address nftAddr) public onlyOwner {
    crocosNft = ICrocosNFT(nftAddr);
  }

  function setFtContractAddr(address ftAddr) public onlyOwner {
    yieldToken = ICrocosToken(ftAddr);
  }

  function setCrocosFarmContractAddr(address crcFarmAddress) public onlyOwner {
    crcFarm = ICrocosFarm(crcFarmAddress);
  }

  function withdrawCash() public onlyOwner {
    yieldToken.transfer(admin, yieldToken.balanceOf(address(this)));
  }
}