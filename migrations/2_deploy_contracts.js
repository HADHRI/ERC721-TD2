// Creating a contract extraction

const ERC721= artifacts.require("./ERC721.sol");

module.exports = function(deployer) {
  deployer.deploy(ERC721);
};
