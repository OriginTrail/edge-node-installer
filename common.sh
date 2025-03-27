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

create_env_file() {
    cat <<EOL > $1/.env
NODE_ENV=development
DB_USERNAME=root
DB_PASSWORD=otnodedb
DB_DATABASE=$2
DB_HOST=127.0.0.1
DB_DIALECT=mysql
PORT=$3
UI_ENDPOINT=http://$SERVER_IP
UI_SSL=false
EOL
}


