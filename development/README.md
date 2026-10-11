# Development Environment

General Requirements:
- Git (and GPG for verified commits)
- Linux, MacOS or Windows with WSL2
- BASH
- openssl (for secret generation)

run ```./swdev.sh help``` for a list of all functions.

Overview:
-  ./swdev.sh: Manages and sets up the development environment
- Containerfile: Builds the image where sportyweb is developed
- compose.yaml: organizes the container
- template.env and .env: .env is generated from the template and can be adjusted to your needs. Provides the environment vars for the container and the script.


## Quickstart for the container-based development environment:

Additional requirements:
- Podman or Docker


If you use Windows, install podman (or docker) in WSL2


Instuctions:

1. clone the repository to your preferred location
2. (if you want to use docker instead of podman, run ```./swdev.sh create-devenvfile``` and change the Values of CONTAINER_TOOL and COMPOSE_PROVIDER)
2. run ```./swdev.sh init```, this creates the containers, loads and compiles packages, sets up the DB and starts the webserver (exit with Ctrl+C, A)
4. Now the webserver should be accessible at <http://localhost:4000>

Now you can start developing or enter the container and run more commands:

- run ```-/swdev.sh enter``` to attach your shell to the container.
- then run some command, like ```mix ... ``` or use the alias 'swdev' with tab-completion inside the container!


Some functions from the script 'swdev.sh' are only available on a host with podman or docker, while others have to be used inside a container. To get an overview run ```./swdev.sh help```

### Quickstart for Dev Container:

Additional requirements:
- Podman or Docker
- A Tool that implements the Dev Container Specification like VSCode with the DevContainer extension https://code.visualstudio.com/docs/devcontainers/containers
    - Adjust the extension settings 'Docker Path' and 'Docker Compose Path' to podman( compose) if you use podman


Instructions:
1. clone the repository
2. open the workspace in a Dev Container (F1 -> Reopen in Container)
3. run ```./swdev.sh init``` - loads and compiles packages, sets up the DB, starts the webserver (exit with Ctrl+C, A)
4. Now the webserver should be accessible at <http://localhost:4000>
5. run some command, like ```mix .... ``` or use the alias 'swdev' with tab-completion inside the container!

## Step-by-Step Explanation

### Ubuntu, Debian

1. Install needed packages on your system:
```sudo apt install git podman podman-compose openssl```

2. now follow the Quickstart above!


### Windows

1. Install WSL2 (https://learn.microsoft.com/de-de/windows/wsl/install)
    - run in powershell ```wsl --install```
2. You will have to setup a local user during the installation.
3. We recommended to use VSCode because of the WSL integration (https://code.visualstudio.com/docs/remote/wsl), so install it:
    - ```winget install -e --id Microsoft.VisualStudioCode```
    - Install the WSL Extension (https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-wsl)
4. to start a bash shell, use ```wsl``` in powershell
5. in bash (WSL2): ```sudo apt install git podman podman-compose openssl```
6. clone the repository to a WSL2 directory like ```/home/user/...```, NOT ```/mnt/c/...``` for performance reasons
7. in bash (WSL2): ```code .``` to open the VSCode Frontend on Windows, while being connected to WSL.
8. Now you can run ```./swdev.sh init```, which should result in the running webserver, accessible at <http://localhost:4000>

### MacOS
# Proposal - needs evaluation!
1. Install git (https://git-scm.com/install/mac) and podman (https://podman-desktop.io/downloads)
    - homebrew:
        -  ```brew install git```
        -  ```brew install --cask podman-desktop```
    - manual:
        - ```xcode-select --install``` (Git)
        - Download the installer from the Website
2. Setup Podman including Podman Compose within the GUI
3. follow the Quickstart above!



## Further Details
### Functions of the script
Functions are the first arg when running the script: ```./swdev.sh FUNCTION```
Important functions are:

- ```init```: sets up both ```MIX_ENV=dev``` (```init-dev```) and ```MIX_ENV=test``` (```init-test```) and starts the websever, by default in the development container.
- ```clean```: cleans data like the database, the directories ```_build, deps, doc, uploads```. When run on the host, it also removes containers, volumes and the image.
- ```up``` starts the container
- ```down`` stops and removes the container
- ```enter``` Starts a shell in the development container, where you can run ```mix COMMANDS```
- ```enter-root``` Starts a root shell in the container
- ```con-cmd`` passes following args to the container and runs them in a bash shell. Example ```./swdev.sh con-cmd "mix.phx server"``` to start the webserver 
- ```test``` creates the test environment in the container and runs unit-tests
- ```credo``` runs the linting tool credo

For further details, please inspect the file.

### .env Files
With the Environment Variable ```SW_ENV_FILE``` a custom file will be used by the script (but not the compose.yaml!). It could be used inside a CI/CD-Action that runs test with a custom ```test.env```. 


### S3
In order to use the S3 Service, you have to uncomment the ```#USE_S3_STORAGE=true``` in ```.env``` AND adjust the configuration for the storage backend in ```config.exs``` (```storage_backend: ...```). These settings can (currently) not be provided in ```runtime.exs```. ```swdev.sh``` will start the S3 service when the env var is set, but the ```devcontainer.json``` ```"runServices":``` has to be adjusted manually.