#!/usr/bin/env node

import { Wallet } from "ethers";
import fs from "fs";
import path from "path";

const PUBLISH_COUNT = 1;

const INPUT = "./.env";
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
    const adj = adjectives[Math.floor(Math.random() * adjectives.length)];
    const noun = nouns[Math.floor(Math.random() * nouns.length)];
    const num = Math.floor(Math.random() * 900 + 100);
    return `${adj}-${noun}-${num}`;
}

if (!fs.existsSync(INPUT))
    throw new Error(".env file doesn't exist — check if the previous step was done correctly");

const make = label => {
    const w = Wallet.createRandom();
    return { label, address: w.address, privateKey: w.privateKey };
};

const publishWallets = Array.from({ length: PUBLISH_COUNT },
    (_, i) => make(`publish${i + 1}`));

// Use the same management wallet for all chains
const sharedMgmt = make("sharedMgmt"); // One management wallet for all chains

const extraWallets = [
    sharedMgmt, make("neurowebOp"),
    make("baseOp"),
    make("gnosisOp")
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
    .replace(/BASE_NODE_NAME=.*/, `BASE_NODE_NAME=${NODE_NAME}`)
    .replace(/GNOSIS_NODE_NAME=.*/, `GNOSIS_NODE_NAME=${NODE_NAME}`);

const put = (regex, val) => { envText = envText.replace(regex, val); };

// NEUROWEB
put(/NEUROWEB_MANAGEMENT_KEY_PUBLIC_ADDRESS=.*/,
    `NEUROWEB_MANAGEMENT_KEY_PUBLIC_ADDRESS=${sharedMgmt.address}`);
put(/NEUROWEB_OPERATIONAL_KEY_PUBLIC_ADDRESS=.*/,
    `NEUROWEB_OPERATIONAL_KEY_PUBLIC_ADDRESS=${extraWallets[1].address}`);
put(/NEUROWEB_OPERATIONAL_KEY_PRIVATE_ADDRESS=.*/,
    `NEUROWEB_OPERATIONAL_KEY_PRIVATE_ADDRESS=${extraWallets[1].privateKey}`);

// BASE
put(/BASE_MANAGEMENT_KEY_PUBLIC_ADDRESS=.*/,
    `BASE_MANAGEMENT_KEY_PUBLIC_ADDRESS=${sharedMgmt.address}`);
put(/BASE_OPERATIONAL_KEY_PUBLIC_ADDRESS=.*/,
    `BASE_OPERATIONAL_KEY_PUBLIC_ADDRESS=${extraWallets[2].address}`);
put(/BASE_OPERATIONAL_KEY_PRIVATE_ADDRESS=.*/,
    `BASE_OPERATIONAL_KEY_PRIVATE_ADDRESS=${extraWallets[2].privateKey}`);

// GNOSIS
put(/GNOSIS_MANAGEMENT_KEY_PUBLIC_ADDRESS=.*/,
    `GNOSIS_MANAGEMENT_KEY_PUBLIC_ADDRESS=${sharedMgmt.address}`);
put(/GNOSIS_OPERATIONAL_KEY_PUBLIC_ADDRESS=.*/,
    `GNOSIS_OPERATIONAL_KEY_PUBLIC_ADDRESS=${extraWallets[3].address}`);
put(/GNOSIS_OPERATIONAL_KEY_PRIVATE_ADDRESS=.*/,
    `GNOSIS_OPERATIONAL_KEY_PRIVATE_ADDRESS=${extraWallets[3].privateKey}`);

fs.writeFileSync(INPUT, envText);
console.log(`.env updated correctly with generated wallets and node name: ${NODE_NAME}`);

const dumpLines = [];

// Add publish wallets with env-style labels
publishWallets.forEach((w, i) => {
    const idx = String(i + 1).padStart(2, "0");
    dumpLines.push(
        `PUBLISH_WALLET_${idx}_PUBLIC_KEY\n  Address: ${w.address}\n  Private: ${w.privateKey}\n`
    );
});

// Add management wallet (shared)
dumpLines.push(
    `SHARED_MANAGEMENT_KEY\n  Address: ${sharedMgmt.address}\n  Private: ${sharedMgmt.privateKey}\n`
);

// Add operational wallets
dumpLines.push(
    `NEUROWEB_OPERATIONAL_KEY\n  Address: ${extraWallets[1].address}\n  Private: ${extraWallets[1].privateKey}\n`,
    `BASE_OPERATIONAL_KEY\n  Address: ${extraWallets[2].address}\n  Private: ${extraWallets[2].privateKey}\n`,
    `GNOSIS_OPERATIONAL_KEY\n  Address: ${extraWallets[3].address}\n  Private: ${extraWallets[3].privateKey}\n`
);

fs.writeFileSync(KEYS_OUT, dumpLines.join("\n"));
console.log(`Public addresses and private keys have been saved in ${KEYS_OUT}`);