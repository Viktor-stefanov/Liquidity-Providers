module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const usdc = await deploy("UsdcContract", { from: deployer, log: true });
  const pf = await deploy("PriceFeed", { from: deployer, log: true });

  await deploy("UsdcMock", {
    from: deployer,
    log: true,
    args: [18, 1],
  });

  await deploy("EthMock", {
    from: deployer,
    log: true,
    args: [18, 1500],
  });

  await deploy("EthToUsdc", {
    from: deployer,
    log: true,
    args: [usdc.address, pf.address],
  });
};
