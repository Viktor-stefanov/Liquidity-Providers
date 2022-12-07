const { ethers } = require("hardhat");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const usdc = await deploy("UsdcContract", {
      from: deployer,
      log: true,
      args: [
        [
          "0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199",
          "0xdD2FD4581271e230360230F9337D5c0430Bf44C0",
        ],
      ],
    }),
    usdt = await deploy("UsdtContract", {
      from: deployer,
      log: true,
      args: [
        [
          "0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199",
          "0xdD2FD4581271e230360230F9337D5c0430Bf44C0",
        ],
      ],
    }),
    usdcMock = await deploy("UsdcMock", {
      from: deployer,
      log: true,
      args: [1, 1],
    }),
    usdtMock = await deploy("UsdtMock", {
      from: deployer,
      log: true,
      args: [1, 1],
    }),
    ethMock = await deploy("EthMock", {
      from: deployer,
      log: true,
      args: [18, 1500],
    }),
    pf = await deploy("PriceFeed", {
      from: deployer,
      log: true,
      args: [
        [usdc.address, usdt.address, ethMock.address],
        [usdcMock.address, usdtMock.address, ethMock.address],
      ],
    });

  const ethToERC = await deploy("EthToERC20", {
      from: deployer,
      log: true,
      args: [],
    }),
    ercToErc = await deploy("ERC20ToERC20", {
      from: deployer,
      log: true,
      args: [[usdt.address, usdc.address], ["UTMC", "UCMC"], pf.address],
    }),
    diamondInit = await deploy("DiamondInit", { from: deployer, log: true });

  const initInterface = new ethers.utils.Interface(diamondInit.abi);
  const calldata = initInterface.encodeFunctionData("ethToERCInit", [
    [ethMock.address, usdt.address, ethMock.address, usdc.address],
    ["ETH", "UTMC", "ETH", "UCMC"],
    pf.address,
    ethers.utils.parseEther("0.02"),
    18,
  ]);

  const interface = new ethers.utils.Interface(ethToERC.abi);
  const functionSelectors = Object.keys(interface.functions).map((f) => interface.getSighash(f));
  const diamondCut = [ethToERC.address, 0, functionSelectors];

  await deploy("Diamond", {
    from: deployer,
    log: true,
    args: [[diamondCut], [deployer, diamondInit.address, calldata]],
  });
};
