import React, { useState, createContext, useContext } from "react";
import { useNavigate } from "react-router-dom";
import Metamask from "../utils/metamask.js";

const AuthContext = createContext({});

export default function AuthProvider({ children }) {
  const navigate = useNavigate();
  const [isLoggedIn, updateIsLoggedIn] = useState(null);
  const [walletInfo, updateWalletInfo] = useState({});

  const handleLogin = async () => {
    const walletConnected = await Metamask.connectWallet();
    updateIsLoggedIn(walletConnected);
    updateWalletInfo({
      networkName: Metamask.network.name,
      chainId: Metamask.network.chainId,
      account: Metamask.account,
      accounts: Metamask.accounts,
      balance: Metamask.balance,
    });
    navigate("/pairs");
  };

  const auth = {
    isLoggedIn,
    walletInfo,
    onLogin: handleLogin,
  };

  return <AuthContext.Provider value={auth}>{children}</AuthContext.Provider>;
}

const useAuth = () => {
  return useContext(AuthContext);
};

export { useAuth };
