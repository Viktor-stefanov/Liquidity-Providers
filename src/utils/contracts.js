import { ethers } from "ethers";
import priceFeed from "../../deployments/localhost/PriceFeed.json";
import usdtMock from "../../deployments/localhost/UsdtMock.json";
import usdcMock from "../../deployments/localhost/UsdcMock.json";
import ethMock from "../../deployments/localhost/EthMock.json";
import ethToERC20 from "../../deployments/localhost/EthToERC20.json";
import erc20ToErc20 from "../../deployments/localhost/ERC20ToERC20.json";
import usdc from "../../deployments/localhost/UsdcContract.json";
import usdt from "../../deployments/localhost/UsdtContract.json";

const { ethToERC20Contract, erc20ToErc20Contract, priceFeedContract, usdcContract, usdtContract } =
  await instantiateContracts();

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
    erc20ToErc20Contract = new ethers.Contract(erc20ToErc20.address, erc20ToErc20.abi, web3signer),
    usdcContract = new ethers.Contract(usdc.address, usdc.abi, web3signer),
    usdtContract = new ethers.Contract(usdt.address, usdt.abi, web3signer);

  return {
    ethToERC20Contract,
    erc20ToErc20Contract,
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
    const pair = `ETH/${token}`,
      tokenContract = token === "UCMC" ? usdcContract : token === "UTMC" ? usdtContract : null,
      user = await ethToERC20Contract.signer.getAddress();

    if ((await tokenContract.allowance(user, ethToERC20Contract.address)) < tokenAmount)
      await tokenContract.approve(ethToERC20Contract.address, tokenAmount);

    await ethToERC20Contract.deposit(pair, tokenAmount, {
      value: ethers.utils.parseEther(ethAmount.toString()),
    });
  } catch (err) {
    console.log(`Error on depositing ETH/ERC20 pair. ${err}`);
  }
}

async function depositERC20AndERC20(fromToken, toToken, fromAmount, toAmount) {
  try {
    const pair = `${fromToken}/${toToken}`,
      user = await erc20ToErc20Contract.signer.getAddress(),
      tok1Contract =
        fromToken === "UCMC" ? usdcContract : fromToken === "UTMC" ? usdtContract : null,
      tok2Contract = toToken === "UCMC" ? usdcContract : toToken === "UTMC" ? usdtContract : null;

    if ((await tok1Contract.allowance(user, erc20ToErc20Contract.address)) < fromAmount)
      await tok1Contract.approve(erc20ToErc20Contract.address, fromAmount);

    if ((await tok2Contract.allowance(user, erc20ToErc20Contract.address)) < toAmount)
      await tok2Contract.approve(erc20ToErc20Contract.address, toAmount);

    await erc20ToErc20Contract.deposit(pair, fromAmount, toAmount);
  } catch (err) {
    console.log(`Error on depositing ERC20/ERC20 pair. ${err}`);
  }
}

async function provideLiquidity(fromToken, fromAmount, toToken, toAmount) {
  if (fromToken === "ETH" || toToken === "ETH") {
    const [token, ethAmount, tokenAmount] =
      fromToken === "ETH" ? [toToken, fromAmount, toAmount] : [fromToken, toAmount, fromAmount];
    await depositEthAndERC20(ethAmount, token, ethers.utils.parseEther(tokenAmount.toString()));
  } else
    await depositERC20AndERC20(
      fromToken,
      toToken,
      ethers.utils.parseEther(fromAmount),
      ethers.utils.parseEther(toAmount)
    );
}

async function ethToERC20Swap(ethAmount, token) {
  try {
    const pair = `ETH/${token}`;
    await ethToERC20Contract.ethToERC20Swap(pair, {
      value: ethers.utils.parseEther(ethAmount.toString()),
    });
  } catch (err) {
    console.log(`Error on swapping ETH for ERC20. ${err}`);
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

async function ERC20ToERC20Swap(fromToken, toToken, amount) {
  try {
    let pair = `${fromToken}/${toToken}`,
      t1ToT2 = true,
      tokenCon = fromToken === "UCMC" ? usdcContract : fromToken === "UTMC" ? usdtContract : null;

    if (!(await erc20ToErc20Contract.poolExists(pair))) {
      pair = `${toToken}/${fromToken}`;
      t1ToT2 = false;
      tokenCon = toToken === "UCMC" ? usdcContract : toToken === "UTMC" ? usdtContract : null;
    }

    const user = await tokenCon.signer.getAddress();
    if ((await tokenCon.allowance(erc20ToErc20Contract.address, user)) < amount)
      await tokenCon.approve(erc20ToErc20Contract.address, amount);

    console.log(await erc20ToErc20Contract.poolExists(pair));
    console.log(tokenCon.address);
    await erc20ToErc20Contract.swap(pair, amount, t1ToT2);
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
    await ERC20ToERC20Swap(fromToken, toToken, ethers.utils.parseEther(fromAmount));
  }
}

async function getEthToERC20Price(token, ethAmount, ethToERC20) {
  const pair = `ETH/${token}`,
    equivalentAmount = ethers.utils.formatEther(
      await ethToERC20Contract.getRelativePrice(
        pair,
        ethers.utils.parseEther(ethAmount),
        ethToERC20
      )
    );

  return equivalentAmount;
}

async function getERC20ToERC20Price(fromToken, toToken, amount) {
  let pair = `${fromToken}/${toToken}`,
    t1ToT2 = true;
  if (!(await erc20ToErc20Contract.poolExists(pair))) {
    pair = `${toToken}/${fromToken}`;
    t1ToT2 = false;
  }

  const equivalentAmount = ethers.utils.formatEther(
    await erc20ToErc20Contract.getRelativePrice(pair, ethers.utils.parseEther(amount), t1ToT2)
  );

  return equivalentAmount;
}

async function getRelativePrice(fromToken, toToken, fromAmount) {
  if (fromToken === "ETH" || toToken === "ETH") {
    const token = fromToken === "ETH" ? toToken : fromToken,
      ethToERC20 = fromToken === "ETH";
    return await getEthToERC20Price(token, fromAmount, ethToERC20);
  } else return await getERC20ToERC20Price(fromToken, toToken, fromAmount);
}

async function getEthToERC20Deposit(token, amount, ethToERC20) {
  const pair = `ETH/${token}`;

  return parseFloat(
    ethers.utils.formatEther(
      (
        await ethToERC20Contract.estimateEthToERC20Deposit(
          pair,
          ethers.utils.parseEther(amount),
          ethToERC20
        )
      )
        .div(10 ** 8)
        .div(10 ** 8)
    )
  ).toFixed(10);
}

async function getERC20ToERC20Deposit(fromToken, toToken, amount, t1ToT2) {
  let pair = `${fromToken}/${toToken}`;
  if (!(await erc20ToErc20Contract.poolExists(pair))) pair = `${toToken}/${fromToken}`;

  return ethers.utils.formatEther(
    (await erc20ToErc20Contract.estimateDeposit(pair, ethers.utils.parseEther(amount), t1ToT2))
      .div(10 ** 8)
      .div(10 ** 8)
  );
}

async function estimateBalancedDeposit(fromToken, toToken, amount, inputDirection) {
  if (fromToken === "ETH" || toToken === "ETH") {
    const token = fromToken === "ETH" ? toToken : fromToken,
      ethToERC20 =
        (inputDirection === "fromTo" && fromToken === "ETH") ||
        (inputDirection === "toFrom" && toToken === "ETH")
          ? true
          : false;
    return await getEthToERC20Deposit(token, amount, ethToERC20);
  } else
    return await getERC20ToERC20Deposit(fromToken, toToken, amount, inputDirection === "fromTo");
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
  for (let contract of contracts) {
    const [tok1, tok2] = contract.split("/");

    tokens.add(tok1);
    tokens.add(tok2);
  }

  return Array.from(tokens);
}

async function getTokenPrices() {
  // TODO: CLEAN THIS MESS UP!!!
  let tokens = [];
  const pairs = await ethToERC20Contract.getContracts();
  for (let pair of pairs) {
    const pool = await ethToERC20Contract.getPool(pair),
      tok1Price = parseInt(await priceFeedContract.getPrice(pool[2])),
      tok2Price = parseInt(await priceFeedContract.getPrice(pool[3])),
      [tok1Symbol, tok2Symbol] = pair.split("/");

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

export {
  provideLiquidity,
  getEthToERC20Pools,
  getTokenPrices,
  ethToERC20Swap,
  getRelativePrice,
  getAllTokens,
  swapTokens,
  estimateBalancedDeposit,
};
