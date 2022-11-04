import React, { useState, useEffect } from "react";
import { provideLiquidity, getTokenPrices, estimateDeposit } from "../utils/contracts";

export default function Pool() {
  const [pool, setPool] = useState(false);
  const [marketData, setMarketData] = useState([]);
  const [fromCoin, setFromCoin] = useState(null);
  const [fromCoinAmount, setFromCoinAmount] = useState(null);
  const [toCoin, setToCoin] = useState(null);
  const [toCoinAmount, setToCoinAmount] = useState(null);
  const [fromCoinPrice, setFromCoinPrice] = useState(null);
  const [toCoinPrice, setToCoinPrice] = useState(null);
  const [depositing, setDepositing] = useState(false);

  async function getCoinsData() {
    setMarketData(await getTokenPrices());
  }

  useEffect(() => {
    async function estimate() {
      if (fromCoin && toCoin) {
        const [fcEstimate, tcEstimate] = await estimateDeposit(fromCoin, toCoin);
        setFromCoinPrice(fcEstimate);
        setToCoinPrice(tcEstimate);
      }
    }
    estimate();
  }, [toCoin]);

  useEffect(() => {
    getCoinsData();
  }, []);

  function calcOtherAmount(amount, target) {
    if (target === "to") {
      const ratio = fromCoinPrice / toCoinPrice;
      setFromCoinAmount(amount);
      setToCoinAmount(amount * ratio);
    } else {
      const ratio = toCoinPrice / fromCoinPrice;
      setFromCoinAmount(amount * ratio);
      setToCoinAmount(amount);
    }
  }

  async function startPooling() {
    setDepositing(true);
    await provideLiquidity(fromCoin, fromCoinAmount, toCoin, toCoinAmount);
    setFromCoinAmount(null);
    setToCoinAmount(null);
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
            name="fromCoin"
            onChange={(e) => setFromCoin(e.target.value.toUpperCase())}
            defaultValue="init"
            disabled={depositing}
          >
            <option value="init" disabled></option>
            {marketData.map((coinData, index) => (
              <option value={coinData.name} key={index}>
                {coinData.name}
              </option>
            ))}
          </select>
          <br />
          <select
            name="toCoin"
            onChange={(e) => setToCoin(e.target.value.toUpperCase())}
            defaultValue="init"
            disabled={depositing}
          >
            <option value="init" disabled></option>
            {marketData.map((coinData, index) => (
              <option value={coinData.name} key={index}>
                {coinData.name}
              </option>
            ))}
          </select>

          {fromCoin && toCoin && (
            <div>
              <p>Enter amount of {fromCoin}: </p>
              <input
                type="number"
                onChange={(e) => calcOtherAmount(e.target.value, "to")}
                disabled={depositing}
                value={fromCoinAmount || ""}
              />
              <p>Enter amount of {toCoin}: </p>
              <input
                type="number"
                onChange={(e) => calcOtherAmount(e.target.value, "from")}
                disabled={depositing}
                value={toCoinAmount || ""}
              />
              {fromCoinAmount && toCoinAmount && (
                <div>
                  <p>
                    Deposit {fromCoinAmount} {fromCoin} and {toCoinAmount} {toCoin} to become a
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
