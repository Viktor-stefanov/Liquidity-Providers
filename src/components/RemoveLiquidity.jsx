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
  const [fromToken, setFromToken] = useState(null);
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
    const parsedAmount = parseFloat(amount);
    if (Number.isNaN(parsedAmount) || parsedAmount === 0 || parsedAmount > deposits.user[idx]) {
      if (
        (Number.isNaN(parsedAmount) && [".", ""].includes(amount)) ||
        parseFloat(amount) <= parseFloat(deposits.user[idx])
      ) {
        const newInputAmounts = [];
        newInputAmounts[idx] = amount;
        setInputAmounts(newInputAmounts);
      }
      if (parsedAmount === 0 || amount === "") setWdAmounts([]);
      return;
    }

    const newWdAmounts = await estimateWithdrawAmounts(
        tokens.join("/"),
        amount,
        tokens[0] === tokens[idx]
      ),
      newInputAmounts = [];
    newInputAmounts[idx] = amount;

    setWdAmounts(newWdAmounts);
    setInputAmounts(newInputAmounts);
  }

  async function withdrawTokens() {
    setInTx(true);
    setInputAmounts([]);
    const pool = tokens.join("/");
    let tokenAmount;
    for (let el of inputAmounts) if (el) tokenAmount = el;
    await (await withdraw(pool, fromToken, tokenAmount)).wait();
    setDeposits({ pool: await getPoolDeposits(pool), user: await getUserDeposits(pool) });
    setWdAmounts([]);
    setInTx(false);
  }

  function onInputAmountChange(index, amount) {
    calcWithdrawAmounts(index, amount);
    setFromToken(tokens[index]);
  }

  return (
    <>
      <select onChange={(e) => onPoolSelect(e.target.value)} defaultValue="init" disabled={inTx}>
        <option value="init" disabled={inTx}></option>
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
              onInput={(e) => onInputAmountChange(index, e.target.value)}
              disabled={inTx}
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
          <button onClick={withdrawTokens} disabled={inTx}>
            Withdraw
          </button>
        </>
      )}
      {inTx && <p>Please open you wallet and accept the transaction.</p>}
    </>
  );
}
