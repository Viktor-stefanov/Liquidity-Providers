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
    }),
    ethToERC = await deploy("EthToERC20", {
      from: deployer,
      log: true,
      args: [],
    }),
    ercToErc = await deploy("ERC20ToERC20", {
      from: deployer,
      log: true,
      args: [],
    }),
    diamondInit = await deploy("DiamondInit", { from: deployer, log: true });

  const initInterface = new ethers.utils.Interface(diamondInit.abi);
  const calldata = initInterface.encodeFunctionData("ethToERCInit", [
    [ethMock.address, usdt.address, ethMock.address, usdc.address, usdt.address, usdc.address],
    ["ETH", "UTMC", "ETH", "UCMC", "UTMC", "UCMC"],
    pf.address,
    ethers.utils.parseEther("0.02"),
    18,
  ]);

  const ethInterface = new ethers.utils.Interface(ethToERC.abi),
    ethFunctions = Object.keys(ethInterface.functions),
    ethToERCSelectors = ethFunctions.map((f) => ethInterface.getSighash(f)),
    ercInterface = new ethers.utils.Interface(ercToErc.abi),
    ercFunctions = Object.keys(ercInterface.functions).filter((f) => !ethFunctions.includes(f)),
    ercToErcSelectors = ercFunctions.map((f) => ercInterface.getSighash(f));

  const diamondCuts = [
    [ethToERC.address, 0, ethToERCSelectors],
    [ercToErc.address, 0, ercToErcSelectors],
  ];

  await deploy("Diamond", {
    from: deployer,
    log: true,
    args: [diamondCuts, [deployer, diamondInit.address, calldata]],
  });
};
