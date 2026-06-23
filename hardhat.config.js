require("@nomicfoundation/hardhat-toolbox");

const PRIVATE_KEY = "0x88d07b5acc049d424aeccdcec7fb08e3bf90aec7c273286acc1ee218d1d7bfc6";

module.exports = {
  solidity: "0.8.20",
  networks: {
    hardhat: {},
    localhost: {
      url: "http://127.0.0.1:8545"
    },
    sepolia: {
      url: "https://rpc.sepolia.dev",
      accounts: [PRIVATE_KEY]
    }
  }
};
