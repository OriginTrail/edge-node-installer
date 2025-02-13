Edge Node v1.0.1 Installation

Welcome to the Private Beta of DKG Edge Node! 🚀

Thank you for being an early adopter of our Edge node. This private beta release allows you to test and provide valuable feedback. Your input will help shape the future of the Edge node. Please report any bugs 🐛 or suggestions!

## Table of Contents# Edge Node v1.0.1 Installation





---



## Prerequisites



Before installing, ensure your system meets the following requirements:



### System Requirements (Mac & Linux)



- **OS**: Linux(Ubuntu)

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



# Edge Node Installer

## 1. Clone the Repository
To begin, copy the following code:

 ```bash
git clone https://github.com/BogBogdan/edge-node-installer
```


## 2. Set the Environment Variables File
Once you have cloned the repository, navigate to the directory and set the environment variables:

1. Open the `.env.example` file:

 ```bash
nano .env.example
```

2. Fill in the required parameters. This includes adding the MySQL password that is necessary for the installation. Make sure that MySQL is installed and running.

3. After completing the environment file, rename it to `.env`:

 ```bash
mv .env.example .env
```


## 3. Execute the Installer
To execute the installation, run the following command:

 ```bash
bash edge-node-installer.sh
```


## 4. Usage
Once the installation is complete, you can access the user interface by navigating to:

```bash
    http://your-nodes-ip-address
```

The default login credentials are:

- **Username:** my_edge_node
- **Password:** edge_node_pass

**Important:** It is highly recommended to change the default credentials. To do this, directly modif