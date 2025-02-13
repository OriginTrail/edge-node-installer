Edge Node v1.0.1 Installation

Welcome to the Private Beta of DKG Edge Node! 🚀

Thank you for being an early adopter of our Edge node. This private beta release allows you to test and provide valuable feedback. Your input will help shape the future of the Edge node. Please report any bugs 🐛 or suggestions!

## Table of Contents# Edge Node v1.0.1 Installation



Welcome to the Private Beta of DKG Edge Node! 🚀



Thank you for being an early adopter of our Edge node. This private beta release allows you to test and provide valuable feedback. Your input will help shape the future of the Edge node. Please report any bugs 🐛 or suggestions!



\## Table of Contents



\- [Prerequisites]\(#prerequisites)

\- [Installation Options]\(#installation-options)

&#x20; \- [Option 1: Manual Installation (Mac)]\(#option-1-manual-installation-mac)

&#x20; \- [Option 2: Automated Installation (Linux)]\(#option-2-automated-installation-linux)

\- [Configuration]\(#configuration)

\- [Useful Links]\(#useful-links)



\---



\## Prerequisites



Before installing, ensure your system meets the following requirements:



\### System Requirements (Mac & Linux)



\- \*\*OS\*\*: macOS or Linux

\- \*\*RAM\*\*: At least 8 GB

\- \*\*CPU\*\*: 4 Cores

\- \*\*Storage\*\*: At least 2 GB (Mac) / 60 GB (Linux)

\- \*\*Network\*\*: Stable internet connection



\### Software Dependencies



Ensure the following services are installed:



\- Git

\- MySQL 8

\- Redis

\- Node.js v22.4.0



\## Installation Options



\### Option 1: Manual Installation (Mac)



\#### Step 1: Prepare Your Environment



1\. Clone repositories:

&#x20;  \`\`\`sh

&#x20;  git clone [https://github.com/OriginTrail/edge-node-authentication-service.git](https://github.com/OriginTrail/edge-node-authentication-service.git)

&#x20;  git clone [https://github.com/OriginTrail/edge-node-api.git](https://github.com/OriginTrail/edge-node-api.git)

&#x20;  git clone [https://github.com/OriginTrail/edge-node-interface.git](https://github.com/OriginTrail/edge-node-interface.git)

&#x20;  git clone [https://github.com/OriginTrail/edge-node-knowledge-mining.git](https://github.com/OriginTrail/edge-node-knowledge-mining.git)

&#x20;  git clone [https://github.com/OriginTrail/edge-node-drag.git](https://github.com/OriginTrail/edge-node-drag.git)

&#x20;  \`\`\`

2\. Setup a Paranet (requires TRAC & ETH on Base Sepolia)

3\. Configure \`.origintrail\_noderc\` with your Paranet UAL



\#### Step 2: Install & Run Services



Each service has its own \`README.md\` with detailed installation steps. Basic setup:



\- \*\*Edge Node Authentication Service\*\* (Runs on \`http\://localhost:3001\`)

\- \*\*Edge Node API\*\* (Runs on \`http\://localhost:3002\`)

\- \*\*Edge Node Interface\*\* (Runs on \`http\://localhost:5173\`)

\- \*\*Edge Node Knowledge Mining\*\* (Runs on \`http\://localhost:5005\`)

\- \*\*Edge Node DRAG\*\* (Runs on \`http\://localhost:5002\`)



\### Option 2: Automated Installation (Linux)



\#### Step 1: Clone the Installer



\`\`\`sh

git clone [https://github.com/OriginTrail/edge-node-installer.git](https://github.com/OriginTrail/edge-node-installer.git)

cd edge-node-installer

chmod +x edge-node-installer.sh

\`\`\`



\#### Step 2: Run the Installer



\`\`\`sh

./edge-node-installer.sh

\`\`\`



The installer will:



\- Clone repositories

\- Set up runtime environments (Node.js, Python, MySQL, Redis, Apache Airflow)

\- Configure services



\#### Step 3: Update Configuration Files



Update \`.env\` files for each service to match your setup.



\---



\## Configuration



\- Modify \`.origintrail\_noderc\` with correct IP and Paranet UAL

\- Set environment variables for each service (\`.env\` files)

\- Optionally configure installer with custom repositories/branches



\## Useful Links



\- [DKG v8 Core Node Setup]\([https://docs.origintrail.io/dkg-v8-upcoming-version/run-a-v8-core-node-on-testnet](https://docs.origintrail.io/dkg-v8-upcoming-version/run-a-v8-core-node-on-testnet))

\- [Edge Node Authentication Service]\([https://github.com/OriginTrail/edge-node-authentication-service](https://github.com/OriginTrail/edge-node-authentication-service))

\- [Edge Node API]\([https://github.com/OriginTrail/edge-node-api](https://github.com/OriginTrail/edge-node-api))

\- [Edge Node Interface]\([https://github.com/OriginTrail/edge-node-interface](https://github.com/OriginTrail/edge-node-interface))

\- [Edge Node Knowledge Mining]\([https://github.com/OriginTrail/edge-node-knowledge-mining](https://github.com/OriginTrail/edge-node-knowledge-mining))

\- [Edge Node DRAG]\([https://github.com/OriginTrail/edge-node-drag](https://github.com/OriginTrail/edge-node-drag))



\## Feedback & Support



If you encounter any issues or have suggestions, please open an issue on GitHub or reach out to our support team.



Happy coding! 🎉





[Prerequisites](#prerequisites)

- [Installation Options](#installation-options)
  - [Option 1: Manual Installation (Mac)](#option-1-manual-installation-mac)
  - [Option 2: Automated Installation (Linux)](#option-2-automated-installation-linux)
- [Configuration](#configuration)
- [Useful Links](#useful-links)

---

## Prerequisites

Before installing, ensure your system meets the following requirements:

### System Requirements (Mac & Linux)

- **OS**: macOS or Linux
- **RAM**: At least 8 GB
- **CPU**: 4 Cores
- **Storage**: At least 2 GB (Mac) / 60 GB (Linux)
- **Network**: Stable internet connection

### Software Dependencies

Ensure the following services are installed:

- Git
- MySQL 8
- Redis
- Node.js v22.4.0

## Installation Options

### Option 1: Manual Installation (Mac)

#### Step 1: Prepare Your Environment

1. Clone repositories:
   ```sh
   git clone https://github.com/OriginTrail/edge-node-authentication-service.git
   git clone https://github.com/OriginTrail/edge-node-api.git
   git clone https://github.com/OriginTrail/edge-node-interface.git
   git clone https://github.com/OriginTrail/edge-node-knowledge-mining.git
   git clone https://github.com/OriginTrail/edge-node-drag.git
   ```
2. Setup a Paranet (requires TRAC & ETH on Base Sepolia)
3. Configure `.origintrail_noderc` with your Paranet UAL

#### Step 2: Install & Run Services

Each service has its own `README.md` with detailed installation steps. Basic setup:

- **Edge Node Authentication Service** (Runs on `http://localhost:3001`)
- **Edge Node API** (Runs on `http://localhost:3002`)
- **Edge Node Interface** (Runs on `http://localhost:5173`)
- **Edge Node Knowledge Mining** (Runs on `http://localhost:5005`)
- **Edge Node DRAG** (Runs on `http://localhost:5002`)

### Option 2: Automated Installation (Linux)

#### Step 1: Clone the Installer

```sh
git clone https://github.com/OriginTrail/edge-node-installer.git
cd edge-node-installer
chmod +x edge-node-installer.sh
```

#### Step 2: Run the Installer

```sh
./edge-node-installer.sh
```

The installer will:

- Clone repositories
- Set up runtime environments (Node.js, Python, MySQL, Redis, Apache Airflow)
- Configure services

#### Step 3: Update Configuration Files

Update `.env` files for each service to match your setup.

---

## Configuration

- Modify `.origintrail_noderc` with correct IP and Paranet UAL
- Set environment variables for each service (`.env` files)
- Optionally configure installer with custom repositories/branches

## Useful Links

- [DKG v8 Core Node Setup](https://docs.origintrail.io/dkg-v8-upcoming-version/run-a-v8-core-node-on-testnet)
- [Edge Node Authentication Service](https://github.com/OriginTrail/edge-node-authentication-service)
- [Edge Node API](https://github.com/OriginTrail/edge-node-api)
- [Edge Node Interface](https://github.com/OriginTrail/edge-node-interface)
- [Edge Node Knowledge Mining](https://github.com/OriginTrail/edge-node-knowledge-mining)
- [Edge Node DRAG](https://github.com/OriginTrail/edge-node-drag)

## Feedback & Support

If you encounter any issues or have suggestions, please open an issue on GitHub or reach out to our support team.

Happy coding! 🎉

