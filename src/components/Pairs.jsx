import React, { useEffect, useState } from "react";
import { getAllTokens, getRelativePrice, swapTokens } from "../utils/contracts";

export default function Pairs() {
  const [tokens, setTokens] = useState([]);
  const [fromToken, setFromToken] = useState(null);
  const [toToken, setToToken] = useState(null);
  const [fromTokenAmount, setFromTokenAmount] = useState(null);
  const [toTokenAmount, setToTokenAmount] = useState(null);

  useEffect(() => {
    async function getTokens() {
      setTokens(await getAllTokens());
    }
    getTokens();
  }, []);

  async function calcOtherAmount(amount) {
    if (amount === "") {
      setFromTokenAmount(null);
      setToTokenAmount(null);
      return;
    }

    const equivalentAmount = await getRelativePrice(fromToken, toToken, amount);
    setFromTokenAmount(amount);
    setToTokenAmount(equivalentAmount);
  }

  async function exchangeTokens() {
    await swapTokens(fromToken, fromTokenAmount, toToken, toTokenAmount);
  }

  return (
    <>
      <h3>Swap Interface </h3>
      <p>Select token to swap:</p>
      <select defaultValue={"init"} onChange={(e) => setFromToken(e.target.value)}>
        <option value="init" disabled></option>
        {tokens.map((token, index) => (
          <option value={token} key={index}>
            {token}
          </option>
        ))}
      </select>
      <p>Select token to receive:</p>
      <select defaultValue={"init"} onChange={(e) => setToToken(e.target.value)}>
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
          />
          {fromTokenAmount && (
            <>
              <p>
                {fromTokenAmount} {fromToken} trades for {toTokenAmount} {toToken}
              </p>
              <button onClick={exchangeTokens}>Swap</button>
            </>
          )}
        </>
      )}
    </>
  );
}
