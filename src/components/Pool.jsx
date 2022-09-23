import React, { useEffect, useState } from "react";
import getMarketData from "../utils/coinData";

export default function Pool() {
  const [pool, setPool] = useState(false);
  const [marketData, setMarketData] = useState([]);
  const [fromCoin, setFromCoin] = useState(null);
  const [toCoin, setToCoin] = useState(null);
  const [toCoinAmount, setToCoinAmount] = useState(null);

  useEffect(() => {
    async function getCoinsData() {
      const coinData = await getMarketData();
      setMarketData(coinData);
    }
    getCoinsData();
  });

  function calcToAmount(fromAmount) {
    let fromCoinPrice, toCoinPrice;
    marketData.forEach((coinData) => {
      if (coinData.symbol.toUpperCase() === fromCoin) {
        fromCoinPrice = coinData.current_price;
      } else if (coinData.symbol.toUpperCase() === toCoin)
        toCoinPrice = coinData.current_price;
    });
    const ratio = fromCoinPrice / toCoinPrice;

    setToCoinAmount(fromAmount * ratio);
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
            onChange={(e) => setToCoin(e.target.value.toUpperCase())}
            defaultValue="init"
          >
            <option value="init" disabled></option>
            {marketData.map((coin, index) => (
              <option value={coin.symbol} key={index}>
                {coin.symbol.toUpperCase()}
              </option>
            ))}
          </select>

          {fromCoin && (
            <div>
              <p>Enter amount of {fromCoin} </p>
              <input
                type="number"
                onChange={(e) => calcToAmount(e.target.value)}
              ></input>
              {toCoinAmount && (
                <input type="number" disabled>
                  {toCoinAmount}
                </input>
              )}
            </div>
          )}
        </div>
      )}
    </>
  );
}
