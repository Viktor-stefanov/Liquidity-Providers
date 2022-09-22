import React from "react";
import { useAuth } from "./AuthProvider";

export default function AssetPairs() {
  console.log(useAuth());

  return <h1>Pairs Page</h1>;
}
