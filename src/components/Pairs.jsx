import React from "react";
import { useAuth } from "./AuthProvider";

export default function Pairs() {
  const pairs = [];
  let fromPairs = [];
  let toPairs = [];
  pairs.forEach((pair) => {
    fromPairs.push(pair.from);
    toPairs.push(pair.to);
  });

  fromPairs = ["ETH", "BTC", "ADA"];
  toPairs = ["AAVE", "UNI", "AVAX"];

  return (
    <div id="pairs">
      <h3>Swap</h3>
      <select>
        {fromPairs.map((pair, index) => (
          <option value={pair} key={index}>
            {pair}
          </option>
        ))}
      </select>
      <br />
      <br />
      <select>
        {toPairs.map((pair, index) => (
          <option value={pair} key={index}>
            {pair}
          </option>
        ))}
      </select>
    </div>
  );
}
