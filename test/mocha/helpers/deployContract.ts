import { ethers } from "hardhat";

export default async function deployContract(
  contractName: string,
  constructorArgs: any[]
) {
  const factory = await ethers.getContractFactory(contractName);
  let contract = await factory.deploy(...(constructorArgs || []));
  await contract.deployed();
  return contract;
}
