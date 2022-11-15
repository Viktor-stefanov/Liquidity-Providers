import React, { useState, useEffect } from "react";
import { provideLiquidity, getTokenPrices, estimateBalancedDeposit } from "../utils/contracts";

export default function Pool() {
  const [pool, setPool] = useState(false);
  const [marketData, setMarketData] = useState([]);
  const [fromToken, setFromToken] = useState(null);
  const [fromTokenAmount, setFromTokenAmount] = useState(null);
  const [toToken, setToToken] = useState(null);
  const [toTokenAmount, setToTokenAmount] = useState(null);
  const [depositing, setDepositing] = useState(false);

  async function getTokensData() {
    setMarketData(await getTokenPrices());
  }

  useEffect(() => {
    getTokensData();
  }, []);

  async function calcOtherAmount(amount, inputDirection) {
    if (amount === "") {
      setFromTokenAmount(null);
      setToTokenAmount(null);
      return;
    }

    const otherAmount = await estimateBalancedDeposit(fromToken, toToken, amount, inputDirection);
    if (inputDirection === "fromTo") {
      setFromTokenAmount(amount);
      setToTokenAmount(otherAmount);
    } else {
      setToTokenAmount(amount);
      setFromTokenAmount(otherAmount);
    }
  }

  async function startPooling() {
    setDepositing(true);
    await provideLiquidity(fromToken, fromTokenAmount, toToken, toTokenAmount);
    setFromTokenAmount(null);
    setToTokenAmount(null);
    setDepositing(false);
  }

  return (
    <>
      <button onClick={() => setPool(true)}>Become a Liquidity Provider</button>
      <br />
      <br />

      {pool && (
        <div>
          <select
            name="fromToken"
            onChange={(e) => setFromToken(e.target.value.toUpperCase())}
            defaultValue="init"
            disabled={depositing}
          >
            <option value="init" disabled></option>
            {marketData.map((TokenData, index) => (
              <option value={TokenData.name} key={index}>
                {TokenData.name}
              </option>
            ))}
          </select>
          <br />
          <select
            name="toToken"
            onChange={(e) => setToToken(e.target.value.toUpperCase())}
            defaultValue="init"
            disabled={depositing}
          >
            <option value="init" disabled></option>
            {marketData.map((TokenData, index) => (
              <option value={TokenData.name} key={index}>
                {TokenData.name}
              </option>
            ))}
          </select>

          {fromToken && toToken && (
            <div>
              <p>Enter amount of {fromToken}: </p>
              <input
                type="number"
                onChange={(e) => calcOtherAmount(e.target.value, "fromTo")}
                disabled={depositing}
                value={fromTokenAmount || ""}
              />
              <p>Enter amount of {toToken}: </p>
              <input
                type="number"
                onChange={(e) => calcOtherAmount(e.target.value, "toFrom")}
                disabled={depositing}
                value={toTokenAmount || ""}
              />
              {fromTokenAmount && toTokenAmount && (
                <div>
                  <p>
                    Deposit {fromTokenAmount} {fromToken} and {toTokenAmount} {toToken} to become a
                    liquidity provider.
                  </p>
                  <button onClick={startPooling} disabled={depositing}>
                    Deposit
                  </button>
                  {depositing && (
                    <p>Please open your web wallet and await for the transactions to complete.</p>
                  )}
                </div>
              )}
            </div>
          )}
        </div>
      )}
    </>
  );
}
