import { useState, useEffect } from "react";
import { provideLiquidity, getAllTokens, estimateBalancedDeposit } from "../utils/contracts";

export default function ProvideLiquidity() {
  const [marketData, setMarketData] = useState([]);
  const [fromToken, setFromToken] = useState(null);
  const [fromTokenAmount, setFromTokenAmount] = useState(null);
  const [toToken, setToToken] = useState(null);
  const [toTokenAmount, setToTokenAmount] = useState(null);
  const [depositing, setDepositing] = useState(false);

  useEffect(() => {
    getTokensData();
  }, []);

  async function getTokensData() {
    setMarketData(await getAllTokens());
  }

  async function calcOtherAmount(amount, inputDirection) {
    if (amount === "") {
      setFromTokenAmount(null);
      setToTokenAmount(null);
      return;
    }

    const [fromAmount, toAmount] = await estimateBalancedDeposit(
      fromToken,
      toToken,
      amount,
      inputDirection
    );

    if (inputDirection === "fromTo") {
      setFromTokenAmount(amount);
      setToTokenAmount(toAmount);
    } else {
      setToTokenAmount(amount);
      setFromTokenAmount(fromAmount);
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
      <select
        name="fromToken"
        onChange={(e) => setFromToken(e.target.value.toUpperCase())}
        defaultValue="init"
        disabled={depositing}
      >
        <option value="init" disabled></option>
        {marketData.map((token, index) => (
          <option value={token} key={index}>
            {token}
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
        {marketData.map((token, index) => (
          <option value={token} key={index}>
            {token}
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
    </>
  );
}
