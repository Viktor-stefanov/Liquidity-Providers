import React, { useEffect, useState } from "react";
import getMarketData from "../utils/coinData";

export default function Pool() {
  const [pool, setPool] = useState(false);
  const [marketData, setMarketData] = useState([]);
  const [fromCoin, setFromCoin] = useState(null);
  const [fromCoinAmount, setFromCoinAmount] = useState(null);
  const [toCoin, setToCoin] = useState(null);
  const [toCoinAmount, setToCoinAmount] = useState(null);

  useEffect(() => {
    async function getCoinsData() {
      //const coinData = await getMarketData();
      const coinData = [
        { name: "ETH", price: 1200 },
        { name: "USDC", price: 1 },
        { name: "USDT", price: 1 },
      ];
      setMarketData(coinData);
    }
    getCoinsData();
  }, []);

  function calcToAmount(fromAmount) {
    let fromCoinPrice, toCoinPrice;

    marketData.forEach((coinData) => {
      if (coinData.name.toUpperCase() === fromCoin) fromCoinPrice = coinData.price;
      else if (coinData.name.toUpperCase() === toCoin) toCoinPrice = coinData.price;
    });
    const ratio = fromCoinPrice / toCoinPrice;

    setFromCoinAmount(fromAmount);
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
            <option value="ETH">ETH</option>
            <option value="USDT">USDT</option>
            <option value="USDC">USDC</option>
            {/*{marketData.map((coin, index) => (
              <option value={coin.symbol} key={index}>
                {coin.symbol.toUpperCase()}
              </option>
            ))}*/}
          </select>
          <br />
          <select
            name="toCoin"
            onChange={(e) => setToCoin(e.target.value.toUpperCase())}
            defaultValue="init"
          >
            <option value="init" disabled></option>
            <option value="ETH">ETH</option>
            <option value="USDT">USDT</option>
            <option value="USDC">USDC</option>
            {/*{marketData.map((coin, index) => (
              <option value={coin.symbol} key={index}>
                {coin.symbol.toUpperCase()}
              </option>
            ))}*/}
          </select>

          {fromCoin && (
            <div>
              <p>Enter amount of {fromCoin}: </p>
              <input type="number" onChange={(e) => calcToAmount(e.target.value)} />
              {toCoinAmount && (
                <div>
                  <input type="number" placeholder={toCoinAmount} disabled />
                  <p>
                    Deposit {fromCoinAmount} {fromCoin} and {toCoinAmount} {toCoin} to become a
                    liquidity provider and receive a 0.2% fee whenever your assets are swapped.
                  </p>
                  <button>Deposit</button>
                </div>
              )}
            </div>
          )}
        </div>
      )}
    </>
  );
}
