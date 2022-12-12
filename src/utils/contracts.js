import { ethers } from "ethers";
import priceFeed from "../../deployments/localhost/PriceFeed.json";
import diamond from "../../deployments/localhost/Diamond.json";
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
    ethToERC20Contract = new ethers.Contract(diamond.address, ethToERC20.abi, web3signer),
    erc20ToErc20Contract = new ethers.Contract(diamond.address, erc20ToErc20.abi, web3signer),
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

    await ethToERC20Contract.depositEthToErc(pair, tokenAmount, {
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

    await erc20ToErc20Contract.depositErcToErc(pair, fromAmount, toAmount);
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
      ethers.utils.parseEther(fromAmount.toString()),
      ethers.utils.parseEther(toAmount.toString())
    );
}

async function ethToERC20Swap(ethAmount, token) {
  try {
    const pair = `ETH/${token}`;
    await ethToERC20Contract.ethToErc20Swap(pair, {
      value: ethers.utils.parseEther(ethAmount.toString()),
    });
  } catch (err) {
    console.log(`Error on swapping ETH for ERC20. ${err}`);
  }
}

async function ERC20ToEthSwap(token, tokenAmount) {
  try {
    const tokenContract = token === "UCMC" ? usdcContract : token === "UTMC" ? usdtContract : null,
      tokenInWei = ethers.utils.parseEther(tokenAmount),
      pool = `ETH/${token}`,
      user = await tokenContract.signer.getAddress();
    if ((await tokenContract.allowance(ethToERC20Contract.address, user)) < tokenInWei)
      await tokenContract.approve(ethToERC20Contract.address, tokenInWei);

    await ethToERC20Contract.erc20ToEthSwap(pool, tokenContract.address, tokenInWei);
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

    await erc20ToErc20Contract.ercToErcSwap(pair, amount, t1ToT2);
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

async function getEthToERC20Price(pool, ethAmount, ethToERC20) {
  const equivalentAmount = ethers.utils.formatEther(
    await ethToERC20Contract.getRelativePrice(pool, ethers.utils.parseEther(ethAmount), ethToERC20)
  );

  return equivalentAmount;
}

async function getERC20ToERC20Price(pool, fromToken, amount) {
  const t1ToT2 = pool.split("/")[0] === fromToken;
  const equivalentAmount = ethers.utils.formatEther(
    await erc20ToErc20Contract.getRelativePrice(pool, ethers.utils.parseEther(amount), t1ToT2)
  );

  return equivalentAmount;
}

async function getRelativePrice(pool, fromToken, toToken, fromAmount) {
  if (fromToken === "ETH" || toToken === "ETH") {
    return await getEthToERC20Price(pool, fromAmount, fromToken === "ETH");
  } else return await getERC20ToERC20Price(pool, fromToken, fromAmount);
}

async function getEthToERC20Deposit(token, amount, ethToERC20) {
  const pair = `ETH/${token}`;

  return (
    await ethToERC20Contract.estimateEthToErcDeposit(
      pair,
      ethers.utils.parseEther(amount),
      ethToERC20
    )
  ).map((amount) => parseFloat(ethers.utils.formatEther(amount)));
}

async function getERC20ToERC20Deposit(fromToken, toToken, amount, t1ToT2) {
  let pair = `${fromToken}/${toToken}`;
  if (!(await erc20ToErc20Contract.poolExists(pair))) pair = `${toToken}/${fromToken}`;

  return (
    await erc20ToErc20Contract.estimateErcToErcDeposit(
      pair,
      ethers.utils.parseEther(amount.toString()),
      t1ToT2
    )
  ).map((amount) => parseFloat(ethers.utils.formatEther(amount)));
}

async function estimateBalancedDeposit(fromToken, toToken, amount, inputDirection) {
  if (fromToken === "ETH" || toToken === "ETH") {
    const token = fromToken === "ETH" ? toToken : fromToken,
      ethToERC20 =
        (inputDirection === "fromTo" && fromToken === "ETH") ||
        (inputDirection === "toFrom" && toToken === "ETH");
    return await getEthToERC20Deposit(token, amount, ethToERC20, fromToken === "fromTo");
  } else
    return await getERC20ToERC20Deposit(fromToken, toToken, amount, inputDirection === "fromTo");
}

async function ethToErcWithdraw(pool, amount, t1ToT2) {
  return await ethToERC20Contract.ethToErcWithdraw(pool, amount, t1ToT2);
}

async function ercToErcWithdraw(pool, amount, t1ToT2) {
  return await erc20ToErc20Contract.ercToErcWithdraw(pool, amount, t1ToT2);
}

async function withdraw(pool, token, amount) {
  const t1ToT2 = token === pool.split("/")[0];
  if (pool.includes("ETH"))
    return await ethToErcWithdraw(pool, ethers.utils.parseEther(amount), t1ToT2);
  else return await ercToErcWithdraw(pool, ethers.utils.parseEther(amount), t1ToT2);
}

async function estimateWithdrawAmounts(pool, tokenAmount, t1ToT2) {
  return pool.includes("ETH")
    ? (
        await ethToERC20Contract.estimateWithdrawAmounts(
          pool,
          ethers.utils.parseEther(tokenAmount),
          t1ToT2
        )
      ).map((amount) => parseFloat(ethers.utils.formatEther(amount)).toFixed(5))
    : (
        await erc20ToErc20Contract.estimateErcToErcWithdrawAmounts(
          pool,
          ethers.utils.parseEther(tokenAmount),
          t1ToT2
        )
      ).map((amount) => parseFloat(ethers.utils.formatEther(amount)).toFixed(5));
}

async function getUserDeposits(pool) {
  return pool.includes("ETH")
    ? (await ethToERC20Contract.getUserDeposits(pool)).map((amount) =>
        ethers.utils.formatEther(amount)
      )
    : (await erc20ToErc20Contract.getUserDeposits(pool)).map((amount) =>
        ethers.utils.formatEther(amount)
      );
}

async function getPoolDeposits(pool) {
  return pool.includes("ETH")
    ? (await ethToERC20Contract.getPoolDeposits(pool)).map((amount) =>
        ethers.utils.formatEther(amount)
      )
    : (await erc20ToErc20Contract.getPoolDeposits(pool)).map((amount) =>
        ethers.utils.formatEther(amount)
      );
}

async function getAllTokens() {
  let tokens = new Set();
  const pools = await ethToERC20Contract.getPools();
  for (let pool of pools) {
    const [tok1, tok2] = pool.split("/");

    tokens.add(tok1);
    tokens.add(tok2);
  }

  return Array.from(tokens);
}

async function getAllPools() {
  return await ethToERC20Contract.getPools();
}

export {
  withdraw,
  estimateWithdrawAmounts,
  getPoolDeposits,
  getUserDeposits,
  provideLiquidity,
  ethToERC20Swap,
  getRelativePrice,
  getAllTokens,
  swapTokens,
  estimateBalancedDeposit,
  getAllPools,
};
