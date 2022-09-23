import axios from "axios";

export default async function getMarketData() {
  const url = "https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd";
  const res = await axios.get(url);
  if (res.status === 200) return res?.data;
  else return [];
}
