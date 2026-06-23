const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("正在编译并部署 Voting 合约...");
  
  const Voting = await hre.ethers.getContractFactory("Voting");
  const voting = await Voting.deploy();

  await voting.waitForDeployment();
  const votingAddress = await voting.getAddress();
  const tokenAddress = await voting.votingToken();

  console.log("-----------------------------------------");
  console.log(`Voting 合约已成功部署!`);
  console.log(`Voting 地址: ${votingAddress}`);
  console.log(`MockERC20 代币地址: ${tokenAddress}`);
  console.log("-----------------------------------------");

  // 自动将新地址更新到 index.html 中
  const indexPath = path.join(__dirname, "../index.html");
  if (fs.existsSync(indexPath)) {
    let indexContent = fs.readFileSync(indexPath, "utf8");
    
    // 正则表达式匹配 const CONTRACT_ADDRESS = "0x...";
    const regex = /const CONTRACT_ADDRESS = "0x[a-fA-F0-9]{40}";/g;
    if (regex.test(indexContent)) {
      indexContent = indexContent.replace(regex, `const CONTRACT_ADDRESS = "${votingAddress}";`);
      fs.writeFileSync(indexPath, indexContent, "utf8");
      console.log(`✅ 已自动将 index.html 中的 CONTRACT_ADDRESS 更新为: ${votingAddress}`);
    } else {
      console.log("⚠️ 无法在 index.html 中匹配到 CONTRACT_ADDRESS 常量，请手动更新。");
    }
  } else {
    console.log("⚠️ 未找到 index.html 文件，无法自动更新合约地址。");
  }
  console.log("-----------------------------------------");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
