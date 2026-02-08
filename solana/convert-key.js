const bs58 = require("bs58");
const fs = require("fs");

const privateKey = process.argv[2];
if (!privateKey) {
  console.error("Usage: node convert-key.js <YOUR_PHANTOM_BASE58_PRIVATE_KEY>");
  process.exit(1);
}

const decoded = bs58.decode(privateKey);
fs.writeFileSync(".keys/deployer.json", JSON.stringify(Array.from(decoded)));
console.log("Key saved to .keys/deployer.json");
