# Development Environment

General Requirements:
- Linux, MacOS or Windows with WSL2
- BASH or ZSH
- openssl (for secret generation)

run ```./swdev.sh help``` for a list of all functions.

Overview:
    - ./swdev.sh: Manages and sets up the development environment
    - Containerfile: Builds the image where sportyweb is developed
    - compose.yml: organizes the containers
    - template.env and .env: .env is generated from the template and can be adjusted to your needs. Provides the environment vars for the containers and the script.


## Quickstart for the container-based development environment:

Requirements:
- Default: Podman, can be changed to docker in .env
If you use Windows, install podman (or docker) in WSL2


Instuctions:

1. clone the repository to your preferred location
2. (if you want to use docker instead of podman, run ```./swdev.sh create-devenvfile``` and change the Values of CONTAINER_TOOL and COMPOSE_PROVIDER)
2. run ```./swdev.sh init``` - This creates the containers, loads and compiles packages, sets up the DB and starts the webserver (exit with Ctrl+C, A)
3. run ```-/swdev.sh enter``` - To attach your shell to the container.
4. run some command, like ```mix .... ``` or use the alias 'swdev' with tab-completion inside the container!


Some functions from the script 'swdev.sh' are only available on a host with podman or docker, while others have to be used inside a container or where all dependencies are installed on the host. To get an overview run ```./swdev.sh help```

### Quickstart for Dev Container:

Requirements:
- Podman or Docker
- A Tool that implements the Dev Container Specification like VSCode with the DevContainer extension https://code.visualstudio.com/docs/devcontainers/containers
    - Adjust the extension settings 'Docker Path' and 'Docker Compose Path' to podman( compose) if you use podman


Instructions:
1. clone the repository
2. open the workspace in a Dev Container (F1 -> Reopen in Container)
3. run ```./swdev.sh init``` - loads and compiles packages, sets up the DB, starts the webserver (exit with Ctrl+C, A)
4. run some command, like ```mix .... ``` or use the alias 'swdev' with tab-completion inside the container!

## Step-by-Step Explanation

### Ubuntu, Debian

1. Install needed packages on your system:
```sudo apt install git podman podman-compose openssl```

2. now follow the Quickstart above!

### MacOS

1. Install git (https://git-scm.com/install/mac) and podman (https://podman-desktop.io/downloads)
    - homebrew:
        -  ```brew install git```
        -  ```brew install --cask podman-desktop```
    - manual:
        - ```xcode-select --install``` (Git)
        - Download the installer from the Website
2. Setup Podman including Podman Compose within the GUI
3. follow the Quickstart above!


### Windows

1. Install WSL2 (https://learn.microsoft.com/de-de/windows/wsl/install)
    - run in powershell ```wsl --install```
2. You will have to setup a local user during the installation.
3. It is recommended to use VSCode because of its WSL integration (https://code.visualstudio.com/docs/remote/wsl), so install it:
    - ```winget install -e --id Microsoft.VisualStudioCode```
    - Install the WSL Extension (https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-wsl)
4. to start a bash shell, use ```wsl``` in powershell
5. in bash (WSL2): ```sudo apt install git podman podman-compose openssl```
6. clone the repository to a WSL2 directory like ```/home/user/...```, NOT ```/mnt/c/...``` for performance reasons
7. in bash: ```code .``` to open the VSCode Frontend on Windows, while being connected to WSL.
8. Now you can run ```./swdev.sh init``` and other commands and can start developing.


## Further Details
### Functions of the script
- ```init```: sets up both ```MIX_ENV=dev``` (```init-dev```) and ```MIX_ENV=test``` (```init-test```) and starts the websever, by default in the development container.
- ```clean```: cleans data like the database, the directories ```_build, deps, doc, uploads```, containers, volumes and the image.


### .env Files
With the Environment Variable ```SW_ENV_FILE``` a custom file will be used by the script (but not the compose.yml!). It could be used inside a CI/CD-Action that runs test with a custom ```test.env```. 


### S3
In order to use the S3 Service, you have to uncomment the ```#USE_S3_STORAGE=true``` in ```.env``` AND adjust the configuration for the storage backend in ```config.exs``` (```storage_backend: ...```). These settings can (currently) not be provided in ```runtime.exs```. ```swdev.sh``` will start the S3 service when the env var is set, but the ```devcontainer.json``` ```"runServices":``` has to be adjusted manually.