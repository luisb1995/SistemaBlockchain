const hre = require("hardhat");

async function main() {
  console.log("🚀 Desplegando VotingSystem...");

  // 1. Obtener la factory del contrato
  const VotingSystem = await hre.ethers.getContractFactory("VotingSystem");

  // 2. Desplegar contrato
  const votingSystem = await VotingSystem.deploy();
  await votingSystem.waitForDeployment();

  // 3. Mostrar dirección en consola
  const contractAddress = await votingSystem.getAddress();
  console.log("✅ VotingSystem desplegado en:", contractAddress);
}

main().catch((error) => {
  console.error("❌ Error al desplegar:", error);
  process.exitCode = 1;
});