import { ethers } from "ethers";
import priceFeed from "../../deployments/localhost/PriceFeed.json";
import usdcMock from "../../deployments/localhost/UsdcMock.json";
import ethMock from "../../deployments/localhost/EthMock.json";
import ethToUsdc from "../../deployments/localhost/EthToUsdc.json";
import usdc from "../../deployments/localhost/UsdcContract.json";

const { ethToUsdcContract, priceFeedContract, usdcAggregator, ethAggregator } =
  await instantiateContracts();

async function instantiateContracts() {
  const provider = new ethers.providers.JsonRpcProvider(
      "http://127.0.0.1:8545/"
    ),
    signer = provider.getSigner(),
    usdcAggregator = new ethers.Contract(
      usdcMock.address,
      usdcMock.abi,
      signer
    ),
    ethAggregator = new ethers.Contract(ethMock.address, ethMock.abi, signer),
    priceFeedContract = new ethers.Contract(
      priceFeed.address,
      priceFeed.abi,
      signer
    ),
    ethToUsdcContract = new ethers.Contract(
      ethToUsdc.address,
      ethToUsdc.abi,
      signer
    ),
    usdcContract = new ethers.Contract(usdc.address, usdc.abi, signer);

  await (
    await priceFeedContract.addPriceAggregator(
      "0x413b1AfCa96a3df5A686d8BFBF93d30688a7f7D9",
      usdcAggregator.address
    )
  ).wait();

  await (
    await priceFeedContract.addPriceAggregator(
      "0xB06c856C8eaBd1d8321b687E188204C1018BC4E5",
      ethAggregator.address
    )
  ).wait();

  const tokenBalance = await usdcContract.balanceOf(await signer.getAddress());
  await usdcContract.approve(ethToUsdcContract.address, tokenBalance);
  await ethToUsdcContract.deposit(1500, {
    value: ethers.utils.parseEther("1"),
    gasLimit: 2.9 * 10 ** 6,
  });

  //console.log(await ethToUsdcContract.test());
  //console.log(await priceFeedContract.getPrice(await ethToUsdcContract.test()));

  return {
    ethToUsdcContract,
    priceFeedContract,
    usdcAggregator,
    ethAggregator,
  };
}

// Q: What are the inputs?
// A: the eth/ERC20 pair, and the amount of eth/erc20
// What are the outputs?
async function provideLiquidity(tokenAddress) {}

export { provideLiquidity };
