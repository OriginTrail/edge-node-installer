#!/usr/bin/env node
import { Wallet } from "ethers";
import fs from "fs";
import path from "path";

const PUBLISH_COUNT = 1;

const INPUT   = "./.env";
const BACKUP  = "./.env.backup";
const KEYS_OUT = "./wallets.txt";

function generateNodeName() {
  const adjectives = [
    "cyber", "shadow", "quantum", "stealth", "iron",
    "crypto", "neon", "vortex", "radix", "atomic"
  ];
  const nouns = [
    "sentinel", "guardian", "bastion", "matrix",
    "fortress", "warden", "shield", "vector", "cipher", "knight"
  ];
  const adj  = adjectives[Math.floor(Math.random() * adjectives.length)];
  const noun = nouns[Math.floor(Math.random() * nouns.length)];
  const num  = Math.floor(Math.random() * 900 + 100);
  return `${adj}-${noun}-${num}`;
}

if (!fs.existsSync(INPUT))
  throw new Error(".env fajl nije pronađen – kreiraj ga pa ponovo pokreni skript.");

fs.copyFileSync(INPUT, BACKUP);
console.log(`Postojeći .env je sačuvan kao ${path.basename(BACKUP)}`);

const make = label => {
  const w = Wallet.createRandom();
  return { label, address: w.address, privateKey: w.privateKey };
};

const publishWallets = Array.from({ length: PUBLISH_COUNT },
  (_, i) => make(`publish${i + 1}`));

const extraWallets = [
  make("neurowebMgmt"), make("neurowebOp"),
  make("baseMgmt"),     make("baseOp"),
  make("gnosisMgmt"),   make("gnosisOp")
];

const wallets = [...publishWallets, ...extraWallets];

let envText = fs.readFileSync(INPUT, "utf-8");

envText = envText.replace(
  /^PUBLISH_WALLET_\d{2}_(PUBLIC|PRIVATE)_KEY=.*\n?/gm,
  ""
);

let publishBlock = "";
publishWallets.forEach((w, i) => {
  const idx = String(i + 1).padStart(2, "0");
  publishBlock +=
    `PUBLISH_WALLET_${idx}_PUBLIC_KEY=${w.address}\n` +
    `PUBLISH_WALLET_${idx}_PRIVATE_KEY=${w.privateKey}\n`;
});

envText = envText.replace(
  /(DEFAULT_PUBLISH_BLOCKCHAIN=.*\n(?:#.*\n)+)/,
  `$1${publishBlock}`
);

const NODE_NAME = generateNodeName();
envText = envText
  .replace(/NEUROWEB_NODE_NAME=.*/, `NEUROWEB_NODE_NAME=${NODE_NAME}`)
  .replace(/BASE_NODE_NAME=.*/,     `BASE_NODE_NAME=${NODE_NAME}`)
  .replace(/GNOSIS_NODE_NAME=.*/,   `GNOSIS_NODE_NAME=${NODE_NAME}`);

const put = (regex, val) => { envText = envText.replace(regex, val); };

// NEUROWEB
put(/NEUROWEB_MANAGEMENT_KEY_PUBLIC_ADDRESS=.*/,
    `NEUROWEB_MANAGEMENT_KEY_PUBLIC_ADDRESS=${extraWallets[0].address}`);
put(/NEUROWEB_OPERATIONAL_KEY_PUBLIC_ADDRESS=.*/,
    `NEUROWEB_OPERATIONAL_KEY_PUBLIC_ADDRESS=${extraWallets[1].address}`);
put(/NEUROWEB_OPERATIONAL_KEY_PRIVATE_ADDRESS=.*/,
    `NEUROWEB_OPERATIONAL_KEY_PRIVATE_ADDRESS=${extraWallets[1].privateKey}`);

// BASE
put(/BASE_MANAGEMENT_KEY_PUBLIC_ADDRESS=.*/,
    `BASE_MANAGEMENT_KEY_PUBLIC_ADDRESS=${extraWallets[2].address}`);
put(/BASE_OPERATIONAL_KEY_PUBLIC_ADDRESS=.*/,
    `BASE_OPERATIONAL_KEY_PUBLIC_ADDRESS=${extraWallets[3].address}`);
put(/BASE_OPERATIONAL_KEY_PRIVATE_ADDRESS=.*/,
    `BASE_OPERATIONAL_KEY_PRIVATE_ADDRESS=${extraWallets[3].privateKey}`);

// GNOSIS
put(/GNOSIS_MANAGEMENT_KEY_PUBLIC_ADDRESS=.*/,
    `GNOSIS_MANAGEMENT_KEY_PUBLIC_ADDRESS=${extraWallets[4].address}`);
put(/GNOSIS_OPERATIONAL_KEY_PUBLIC_ADDRESS=.*/,
    `GNOSIS_OPERATIONAL_KEY_PUBLIC_ADDRESS=${extraWallets[5].address}`);
put(/GNOSIS_OPERATIONAL_KEY_PRIVATE_ADDRESS=.*/,
    `GNOSIS_OPERATIONAL_KEY_PRIVATE_ADDRESS=${extraWallets[5].privateKey}`);

fs.writeFileSync(INPUT, envText);
console.log(`.env je uspešno ažuriran (NODE_NAME = ${NODE_NAME})`);

const dump = wallets.map(w =>
  `${w.label.toUpperCase()}\n  Address: ${w.address}\n  Private: ${w.privateKey}\n`
).join("\n");

fs.writeFileSync(KEYS_OUT, dump);
console.log(`Svi ključevi su upisani u ${KEYS_OUT}`);
