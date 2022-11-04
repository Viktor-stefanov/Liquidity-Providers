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

async function depositEthAndERC20(ethAmount, token, tokenAmount) {
  const tokenContract = token === "UCMC" ? usdcContract : token === "UTMC" ? usdtContract : null,
    user = await ethToERC20Contract.signer.getAddress();

  try {
    if ((await tokenContract.allowance(user, ethToERC20Contract.address)) < tokenAmount)
      await tokenContract.approve(ethToERC20Contract.address, tokenAmount);

    await (
      await ethToERC20Contract.depositEthToERC20(tokenContract.address, tokenAmount, {
        value: ethers.utils.parseEther(ethAmount.toString()),
        gasLimit: 2.9 * 10 ** 6,
      })
    ).wait();
    return true;
  } catch (err) {
    console.log(`Error on depositing ETH/ERC20 pair. ${err}`);
    return false;
  }
}

async function provideLiquidity(fromToken, fromAmount, toToken, toAmount) {
  const token = fromToken === "ETH" ? toToken : toToken === "ETH" ? fromToken : null;
  if (token) await depositEthAndERC20(fromAmount, token, toAmount); // ETH->ERC20/ERC20->ETH
  else {
    // ERC20->ERC20
  }
}

async function getEthToERC20Pools() {
  let pairs = [];
  const contracts = await ethToERC20Contract.getContracts();
  for (let contract of contracts) {
    const contractPool = await ethToERC20Contract.getPool(contract);

    pairs.push({
      from: "ETH",
      to: contractPool[0],
      poolName: `ETH/${contractPool[0]}`,
      ethPool: ethers.utils.formatEther(contractPool[1]),
      tokenPool: parseInt(contractPool[2]),
    });
  }

  return pairs;
}

async function getAllTokens() {
  let tokens = [];
  const contracts = await ethToERC20Contract.getContracts();
  for (let contract of contracts) {
    const contractPool = await ethToERC20Contract.getPool(contract);
    tokens.push(contractPool[0]);
  }
  tokens.push("ETH");

  return tokens;
}

async function getTokenPrices() {
  let tokens = [];
  const contracts = await ethToERC20Contract.getContracts();
  for (let contract of contracts) {
    const tokenPrice = parseInt(await priceFeedContract.getPrice(contract)),
      symbol = (await ethToERC20Contract.getPool(contract)).symbol;
    tokens.push({ name: symbol, price: tokenPrice });
  }
  tokens.push({ name: "ETH", price: parseInt(await priceFeedContract.getPrice(ethMock.address)) });

  return tokens;
}

async function ethToERC20Swap(ethAmount, token) {
  try {
    const tokenContract = token === "UCMC" ? usdcContract : token === "UTMC" ? usdtContract : null;
    await (
      await ethToERC20Contract.ethToERC20Swap(tokenContract.address, {
        value: ethers.utils.parseEther(ethAmount.toString()),
      })
    ).wait();
    return true;
  } catch (err) {
    console.log(`Error on swapping ETH for ERC20. ${err}`);
    return false;
  }
}

async function ERC20ToEthSwap(token, tokenAmount) {
  try {
    const tokenContract = token === "UCMC" ? usdcContract : token === "UTMC" ? usdtContract : null,
      user = await tokenContract.signer.getAddress();
    if ((await tokenContract.allowance(ethToERC20Contract.address, user)) < tokenAmount)
      await tokenContract.approve(ethToERC20Contract.address, tokenAmount);

    await ethToERC20Contract.ERC20ToEthSwap(tokenContract.address, tokenAmount);
    return true;
  } catch (err) {
    console.log(`Error on swapping ERC20 for ETH. ${err}`);
    return false;
  }
}

async function swapTokens(fromToken, fromAmount, toToken) {
  if (fromToken === "ETH") {
    await ethToERC20Swap(fromAmount, toToken);
  } else if (toToken === "ETH") {
    await ERC20ToEthSwap(fromToken, fromAmount);
  }
}

async function getRelativePrice(fromToken, toToken) {
  const token = fromToken === "ETH" ? toToken : toToken === "ETH" ? fromToken : null;
  const tokenContract = token === "UCMC" ? usdcContract : token === "UTMC" ? usdtContract : null;
  let ethToToken, tokenToEth;
  if (fromToken === "ETH") {
    [ethToToken, tokenToEth] = await ethToERC20Contract.getRelativePrice(tokenContract.address);
    ethToToken = parseInt(ethToToken);
    tokenToEth = ethers.utils.formatEther(tokenToEth);
  } else if (toToken === "ETH") {
    [tokenToEth, ethToToken] = await ethToERC20Contract.getRelativePrice(tokenContract.address);
    tokenToEth = parseInt(tokenToEth);
    ethToToken = ethers.utils.formatEther(ethToToken);
  }

  return [ethToToken, tokenToEth];
}

async function estimateDeposit(fromToken, toToken) {
  const token = fromToken === "ETH" ? toToken : toToken === "ETH" ? fromToken : null,
    tokenContract = token === "UCMC" ? usdcContract : token === "UTMC" ? usdtContract : null;

  if (await ethToERC20Contract.poolIsSeeded(tokenContract.address)) {
    if (token) {
      const [tcEstimate, fcEstimate] = await ethToERC20Contract.estimateDepositValues(
        tokenContract.address
      );
      return [fcEstimate, tcEstimate];
    }
  } else {
    if (token) {
      const tokenPrice = parseInt(await priceFeedContract.getPrice(tokenContract.address)),
        ethPrice = parseInt(await priceFeedContract.getPrice(ethMock.address));
      return [ethPrice, tokenPrice];
    }
  }
}

export {
  provideLiquidity,
  getEthToERC20Pools,
  getTokenPrices,
  ethToERC20Swap,
  getRelativePrice,
  getAllTokens,
  swapTokens,
  estimateDeposit,
};
