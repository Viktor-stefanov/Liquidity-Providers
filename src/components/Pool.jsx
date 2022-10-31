import React, { useState } from "react";
import PoolForm from "./PoolForm";

export default function Pool() {
  function onSubmit(formData) {
    const { fromCoin, toCoin, fromCoinAmount, toCoinAmount, fee } = formData;
    console.log(fromCoin, toCoin, fromCoinAmount, toCoinAmount, fee);
    
    // now fetch user balances and compare if userbalance >= fromCoinAmount and toCoinAmount
  }

  return <PoolForm onSubmit={onSubmit} />;
}
