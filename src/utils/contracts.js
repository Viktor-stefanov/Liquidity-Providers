import { BigNumber, ethers } from "ethers";
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
  try {
    const tokenContract = token === "UCMC" ? usdcContract : token === "UTMC" ? usdtContract : null,
      user = await ethToERC20Contract.signer.getAddress();
    if ((await tokenContract.allowance(user, ethToERC20Contract.address)) < tokenAmount)
      await tokenContract.approve(ethToERC20Contract.address, tokenAmount);

    await ethToERC20Contract.depositEthToERC20(
      ethMock.address,
      tokenContract.address,
      tokenAmount,
      {
        value: ethers.utils.parseEther(ethAmount.toString()),
        //gasLimit: 2.9 * 10 ** 6,
      }
    );
    return true;
  } catch (err) {
    console.log(`Error on depositing ETH/ERC20 pair. ${err}`);
    return false;
  }
}

async function depositERC20AndERC20(fromToken, fromAmount, toToken, toAmount) {
  try {
    const tok1Con =
        fromToken === "UCMC" ? usdcContract : fromToken === "UTMC" ? usdtContract : null,
      tok2Con = toToken === "UCMC" ? usdcContract : toToken === "UTMC" ? usdtContract : null,
      user = await ethToERC20Contract.signer.getAddress();

    if ((await tok1Con.allowance(user, ethToERC20Contract.address)) < fromAmount)
      await tok1Con.approve(ethToERC20Contract.address, fromAmount);

    if ((await tok2Con.allowance(user, ethToERC20Contract.address)) < toAmount)
      await tok2Con.approve(ethToERC20Contract.address, toAmount);

    await (
      await ethToERC20Contract.depositERC20ToERC20(
        tok1Con.address,
        tok2Con.address,
        fromAmount,
        toAmount,
        {
          gasLimit: 2.9 * 10 ** 6,
        }
      )
    ).wait();
    return true;
  } catch (err) {
    console.log(`Error on depositing ETH/ERC20 pair. ${err}`);
    return false;
  }
}

async function provideLiquidity(fromToken, fromAmount, toToken, toAmount) {
  const token = fromToken === "ETH" ? toToken : toToken === "ETH" ? fromToken : null,
    ethAmount = fromToken === "ETH" ? fromAmount : toAmount,
    tokenAmount = fromToken === "ETH" ? toAmount : fromAmount;

  if (token) await depositEthAndERC20(ethAmount, token, tokenAmount); // ETH->ERC20/ERC20->ETH
  else await depositERC20AndERC20(fromToken, fromAmount, toToken, toAmount);
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
  let tokens = new Set();
  const contracts = await ethToERC20Contract.getContracts();
  for (let i = 0; i < contracts.length; i += 2) {
    const tok1Con = contracts[i],
      tok2Con = contracts[i + 1],
      pool = await ethToERC20Contract.getPool(tok1Con, tok2Con);

    tokens.add(pool[0]);
    tokens.add(pool[1]);
  }

  return Array.from(tokens);
}

async function getTokenPrices() {
  // TODO: CLEAN THIS MESS UP!!!
  let tokens = [];
  const contracts = await ethToERC20Contract.getContracts();
  for (let i = 0; i < contracts.length; i += 2) {
    const tok1Con = contracts[i],
      tok2Con = contracts[i + 1],
      tok1Price = parseInt(await priceFeedContract.getPrice(tok1Con)),
      tok2Price = parseInt(await priceFeedContract.getPrice(tok2Con)),
      tok1Symbol =
        tok1Con === ethMock.address ? "ETH" : await ethToERC20Contract.getSymbol(tok1Con),
      tok2Symbol =
        tok2Con === ethMock.address ? "ETH" : await ethToERC20Contract.getSymbol(tok2Con);

    let t1In, t2In;
    for (let tokenPair of tokens) {
      if (tokenPair.name === tok1Symbol) t1In = true;
      if (tokenPair.name === tok2Symbol) t2In = true;
    }

    if (!t1In) tokens.push({ name: tok1Symbol, price: tok1Price });
    if (!t2In) tokens.push({ name: tok2Symbol, price: tok2Price });
  }

  return tokens;
}

async function ethToERC20Swap(ethAmount, token) {
  try {
    const tokenContract = token === "UCMC" ? usdcContract : token === "UTMC" ? usdtContract : null;
    await (
      await ethToERC20Contract.ethToERC20Swap(ethMock.address, tokenContract.address, {
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

    await ethToERC20Contract.ERC20ToEthSwap(ethMock.address, tokenContract.address, tokenAmount);
    return true;
  } catch (err) {
    console.log(`Error on swapping ERC20 for ETH. ${err}`);
    return false;
  }
}

async function ERC20ToERC20Swap(token, toToken, tokenAmount) {
  try {
    const tok1Con = token === "UCMC" ? usdcContract : token === "UTMC" ? usdtContract : null,
      tok2Con = toToken === "UCMC" ? usdcContract : toTOken === "UTMC" ? usdtContract : null,
      user = await tok1Con.signer.getAddress();
    if ((await tok1Con.allowance(ethToERC20Contract.address, user)) < tokenAmount)
      await tok1Con.approve(ethToERC20Contract.address, tokenAmount);

    await ethToERC20Contract.ERC20ToERC20Swap(tok1Con.address, tok2Con.address, tokenAmount);
  } catch (err) {
    console.log(`Error on swapping ERC20 for ERC20. ${err}`);
  }
}

async function swapTokens(fromToken, fromAmount, toToken) {
  if (fromToken === "ETH") {
    await ethToERC20Swap(fromAmount, toToken);
  } else if (toToken === "ETH") {
    await ERC20ToEthSwap(fromToken, fromAmount);
  } else {
    await ERC20ToERC20Swap(fromToken, toToken, fromAmount);
  }
}

async function getRelativePrice(fromToken, toToken) {
  let t1ToT2;
  if (fromToken === "ETH" || toToken === "ETH") {
    const token = fromToken === "ETH" ? toToken : toToken === "ETH" ? fromToken : null,
      tokenContract = token === "UCMC" ? usdcContract : token === "UTMC" ? usdtContract : null;
    t1ToT2 = ethers.utils.formatEther(
      await ethToERC20Contract.getRelativePrice(ethMock.address, tokenContract.address)
    );
    t1ToT2 = fromToken === "ETH" ? t1ToT2 : 1 / t1ToT2;
  } else {
    const t1Con = fromToken === "UCMC" ? usdcContract : fromToken === "UTMC" ? usdtContract : null,
      t2Con = toToken === "UCMC" ? usdcContract : toToken === "UTMC" ? usdtContract : null;
    t1ToT2 = ethers.utils.formatEther(
      (await ethToERC20Contract.getRelativePrice(t1Con.address, t2Con.address)).div(
        "1000000000000000000"
      )
    );
  }

  return [t1ToT2, 1 / t1ToT2];
}

async function estimateEthAndERC20Deposit(token, direction) {
  const tokenContract = token === "UCMC" ? usdcContract : token === "UTMC" ? usdtContract : null;
  if (await ethToERC20Contract.poolIsSeeded(ethMock.address, tokenContract.address)) {
    const [fromTo, toFrom] = await ethToERC20Contract.estimateFromToDeposit(
      ethMock.address,
      tokenContract.address
    );

    return direction === "ERC20ToEth"
      ? [ethers.utils.formatEther(fromTo), parseInt(toFrom)]
      : [parseInt(toFrom), ethers.utils.formatEther(fromTo)];
  } else {
    const ethPrice = await priceFeedContract.getPrice(ethMock.address),
      tokenPrice = await priceFeedContract.getPrice(tokenContract.address);
    return [ethPrice, tokenPrice];
  }
}

async function estimateERC20AndERC20Deposit(token1, token2) {
  const tok1Con = token1 === "UCMC" ? usdcContract : token1 === "UTMC" ? usdtContract : null,
    tok2Con = token2 === "UCMC" ? usdcContract : token2 === "UTMC" ? usdtContract : null;

  if (await ethToERC20Contract.poolIsSeeded(tok1Con.address, tok2Con.address)) {
    const [fromTo, toFrom] = await ethToERC20Contract.estimateFromToDeposit(
      tok1Con.address,
      tok2Con.address
    );
    console.log(fromTo, toFrom);
    return [fromTo, toFrom];
  } else {
    const t1Price = await priceFeedContract.getPrice(tok1Con.address),
      t2Price = await priceFeedContract.getPrice(tok2Con.address);
    return [t1Price, t2Price];
  }
}

async function estimateDeposit(fromToken, toToken) {
  const direction = fromToken === "ETH" ? "ethToERC20" : toToken === "ETH" ? "ERC20ToEth" : null,
    token = fromToken === "ETH" ? toToken : toToken === "ETH" ? fromToken : null;

  if (direction) return estimateEthAndERC20Deposit(token, direction);
  else return estimateERC20AndERC20Deposit(fromToken, toToken);
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
