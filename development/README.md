# Development Environment Setup Skript 'SWDEV'

General Requirements:
- BASH or ZSH
- openssl (for secret generation)

run ```./swdev.sh help``` for a list of all functions.

## Quickstart for the container-based development environment:

Requirements:
- Docker or Podman (Windows: in WSL2)


Instuctions:
1. run ```./swdev.sh init``` - This creates the containers, loads and compiles packages, sets up the DB and starts the webserver.
2. run ```-/swdev.sh enter``` - To attach your shell to the container.

## Quickstart for Dev Container:

Requirements:
- Docker or Podman
- A Tool that implements the Dev Container Specification like VSCode with the DevContainer extension https://code.visualstudio.com/docs/devcontainers/containers


Instuctions:
1.  run ```./swdev.sh``` - To automatically create the dev.env file from the template, including a randomly generated secret
2. open the workspace in a Dev Container (F1 -> Reopen in Container)
3. run ```./swdev.sh init``` - loads and compiles packages, sets up the DB, starts the webserver
