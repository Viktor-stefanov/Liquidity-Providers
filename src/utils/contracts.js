import { ethers } from "ethers";
import priceFeed from "../../deployments/localhost/PriceFeed.json";
import usdcMock from "../../deployments/localhost/UsdcMock.json";
import ethMock from "../../deployments/localhost/EthMock.json";
import ethToUsdc from "../../deployments/localhost/EthToUsdc.json";
import usdc from "../../deployments/localhost/UsdcContract.json";

const { ethToUsdcContract, priceFeedContract, usdcContract, usdcAggregator, ethAggregator } =
  await instantiateContracts();

async function instantiateContracts() {
  const web3provider = new ethers.providers.Web3Provider(window.ethereum),
    provider = new ethers.providers.JsonRpcProvider("http://127.0.0.1:8545/"),
    web3signer = web3provider.getSigner(),
    signer = provider.getSigner(),
    usdcAggregator = new ethers.Contract(usdcMock.address, usdcMock.abi, signer),
    ethAggregator = new ethers.Contract(ethMock.address, ethMock.abi, signer),
    priceFeedContract = new ethers.Contract(priceFeed.address, priceFeed.abi, signer),
    ethToUsdcContract = new ethers.Contract(ethToUsdc.address, ethToUsdc.abi, web3signer),
    usdcContract = new ethers.Contract(usdc.address, usdc.abi, web3signer);

  await (
    await priceFeedContract.addPriceAggregator(
      ethers.utils.getAddress(usdcContract.address),
      usdcAggregator.address
    )
  ).wait();

  await (
    await priceFeedContract.addPriceAggregator(
      "0xB06c856C8eaBd1d8321b687E188204C1018BC4E5",
      ethAggregator.address
    )
  ).wait();

  console.log(await web3signer.getAddress());
  let tokenBalance = await usdcContract.balanceOf("0x572316aC11CB4bc5daf6BDae68f43EA3CCE3aE0e");
  console.log(parseInt(tokenBalance));

  await usdcContract.approve(ethToUsdcContract.address, 50000);
  await ethToUsdcContract.test();

  tokenBalance = await usdcContract.balanceOf("0x572316aC11CB4bc5daf6BDae68f43EA3CCE3aE0e");
  console.log(parseInt(tokenBalance));

  return {
    ethToUsdcContract,
    priceFeedContract,
    usdcContract,
    usdcAggregator,
    ethAggregator,
  };
}

async function provideLiquidity(fromToken, fromAmount, toToken, toAmount) {
  const { toContract, ethToToken } =
    toToken === "USDC" ? { toContract: usdcContract, ethToToken: ethToUsdcContract } : null;
  const web3signer = await ethToUsdcContract.signer.getAddress();

  await usdcContract.approve(usdcContract.address, tokenBalance);
  await usdcContract.transfer(ethToToken.address, tokenBalance.div(2));

  //if (toContract.allowance(web3signer, ethToToken.address) < toAmount)
  //  await toContract.approve(ethToToken.address, tokenBalance);

  //console.log(toAmount, ethers.utils.parseEther(toAmount.toString()));
  //await ethToToken.deposit(toAmount, {
  //  value: ethers.utils.parseEther(fromAmount),
  //  gasLimit: 2.9 * 10 ** 6,
  //});
}

export { provideLiquidity };
