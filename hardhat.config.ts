import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';
import '@nomiclabs/hardhat-etherscan';
import { config as dotenv_config } from 'dotenv';
dotenv_config();

const config: HardhatUserConfig = {
  solidity: '0.8.17',
  defaultNetwork: 'goerli',
  networks: {
    goerli: {
      url: process.env.GOERLI_URL,
      chainId: 5,
      accounts: JSON.parse(process.env.PRIVATE_KEYS || '[]'),
      gas: 12000000,
      blockGasLimit: 0x1fffffffffffff,
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};

export default config;
