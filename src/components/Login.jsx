import React from "react";
import { useAuth } from "./AuthProvider";

export default function Login() {
  const { onLogin } = useAuth();

  return (
    <>
      <h1>Welcome to UniClone</h1>

      <button onClick={onLogin}>Connect Wallet</button>
    </>
  );
}
