Edge Node v1.0.1 Installation

Welcome to the release of the DKG Edge Node Installer! 🚀

Thank you for being an early adopter of our Edge Node Installer. This private beta release provides you with the first official installer to easily set up the Edge Node on your system. By testing this installer and providing feedback, you play a crucial role in improving the setup process. Your insights will help us refine the experience. Please report any bugs 🐛 or suggestions!


## Prerequisites



Before installing, ensure your system meets the following requirements:



### System Requirements (Linux)



- **OS**: Linux(Ubuntu)

- **RAM**: At least 8 GB

- **CPU**: 4 Cores

- **Storage**: At least 60 GB (Linux)

- **Network**: Stable internet connection



### Software Dependencies

Ensure the following services are installed:

- Git


# Edge Node Installer

## 1. Clone the Repository
To begin, copy the following code:

 ```bash
git clone https://github.com/OriginTrail/edge-node-installer
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

**Important:** It is highly recommended to change the default credentials. 