const hre = require("hardhat");

async function main() {
  console.log("🔍 Verificando estado del contrato...");
  
  const [signer] = await hre.ethers.getSigners();
  console.log("👤 Cuenta:", signer.address);
  
  const balance = await hre.ethers.provider.getBalance(signer.address);
  console.log("💰 Balance:", hre.ethers.formatEther(balance), "ETH");
  
  const network = await hre.ethers.provider.getNetwork();
  console.log("🌐 Red:", network.name, "Chain ID:", network.chainId.toString());
  
  // Verificar si hay contratos desplegados
  const contractAddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3";
  const code = await hre.ethers.provider.getCode(contractAddress);
  
  if (code === "0x") {
    console.log("❌ No hay contrato en esa dirección");
    console.log("💡 Necesitas redesplegar:");
    console.log("   npx hardhat run scripts/deploy.js --network localhost");
  } else {
    console.log("✅ Contrato encontrado en:", contractAddress);
    console.log("📊 Código del contrato tiene", code.length, "caracteres");
  }
}

main().catch(console.error);