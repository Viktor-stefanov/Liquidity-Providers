import { useState } from "react";
import RemoveLiquidity from "./RemoveLiquidity";
import ProvideLiquidity from "./ProvideLiquidity";

export default function Pool() {
  const [provideLiquidity, setProvideLiquidity] = useState(null);

  return (
    <>
      <button onClick={() => setProvideLiquidity(true)}>Provide Liquidity</button>
      <button onClick={() => setProvideLiquidity(false)}>Remove Liquidity</button>
      <br />
      <br />

      {provideLiquidity === true ? (
        <ProvideLiquidity />
      ) : provideLiquidity === false ? (
        <RemoveLiquidity />
      ) : (
        ""
      )}
    </>
  );
}
