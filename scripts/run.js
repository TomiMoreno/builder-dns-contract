const main = async () => {
  const [owner, superCoder] = await hre.ethers.getSigners();
  const domainContractFactory = await hre.ethers.getContractFactory("Domains");
  // We pass in "ninja" to the constructor when deploying
  const domainContract = await domainContractFactory.deploy("build");
  await domainContract.deployed();

  console.log("Contract deployed to:", domainContract.address);

  // We're passing in a second variable - value. This is the moneyyyyyyyyyy
  let txn = await domainContract.register("tomi", {
    value: hre.ethers.utils.parseEther("1000"),
  });
  await txn.wait();
  console.log("Minted domain tomi");

  const address = await domainContract.getAddress("tomi");
  console.log("Owner of domain tomi:", address);
  txn = await domainContract.setRecord("tomi", "Give me the hammer");

  try {
    txn = await domainContract
      .connect(superCoder)
      .setRecord("tomi", "I am the owner");
    await txn.wait();
    console.log("Robbed domain");
  } catch (error) {
    console.error(error.message);
    console.log("Could not rob domain");
  }

  console.log("Attempting to rob contract");
  try {
    txn = await domainContract.connect(superCoder).withdraw();
    await txn.wait();
    console.log("Robbed contract");
  } catch (error) {
    console.error(error.message);
    console.log("Could not rob contract");
  }

  let ownerBalance = await hre.ethers.provider.getBalance(owner.address);
  console.log(
    "Balance of owner before withdrawal:",
    hre.ethers.utils.formatEther(ownerBalance)
  );

  txn = await domainContract.connect(owner).withdraw();
  await txn.wait();

  const contractBalance = await hre.ethers.provider.getBalance(
    domainContract.address
  );
  ownerBalance = await hre.ethers.provider.getBalance(owner.address);

  console.log(
    "Contract balance after withdrawal:",
    hre.ethers.utils.formatEther(contractBalance)
  );
  console.log(
    "Balance of owner after withdrawal:",
    hre.ethers.utils.formatEther(ownerBalance)
  );
};

const runMain = async () => {
  try {
    await main();
    process.exit(0);
  } catch (error) {
    console.log(error);
    process.exit(1);
  }
};

runMain();
