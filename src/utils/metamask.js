import { ethers } from "ethers";

const Wallet = {
  accounts: [],
  account: null,
  balance: null,
  network: null,
  walletConnected: false,

  connectWallet: async () => {
    if (window.ethereum) {
      try {
        const provider = new ethers.providers.Web3Provider(window.ethereum);
        Wallet.walletConnected = true;
        Wallet.accounts = await provider.send("eth_requestAccounts", []);
        Wallet.account = Wallet.accounts[0];
        Wallet.balance = parseInt(await provider.getBalance(Wallet.account));
        Wallet.network = (await provider.getNetwork()).name;

        return true;
      } catch {
        return false;
      }
    }
  },
};

export default Wallet;