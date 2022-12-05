import React, { useEffect, useState } from "react";
import { getAllPools, getRelativePrice, swapTokens } from "../utils/contracts";

export default function Pairs() {
  const [pools, setPools] = useState([]);
  const [tokens, setTokens] = useState(null);
  const [fromToken, setFromToken] = useState(null);
  const [toToken, setToToken] = useState(null);
  const [fromTokenAmount, setFromTokenAmount] = useState(null);
  const [toTokenAmount, setToTokenAmount] = useState(null);
  const [swapping, setSwapping] = useState(null);

  useEffect(() => {
    async function getPools() {
      setPools(await getAllPools());
    }
    getPools();
  }, []);

  async function calcOtherAmount(amount) {
    if (amount === "") {
      setFromTokenAmount(null);
      setToTokenAmount(null);
      return;
    }

    const pool = tokens.join("/"),
      equivalentAmount = await getRelativePrice(pool, fromToken, toToken, amount);

    setFromTokenAmount(amount);
    setToTokenAmount(equivalentAmount);
  }

  async function exchangeTokens() {
    setSwapping(true);
    await swapTokens(fromToken, fromTokenAmount, toToken, toTokenAmount);
    setSwapping(false);
  }

  return (
    <>
      <h3>Swap Interface </h3>
      <p>Select a pool:</p>
      <select
        defaultValue={"init"}
        onChange={(e) => setTokens(e.target.value.split("/"))}
        disabled={swapping}
      >
        <option value="init" disabled></option>
        {pools.map((token, index) => (
          <option value={token} key={index}>
            {token}
          </option>
        ))}
      </select>

      {tokens && (
        <>
          <p>Select token to swap:</p>
          <select
            defaultValue={"init"}
            onChange={(e) => setFromToken(e.target.value)}
            disabled={swapping}
          >
            <option value="init" disabled></option>
            {tokens.map((token, index) => (
              <option value={token} key={index}>
                {token}
              </option>
            ))}
          </select>
          <p>Select token to receive:</p>
          <select
            defaultValue={"init"}
            onChange={(e) => setToToken(e.target.value)}
            disabled={swapping}
          >
            <option value="init" disabled></option>
            {tokens.map((token, index) => (
              <option value={token} key={index}>
                {token}
              </option>
            ))}
          </select>
          {fromToken && toToken && (
            <>
              <p>Enter amount of {fromToken}</p>
              <input
                type="number"
                value={fromTokenAmount || ""}
                onChange={(e) => calcOtherAmount(e.target.value)}
                disabled={swapping}
              />
              {fromTokenAmount && (
                <>
                  <p>
                    {fromTokenAmount} {fromToken} trades for {toTokenAmount} {toToken}
                  </p>
                  <button onClick={exchangeTokens} disabled={swapping}>
                    Swap
                  </button>
                </>
              )}
            </>
          )}
        </>
      )}
      {swapping && <p>Please open your wallet app and wait for the transaction to complete.</p>}
    </>
  );
}
