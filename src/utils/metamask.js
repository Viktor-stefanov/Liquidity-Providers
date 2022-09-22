import { ethers } from "ethers";

const Wallet = {
  accounts: [],
  account: null,
  walletConnected: false,

  connectWallet: async () => {
    if (window.ethereum) {
      const provider = new ethers.providers.Web3Provider(window.ethereum);
      Wallet.accounts = await provider.send("eth_requestAccounts", []);
      Wallet.account = Wallet.accounts[0];
      Wallet.walletConnected = true;
    }
  },
};

export default Wallet;
