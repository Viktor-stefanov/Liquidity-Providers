module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const usdc = await deploy("UsdcContract", {
      from: deployer,
      log: true,
      args: ["0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199"],
    }),
    usdt = await deploy("UsdtContract", {
      from: deployer,
      log: true,
      args: ["0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199"],
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

  await deploy("EthToERC20", {
    from: deployer,
    log: true,
    args: [
      [usdt.address, usdc.address, ethMock.address, usdt.address, ethMock.address, usdc.address],
      ["UTMC", "UCMC", "ETH", "UTMC", "ETH", "UCMC"],
      pf.address,
    ],
  });
  await deploy("ERC20ToERC20", {
    from: deployer,
    log: true,
    args: [[usdt.address, usdc.address], ["UTMC", "UCMC"], pf.address],
  });
};
