const Stake = artifacts.require("Stake");
const SimpleToken = artifacts.require("SimpleToken");

module.exports = function (deployer) {
  deployer.deploy(Stake);
  deployer.deploy(SimpleToken, "Simple", "SIM", 100000);
};
