import axios from "axios";

export default async function getMarketData() {
  const url = "http://rest.coinapi.io/v1/assets?apikey=486944C8-833D-4475-AC9C-9DBFD55F4C3E";
  const res = await axios.get(url);
  if (res.status === 200) return await res?.data.filter((entry) => entry.type_is_crypto);
  else return [];
}
