const { expectEvent, expectRevert } = require('@openzeppelin/test-helpers');

const Stake = artifacts.require('Stake');
const SimpleToken = artifacts.require('SimpleToken');
let stakeInstance;
let tokenInstance;

contract('Stake', (accounts) => {

    beforeEach(async function () {
        stakeInstance = await Stake.deployed();
        tokenInstance = await SimpleToken.deployed();
    });

    it('should revert only owner can create stake', async () => {
        await expectRevert(stakeInstance.createStake(tokenInstance.address, 100, { from: accounts[2] }), "Only owner can create a stake")
    });

    it('should create a stake', async () => {

        await stakeInstance.createStake(tokenInstance.address, 100, { from: accounts[0] });

        const storedData = await stakeInstance.getStake(0);
        assert.equal(storedData["1"], tokenInstance.address, 'Stake not created');
    });

    it('should transfer token to a account', async () => {
        await tokenInstance.transfer(accounts[1], "1000000000000000000000");
        const balance = await tokenInstance.balanceOf(accounts[1]);
        assert.equal(balance, "1000000000000000000000", "Transfer Failed");
    });

    it('should approve contract to transfer token', async () => {
        await tokenInstance.approve(stakeInstance.address, "100000000000000000000", { from: accounts[1] });

        const allowance = await tokenInstance.allowance(accounts[1], stakeInstance.address);
        assert.equal(allowance, "100000000000000000000", "Contract is not allowed to spend token");
    });

    it('should add stake', async () => {

        await stakeInstance.addStake(0, { from: accounts[1] });
        const stakersCount = await stakeInstance.totalStakers(0);
        assert.equal(stakersCount, 1, "Stake not Added");
    });

    it('should revert stake added', async () => {
        await expectRevert(stakeInstance.addStake(0, { from: accounts[1] }), "Stake added");
    });

    it('should revert only owner can declare winner', async () => {
        await expectRevert(stakeInstance.declareWinner(0, { from: accounts[1] }), "Only owner can declare winner");
    });

    it('should declare winner', async () => {
        await stakeInstance.declareWinner(0);

        const winner = await stakeInstance.getStake(0);
        assert.equal(winner[5], accounts[1], "Winner not declared");
    });

    it('should create second stake for same token', async () => {
        await stakeInstance.createStake(tokenInstance.address, 100, { from: accounts[0] });
        // Get stored value
        const stake1 = await stakeInstance.getStake(0);
        const stake2 = await stakeInstance.getStake(1);
        assert.equal(stake1[1], stake2[1], 'Stake not created again');
    });

});