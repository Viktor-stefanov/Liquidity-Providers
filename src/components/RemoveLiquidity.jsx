import { useState, useEffect } from "react";
import {
  withdraw,
  estimateWithdrawAmounts,
  getAllPools,
  getUserDeposits,
  getPoolDeposits,
} from "../utils/contracts";

export default function RemoveLiquidity() {
  const [pools, setPools] = useState([]);
  const [tokens, setTokens] = useState([]);
  const [inputAmounts, setInputAmounts] = useState([]);
  const [deposits, setDeposits] = useState({});
  const [wdAmounts, setWdAmounts] = useState([]);
  const [inTx, setInTx] = useState(false);

  useEffect(() => {
    async function getPools() {
      setPools(await getAllPools());
    }
    getPools();
  }, []);

  async function onPoolSelect(pool) {
    const totalDeposits = await getPoolDeposits(pool),
      userDeposits = await getUserDeposits(pool);

    setDeposits({ user: userDeposits, pool: totalDeposits });
    setTokens(pool.split("/"));
  }

  async function calcWithdrawAmounts(idx, amount) {
    if (amount === "") {
      setWdAmounts(wdAmounts.map(() => ""));
      setInputAmounts(inputAmounts.map(() => ""));
    } else if (parseFloat(amount) > deposits.user[idx]) return;

    const newWdAmounts = await estimateWithdrawAmounts(
        tokens.join("/"),
        amount,
        tokens[idx] === "ETH"
      ),
      newInputAmounts = [];
    newInputAmounts[idx] = amount;

    setWdAmounts(newWdAmounts);
    setInputAmounts(newInputAmounts);
  }

  async function withdrawTokens() {
    const pool = tokens.join("/");
    let tokenAmount;
    for (let el of inputAmounts) if (el) tokenAmount = el;
    await withdraw(pool, tokenAmount, Boolean(inputAmounts[0]));
  }

  return (
    <>
      <select onChange={(e) => onPoolSelect(e.target.value)} defaultValue="init" disabled={inTx}>
        <option value="init" disabled></option>
        {pools.map((pool, index) => (
          <option value={pool} key={index}>
            {pool}
          </option>
        ))}
      </select>

      {deposits.user &&
        deposits.user.map((deposit, index) => (
          <div key={index}>
            <p key={index}>
              You have provided {deposit} {tokens[index]} from a total of
              {deposits.pool[index]} {tokens[index]} provided in the pool.
            </p>
            <span>Enter amount of {tokens[index]} to withdraw: </span>
            <input
              value={inputAmounts[index] || ""}
              onInput={(e) => calcWithdrawAmounts(index, e.target.value)}
            />
          </div>
        ))}
      <br />

      {wdAmounts.length !== 0 && wdAmounts.every((x) => x !== "") && (
        <>
          <span>You can withdraw </span>
          {wdAmounts.map((amount, index) => (
            <span key={index}>
              {amount} {tokens[index]}
              {index !== wdAmounts.length - 1 && <span> and </span>}
            </span>
          ))}

          <br />
          <button onClick={withdrawTokens}>Withdraw</button>
        </>
      )}
    </>
  );
}
