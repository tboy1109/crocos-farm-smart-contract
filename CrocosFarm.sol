// SPDX-License-Identifier: MIT
pragma solidity >= 0.7.0 < 0.9.0;
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
contract CrocosFarm is Ownable {
  ICrocosNFT public crocosNft;
  ICrocosToken public yieldToken;
  address public admin = 0xD4577dA97872816534068B3aa8c9fFEd2ED7860C;
  uint256 public constant dailyReward = 400 ether * 12 / 1000; //1.2% of 400 ftm
  mapping(address => uint256) public harvests;
  mapping(address => uint256) public lastUpdate;
  mapping(uint => address) public ownerOfToken;
  mapping(address => uint) public stakeBalances;
  mapping(address => mapping(uint256 => uint256)) public ownedTokens;
  mapping(uint256 => uint256) public ownedTokensIndex;

  mapping(address => uint256) public harvestsFt;
  mapping(address => uint256) public lastUpdateFt;
  mapping(address => uint) public stakeBalancesFt;

  constructor(
    address nftAddr,
    address ftAddr
  ) {
    crocosNft = ICrocosNFT(nftAddr);
    yieldToken = ICrocosToken(ftAddr);
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

  function stakeFt(uint _amount) external payable {
    require(yieldToken.balanceOf(msg.sender) > _amount, 'not enough token');
    updateHarvestFt();
    yieldToken.transferFrom(msg.sender, address(this), _amount);
    stakeBalancesFt[msg.sender] += _amount;
  }

  function withdrawFt(uint _amount) external payable {
    require(stakeBalancesFt[msg.sender] >= _amount, "CrocosFarm: Unable to withdraw Ft");
    harvestFt();
    yieldToken.transfer(msg.sender, _amount);
    stakeBalancesFt[msg.sender] -= _amount;
  }

  function updateHarvestFt() internal {
    uint256 time = block.timestamp;
    uint256 timerFrom = lastUpdateFt[msg.sender];
    if (timerFrom > 0)
      harvestsFt[msg.sender] += stakeBalancesFt[msg.sender] * 12 * (time - timerFrom) / 86400 /1000;
    lastUpdateFt[msg.sender] = time;
  }

  function harvestFt() public payable {
    updateHarvestFt();
    uint256 reward = harvestsFt[msg.sender];
    if (reward > 0) {
      yieldToken.transfer(msg.sender, harvestsFt[msg.sender]);
      harvestsFt[msg.sender] = 0;
    }
  }

  function getTotalClaimableFt(address _user) external view returns(uint256) {
    uint256 time = block.timestamp;
    uint256 pending = stakeBalancesFt[msg.sender] * 12 * (time - lastUpdateFt[_user]) / 86400 / 1000;
    return harvestsFt[_user] + pending;
  }
  function setNftContractAddr(address nftAddr) public onlyOwner {
    crocosNft = ICrocosNFT(nftAddr);
  }

  function setFtContractAddr(address ftAddr) public onlyOwner {
    yieldToken = ICrocosToken(ftAddr);
  }

  function withdrawCash() public onlyOwner {
    yieldToken.transfer(admin, yieldToken.balanceOf(address(this)));
  }
}