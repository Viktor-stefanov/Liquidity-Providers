module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const addr = await deploy("MockV3Aggregator", { from: deployer, log: true, args: [16, 1500] });
  await deploy("PriceFeed", { from: deployer, log: true });
};
