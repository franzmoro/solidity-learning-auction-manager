import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-waffle";

module.exports = {
  solidity: {
    version: "0.8.16",
  },
  paths: {
    sources: "./src",
    cache: "hh-cache",
  },
};
