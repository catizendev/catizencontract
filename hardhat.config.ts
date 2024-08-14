import { HardhatUserConfig } from "hardhat/config";
import "@nomiclabs/hardhat-ethers";
// import "@nomiclabs/hardhat-etherscan";
import "@nomicfoundation/hardhat-verify";

import dotenv from "dotenv";
dotenv.config();

const config: HardhatUserConfig = {
  defaultNetwork: "mantle",
  networks: {
    hardhat: {
    },
    mantle: {
      url: "https://rpc.mantle.xyz", //mainnet
      accounts: [process.env.MAIN_PRIKEY ?? '', process.env.ASSIST_PRIKEY ?? ''],
      gasPrice: 0.02e9,
    },
    mantleTest: {
      url: "https://rpc.mantle.xyz", // mainnet for test
      accounts: [process.env.MAIN_TESTER ?? '', process.env.ASSIST_TESTER ?? '']
    }
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_APIKEY,
    customChains: [
      {
        network: "mantleTest",
        chainId: 5000,
        urls: {
          apiURL: "https://explorer.mantle.xyz/api",
          browserURL: "https://explorer.mantle.xyz"
        }
      }
    ]
  },
  solidity: {
    version: '0.8.19',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
};

export default config;
