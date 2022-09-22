import React, { useState, createContext, useContext } from "react";
import { useNavigate } from "react-router-dom";
import Metamask from "../utils/metamask.js";

const AuthContext = createContext({});

export default function AuthProvider({ children }) {
  const navigate = useNavigate();
  const [isLoggedIn, updateIsLoggedIn] = useState(null);

  const handleLogin = async () => {
    console.log("handling login...");
    const walletConnected = await Metamask.connectWallet();
    updateIsLoggedIn(walletConnected);
    navigate("/");
  };

  const auth = {
    isLoggedIn,
    onLogin: handleLogin,
  };

  return <AuthContext.Provider value={auth}>{children}</AuthContext.Provider>;
}

const useAuth = () => {
  return useContext(AuthContext);
};

export { useAuth };
