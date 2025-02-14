Edge Node v1.0.1 Installation

This installer provides an easy way to set up and run a DKG Edge Node on your system. 
By testing this installer and sharing your feedback, you help us refine the setup process and improve the overall experience. If you encounter any issues or have suggestions, please let us know! 🐛
For detailed instructions on setting up the DKG Edge Node in an automated environment on Ubuntu, check out the official documentation [here](https://docs.origintrail.io/build-with-dkg/dkg-edge-node/run-an-edge-node/automated-environment-setup-ubuntu).

For more details on the DKG Edge Node, visit the official documentation [here](https://docs.origintrail.io/build-with-dkg/dkg-edge-node).
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