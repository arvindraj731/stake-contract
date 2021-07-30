pragma solidity 0.8.0;
// SPDX-License-Identifier: Unlicensed

contract Token {
    function transfer(address recipient, uint256 amount) public virtual  returns (bool) {}
    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {}
    function owner() public view returns (address) {}
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
        uint256 deadline;
    }
    
    mapping(uint256 => Stakes) stakes;
    mapping(uint256 => mapping(address => uint256)) public stakeOfUser;
    mapping(address => StakeState) stakeState;
    
    event DeclareWinner(address indexed winner, uint256 indexed stakeId, uint256 indexed amount);
    event StakeStateChanged(StakeState indexed state, uint256 indexed stakeId);
    event StakeCreated(address indexed owner, uint256 indexed amount, address indexed tokenAddress, uint256 stakeId, uint256 deadline);
    event StakeAdded(address addedBy, uint256 stakeId);
    
    uint256 public stakeCount;

    modifier stakeNotCreated(uint256 stakeId) {
        require(stakes[stakeId].state != StakeState.NotCreated, "Stake is not Created");
        _;
    }

    modifier stakeFinished(uint256 stakeId) {
        require(stakes[stakeId].state == StakeState.Started, "Stake Finished");
        _;
    }
    
    function createStake(address tokenAddress, uint256 amount, uint256 noOfDays) public  {
        require(msg.sender == Token(tokenAddress).owner(), "Only owner can create a stake.");
        require(stakeState[tokenAddress] != StakeState.Started, "Stake is already Started.");
        
        stakes[stakeCount].owner = Token(tokenAddress).owner();
        stakes[stakeCount].stakeAmount = amount * 10 ** Token(tokenAddress).decimals();
        stakes[stakeCount].tokenAddress = tokenAddress;
        stakes[stakeCount].winner = address(0);
        stakes[stakeCount].deadline = block.timestamp + (noOfDays * 1 days);
        
        stakeState[tokenAddress] = StakeState.Started;
        emit StakeCreated(Token(tokenAddress).owner(), amount, tokenAddress, stakeCount, stakes[stakeCount].deadline);
        _changeState(StakeState.Started, stakeCount);
        
        stakeCount = stakeCount + 1;
    }
    
    function addStake(uint256 stakeId) public stakeNotCreated(stakeId) stakeFinished(stakeId) returns(bool) {
        address stake = stakes[stakeId].tokenAddress;
        require(msg.sender != stakes[stakeId].owner, "Owner can't stake tokens");
        require(stakeOfUser[stakeId][msg.sender] == 0, "Stake already added");
        require(block.timestamp <= stakes[stakeId].deadline, "Stake has reached its deadline");
        require(Token(stake).allowance(msg.sender, address(this)) >= stakes[stakeId].stakeAmount, "Approve Contract to transfer token");
        
        
        stakes[stakeId].stakers.push(msg.sender);
        stakeOfUser[stakeId][msg.sender] = stakes[stakeId].stakeAmount;
        Token(stake).transferFrom(msg.sender, address(this), stakes[stakeId].stakeAmount);
        
        emit StakeAdded(msg.sender, stakeId);
        
        return true;
    }
    
    function declareWinner(uint256 stakeId) stakeNotCreated(stakeId) stakeFinished(stakeId) public returns(address){
        address stake = stakes[stakeId].tokenAddress;
        require(msg.sender == stakes[stakeId].owner, 'Only owner can declare winner');
        require(block.timestamp >= stakes[stakeId].deadline, "Stake deadline not reached");
        
        uint256 winAmount = stakes[stakeId].stakeAmount * stakes[stakeId].stakers.length * 2 / 3;
        uint256 winner = _rand(stakes[stakeId].stakers.length);
        
        Token(stake).transfer(stakes[stakeId].stakers[winner], winAmount);
        stakes[stakeId].winner = stakes[stakeId].stakers[winner];
        
        Token(stake).transfer(stakes[stakeId].owner, (stakes[stakeId].stakeAmount * stakes[stakeId].stakers.length) - winAmount);
        
        emit DeclareWinner(stakes[stakeId].stakers[winner], stakeId, winAmount);
        
        _changeState(StakeState.Finished, stakeId);
        
        stakeState[stake] = StakeState.Finished;
        return stakes[stakeId].winner;
    }
    
    function checkAllowance(uint256 stakeId, address tokenHolder) public view returns(uint256) {
        address stake = stakes[stakeId].tokenAddress;
        return Token(stake).allowance(tokenHolder, address(this));
    }

    function getStake(uint256 stakeId) public view returns(address, address, uint256, address[] memory, StakeState, address, uint256){
        Stakes memory _stake = stakes[stakeId];
        return (_stake.owner, _stake.tokenAddress, _stake.stakeAmount, _stake.stakers, _stake.state, _stake.winner, _stake.deadline);
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