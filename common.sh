#!/usr/bin/env bash

install_python() {
    # Install Python 3.11.7
    # Step 1: Install pyenv
    curl https://pyenv.run | bash

    # Step 2: Add pyenv to shell configuration files (.bashrc and .bash_profile)
    echo -e '\n# Pyenv setup\nexport PATH="$HOME/.pyenv/bin:$PATH"\neval "$(pyenv init --path)"\neval "$(pyenv init -)"\n' >> ~/.bashrc
    echo -e '\n# Pyenv setup\nexport PATH="$HOME/.pyenv/bin:$PATH"\neval "$(pyenv init --path)"\neval "$(pyenv init -)"\n' >> ~/.bash_profile

    # Step 3: Source shell configuration files
    source ~/.bashrc
    source ~/.bash_profile

    # Step 4: Ensure pyenv is loaded in the current shell
    export PATH="$HOME/.pyenv/bin:$PATH"
    eval "$(pyenv init --path)"
    eval "$(pyenv init -)"

    # Step 5: Install Python 3.11.7 and set it as global version
    pyenv install 3.11.7
    pyenv global 3.11.7

    # Step 6: Verify installation
    pyenv --version
    python --version
}


check_folder() {
    if [ -d "$1" ]; then
        echo "Note: It is recommended to delete all directories created by any previous installer executions before running the DKG Edge Node installer. This helps to avoid potential conflicts and issues during the installation process."
        read -p "Directory $1 already exists. Do you want to delete and clone again? (yes/no) [default: no]: " choice
        choice=${choice:-no}  # Default to 'no' if the user presses Enter without input

        if [ "$choice" == "yes" ]; then
            rm -rf "$1"
            echo "Directory $1 deleted."
        else
            echo "Skipping clone for $1."
            return 1
        fi
    fi
    return 0
}

check_ot_node_folder() {
    OTNODE_DIR="$EDGE_NODE_DIR/ot-node"
    if [ -d "$OTNODE_DIR" ]; then
        echo -e "\n⚠️  The DKG Node directory '$OTNODE_DIR' already exists."
        echo "Please choose one of the following options before continuing:"
        echo "1) Delete the existing directory and proceed with installation."
        echo "2) Create a backup of the existing directory and proceed with installation."
        echo "3) Abort the installation."
        
        while true; do
            read -p "Enter your choice (1/2/3) [default: 3]: " choice
            choice=${choice:-3}  # Default to '3' (Abort) if the user presses Enter without input

            case "$choice" in
                1)
                    echo "Deleting the existing directory '$OTNODE_DIR'..."
                    rm -rf "$OTNODE_DIR"
                    echo "Directory deleted. Proceeding with installation."
                    break
                    ;;
                2)
                    echo "Creating a backup of the existing directory..."
                    timestamp=$(date +"%Y%m%d%H%M%S")
                    backup_dir="/root/ot-node_backup_$timestamp"
                    mv "$OTNODE_DIR" "$backup_dir"
                    echo "Backup created at: $backup_dir"
                    echo "Proceeding with installation."
                    break
                    ;;
                3)
                    echo "Installation aborted."
                    exit 1
                    ;;
                *)
                    echo -e "\n❌ Invalid choice. Please enter 1, 2, or 3."
                    ;;
            esac
        done
    fi
}

