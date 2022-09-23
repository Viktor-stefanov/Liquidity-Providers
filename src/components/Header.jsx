import React from "react";
import { Link, Outlet } from "react-router-dom";
import { useAuth } from "./AuthProvider";

export default function Header() {
  const { walletInfo } = useAuth();

  return (
    <>
      <div style={{ width: "100%" }}>
        <Link to="/pairs" style={{ marginRight: "10px" }}>
          Pairs
        </Link>
        <Link to="/pool" style={{ marginRight: "10px" }}>
          Pool
        </Link>
        <p style={{ display: "inline" }}>Network: {walletInfo.network}</p>
        <p
          style={{ display: "inline", marginRight: "10px", marginLeft: "10px" }}
        >
          Balance: {walletInfo.balance}
        </p>
        <p style={{ display: "inline" }}>Account: {walletInfo.account}</p>
      </div>
      <br />
      <br />

      <Outlet />
    </>
  );
}
