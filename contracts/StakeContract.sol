pragma solidity 0.8.0;
// SPDX-License-Identifier: Unlicensed

contract Token {
    function balanceOf(address account) public view  returns (uint256) {}
    function transfer(address recipient, uint256 amount) public virtual  returns (bool) {}
    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {}
    function owner() public view returns (address) {}
    function approve(address spender, uint256 amount) external returns (bool){}
    function allowance(address _owner, address spender) external view returns (uint256){}
    function decimals() external view returns (uint8){}
}

contract Stake {
    
    enum StakeState { NotCreated, Started, Finished }
    
    struct Stakes{
        address owner;
        uint256 stakeAmount;
        address tokenAddress;
        StakeState state;
        address[] stakers;
        address winner;
    }
    
    mapping(uint256 => Stakes) stakes;
    mapping(address => mapping(address => uint256)) stakeOfUser;
    
    event DeclareWinner(address indexed winner, uint256 indexed stakeId, uint256 indexed amount);
    event StakeStateChanged(StakeState indexed state, uint256 indexed stakeId);
    event StakeCreated(address indexed owner, uint256 indexed amount, address indexed tokenAddress, uint256 stakeId);
    event StakeAdded(address addedBy, uint256 stakeId);
    
    uint256 public stakeCount;
    
    function createStake(address tokenAddress, uint256 amount) public  {
        require(msg.sender == Token(tokenAddress).owner(), "Only owner can create a stake");
        require(stakes[stakeCount].state == StakeState.NotCreated || stakes[stakeCount].state == StakeState.Finished, "Stake is already Started");
        
        stakes[stakeCount].owner = Token(tokenAddress).owner();
        stakes[stakeCount].stakeAmount = amount * 10 ** Token(tokenAddress).decimals();
        stakes[stakeCount].tokenAddress = tokenAddress;
        stakes[stakeCount].winner = address(0);
        
        emit StakeCreated(Token(tokenAddress).owner(), amount, tokenAddress, stakeCount);
        _changeState(StakeState.Started, stakeCount);
        stakeCount = stakeCount + 1;
    }
    
    function addStake(uint256 stakeId) public returns(bool) {
        for(uint8 i =0; i< stakes[stakeId].stakers.length; i++){
            require(msg.sender != stakes[stakeId].stakers[i], "Stake added");
        }
        address stake = stakes[stakeId].tokenAddress;
        require(Token(stake).allowance(msg.sender, address(this)) >= stakes[stakeId].stakeAmount, "Approve Contract to transfer token");
        require(msg.sender != stakes[stakeId].owner, "Owner can't stake tokens");
        require(stakes[stakeId].state == StakeState.Started, "Stake closed");
        
        stakes[stakeId].stakers.push(msg.sender);
        Token(stake).transferFrom(msg.sender, address(this), stakes[stakeId].stakeAmount);
        
        emit StakeAdded(msg.sender, stakeId);
        
        return true;
    }
    
    function declareWinner(uint256 stakeId) public returns(address){
        require(address(0) != stakes[stakeId].owner, "Stake is not Started or Created");
        require(msg.sender == stakes[stakeId].owner, 'Only owner can declare winner');
        
        uint256 winAmount = stakes[stakeId].stakeAmount * stakes[stakeId].stakers.length * 2 / 3;
        uint256 winner = _rand(stakes[stakeId].stakers.length);
        address stake = stakes[stakeId].tokenAddress;
        
        Token(stake).transfer(stakes[stakeId].stakers[winner], winAmount);
        stakes[stakeId].winner = stakes[stakeId].stakers[winner];
        
        Token(stake).transfer(stakes[stakeId].owner, (stakes[stakeId].stakeAmount * stakes[stakeId].stakers.length) - winAmount);
        
        emit DeclareWinner(stakes[stakeId].stakers[winner], stakeId, winAmount);
        
        _changeState(StakeState.Finished, stakeId);
        return stakes[stakeId].winner;
    }
        
    function stakeOwner(uint256 stakeId) public view returns(address){
        return stakes[stakeId].owner;
    }
    
    function checkAllowance(uint256 stakeId, address tokenHolder) public view returns(uint256) {
        address stake = stakes[stakeId].tokenAddress;
        return Token(stake).allowance(tokenHolder, address(this));
    }

    function getStake(uint256 stakeId) public view returns(address, address, uint256, address[] memory, StakeState, address){
        Stakes memory _stake = stakes[stakeId];
        return (_stake.owner, _stake.tokenAddress, _stake.stakeAmount, _stake.stakers, _stake.state, _stake.winner);
    }
	
    function totalStakers(uint256 stakeId) public view returns(uint256) {
        return stakes[stakeId].stakers.length;
    }
	
	function _rand(uint256 limit) private view returns(uint256) {
        uint256 seed = uint256(keccak256(abi.encodePacked(
            block.timestamp + block.difficulty +
            ((uint256(keccak256(abi.encodePacked(block.coinbase)))) / (block.timestamp)) +
            block.gaslimit + 
            ((uint256(keccak256(abi.encodePacked(msg.sender)))) / (block.timestamp)) +
            block.number
        )));

        return (seed - ((seed / limit) * limit));
    }
    
    function _changeState(StakeState _newState, uint256 stakeId) private {
		stakes[stakeId].state = _newState;
		emit StakeStateChanged(stakes[stakeId].state, stakeId);
	}
    
}