import React, { useState, useEffect } from "react";
import getMarketData from "../utils/coinData";
import { useAuth } from "./AuthProvider";

export default function PoolForm({ onSubmit }) {
  const [pool, setPool] = useState(false);
  const [marketData, setMarketData] = useState([]);
  const [fromCoin, setFromCoin] = useState(null);
  const [fromCoinAmount, setFromCoinAmount] = useState(null);
  const [toCoin, setToCoin] = useState(null);
  const [toCoinAmount, setToCoinAmount] = useState(null);
  const [fee, setFee] = useState(0.5);
  const { walletInfo } = useAuth();

  useEffect(() => {
    async function getCoinsData() {
      const coinData = await getMarketData();
      setMarketData(coinData);
    }

    getCoinsData();
    setInterval(getCoinsData, 1000 * 60);
  }, []);

  function calcToAmount(fromCoinAmount, opts = {}) {
    console.log(walletInfo.networkName.toLowerCase());
    if (walletInfo.networkName.toLowerCase().includes(fromCoin.toLowerCase()))
      console.log("ok");
    if (!fromCoinAmount) return setToCoinAmount(null);
    const fromCoinSymbol = opts.newFromCoin || fromCoin,
      toCoinSymbol = opts.newToCoin || toCoin;

    let fromCoinPrice, toCoinPrice;
    marketData.forEach((coinData) => {
      if (coinData.symbol.toUpperCase() === fromCoinSymbol)
        fromCoinPrice = coinData.current_price;
      if (coinData.symbol.toUpperCase() === toCoinSymbol)
        toCoinPrice = coinData.current_price;
    });
    const ratio = fromCoinPrice / toCoinPrice;
    setFromCoinAmount(parseInt(fromCoinAmount));
    setToCoinAmount(parseInt(fromCoinAmount) * ratio);
  }

  async function updateToCoin(newValue) {
    setToCoin(newValue);
    if (fromCoinAmount && fromCoin)
      calcToAmount(fromCoinAmount, { newToCoin: newValue });
  }

  async function onFromCoinChange(newValue) {
    setFromCoin(newValue);
    if (toCoin && fromCoinAmount)
      calcToAmount(fromCoinAmount, { newFromCoin: newValue });
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
            onChange={async (e) => {
              await onFromCoinChange(e.target.value.toUpperCase());
            }}
            defaultValue="init"
          >
            <option value="init" disabled></option>
            {marketData.map((coin, index) => (
              <option value={coin.symbol} key={index}>
                {coin.symbol.toUpperCase()}
              </option>
            ))}
          </select>
          <br />
          <select
            name="toCoin"
            onChange={(e) => updateToCoin(e.target.value.toUpperCase())}
            defaultValue="init"
          >
            <option value="init" disabled></option>
            {marketData.map((coin, index) => (
              <option value={coin.symbol} key={index}>
                {coin.symbol.toUpperCase()}
              </option>
            ))}
          </select>

          <div>
            {fromCoin && <p>Enter amount of {fromCoin} </p>}
            <input
              type="number"
              disabled={!(fromCoin && toCoin)}
              onChange={(e) => calcToAmount(e.target.value)}
            />
            {toCoinAmount && (
              <input
                type="number"
                disabled
                placeholder={Number.isNaN(toCoinAmount) ? "" : toCoinAmount}
              />
            )}
          </div>
          {!Number.isNaN(toCoinAmount) && toCoinAmount ? (
            <div>
              <p>
                The current market value of {fromCoinAmount} {fromCoin} is
                {toCoinAmount} {toCoin}.
              </p>

              <div>
                <span>Selected fee tier {fee}%</span>
                <br />
                <input
                  type="range"
                  min="0.1"
                  max="1"
                  step="0.01"
                  defaultValue="0.5"
                  onChange={(e) => setFee(e.target.value)}
                />
              </div>

              <p>
                To become a liquidity provider for {fromCoinAmount} {fromCoin}{" "}
                and {toCoinAmount} {toCoin} press the button 'pool'.
              </p>
            </div>
          ) : (
            ""
          )}
          {fromCoinAmount && toCoinAmount && (
            <div>
              <button
                onClick={(e) =>
                  onSubmit({
                    fromCoin,
                    toCoin,
                    fromCoinAmount,
                    toCoinAmount,
                    fee,
                  })
                }
              >
                Pool
              </button>
            </div>
          )}
        </div>
      )}
    </>
  );
}
