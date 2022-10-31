import { ethers } from "ethers";
import abi from "../../artifacts/contracts/PriceFeed.sol/PriceFeed.json";
import aggr from "../../artifacts/contracts/MockV3Aggregator.sol/MockV3Aggregator.json";

const provider = new ethers.providers.JsonRpcProvider("http://127.0.0.1:8545/");
const signer = provider.getSigner();
const aggregator = new ethers.Contract(
  "0x322813Fd9A801c5507c9de605d63CEA4f2CE6c44",
  aggr.abi,
  signer
);
const contract = new ethers.Contract("0xa85233C63b9Ee964Add6F2cffe00Fd84eb32338f", abi.abi, signer);

console.log(aggregator.address);
await (
  await contract.addPriceAggregator(
    "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    aggregator.address
  )
).wait();

const usdcPrice = await contract.getPrice("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48");
console.log(ethers.utils.formatEther(usdcPrice));
