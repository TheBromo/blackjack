/** @type {import('@dethcrypto/eth-sdk').EthSdkConfig} */
const config = {
  rpc: {
    url: "http://127.0.0.1:8545", // ← local node RPC URL
  },
  // Define contracts for each network
  contracts: {
    local: {
      bankTreasury: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
      blackJackTable: "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0",
      rng: "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0",
    },
  },
};
module.exports = config;
