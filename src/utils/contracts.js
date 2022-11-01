import { ethers } from "ethers";
import priceFeed from "../../deployments/localhost/PriceFeed.json";
import usdtMock from "../../deployments/localhost/UsdtMock.json";
import usdcMock from "../../deployments/localhost/UsdcMock.json";
import ethMock from "../../deployments/localhost/EthMock.json";
import ethToERC20 from "../../deployments/localhost/EthToERC20.json";
import usdc from "../../deployments/localhost/UsdcContract.json";
import usdt from "../../deployments/localhost/UsdtContract.json";

const {
  ethToERC20Contract,
  priceFeedContract,
  usdcContract,
  usdtContract,
  usdcAggregator,
  usdtAggregator,
  ethAggregator,
} = await instantiateContracts();

async function instantiateContracts() {
  const web3provider = new ethers.providers.Web3Provider(window.ethereum),
    provider = new ethers.providers.JsonRpcProvider("http://127.0.0.1:8545/"),
    web3signer = web3provider.getSigner(),
    signer = provider.getSigner(),
    usdtAggregator = new ethers.Contract(usdtMock.address, usdtMock.abi, signer),
    usdcAggregator = new ethers.Contract(usdcMock.address, usdcMock.abi, signer),
    ethAggregator = new ethers.Contract(ethMock.address, ethMock.abi, signer),
    priceFeedContract = new ethers.Contract(priceFeed.address, priceFeed.abi, signer),
    ethToERC20Contract = new ethers.Contract(ethToERC20.address, ethToERC20.abi, web3signer),
    usdcContract = new ethers.Contract(usdc.address, usdc.abi, web3signer),
    usdtContract = new ethers.Contract(usdt.address, usdt.abi, web3signer);

  return {
    ethToERC20Contract,
    priceFeedContract,
    usdcContract,
    usdtContract,
    usdcAggregator,
    usdtAggregator,
    ethAggregator,
  };
}

async function provideLiquidity(fromToken, fromAmount, toToken, toAmount) {
  const toContract = toToken === "USDC" ? usdcContract : toToken === "USDT" ? usdtContract : null;
  const user = await ethToERC20Contract.signer.getAddress();
  const tokenBalance = await toContract.balanceOf(user);

  try {
    if ((await toContract.allowance(user, ethToERC20Contract.address)) < toAmount)
      await toContract.approve(ethToERC20Contract.address, tokenBalance);

    await (
      await ethToERC20Contract.deposit(toContract.address, toAmount, {
        value: ethers.utils.parseEther(fromAmount.toString()),
        gasLimit: 2.9 * 10 ** 6,
      })
    ).wait();
    return true;
  } catch (err) {
    console.log(`Error on providing liquidity: ${err}`);
    return false;
  }
}

export { provideLiquidity };
