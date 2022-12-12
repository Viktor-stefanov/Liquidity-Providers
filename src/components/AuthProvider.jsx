import React, { useState, useContext, useEffect, createContext } from "react";
import { useNavigate } from "react-router-dom";
import Metamask from "../utils/metamask.js";

const AuthContext = createContext({});
export default function AuthProvider({ children }) {
  const navigate = useNavigate();
  const [isLoggedIn, setIsLoggedIn] = useState(null);
  const [walletInfo, setWalletInfo] = useState({});

  useEffect(() => {
    setWalletInfo(JSON.parse(localStorage.getItem("walletInfo")));
  }, []);

  const handleLogin = async () => {
    const walletConnected = await Metamask.connectWallet();
    const walletData = {
      networkName: Metamask.network.name,
      chainId: Metamask.network.chainId,
      account: Metamask.account,
      accounts: Metamask.accounts,
      balance: Metamask.balance,
    };
    localStorage.setItem("walletInfo", JSON.stringify(walletData));
    setIsLoggedIn(walletConnected);
    setWalletInfo(walletData);
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
