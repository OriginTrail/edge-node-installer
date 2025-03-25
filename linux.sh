#!/bin/sh


# Function to check the Ubuntu version
check_system_version() {
    # Get the Ubuntu version
    ubuntu_version=$(lsb_release -rs)

    # Supported versions
    supported_versions=("20.04" "22.04" "24.04")

    # Check if the current Ubuntu version is supported
    if [[ " ${supported_versions[@]} " =~ " ${ubuntu_version} " ]]; then
        echo "✔️ Supported Ubuntu version detected: $ubuntu_version"
    else
        echo -e "\n❌ Unsupported Ubuntu version detected: $ubuntu_version"
        echo "This installer only supports the following Ubuntu versions:"
        echo "20.04, 22.04, and 24.04."
        echo "Please install the script on a supported version of Ubuntu."
        exit 1
    fi
}


system_service() {
    systemctl $@
}


echo "alias edge-node-restart='systemctl restart auth-service && systemctl restart edge-node-api && systemctl restart ka-mining-api && systemctl restart airflow-scheduler && systemctl restart drag-api'" >> ~/.bashrc
