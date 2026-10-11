#!/bin/bash
###########################################################################
#
#	_________________________________________________
#
#		Sportyweb development environment script
#	_________________________________________________
#
#   Requirements for this script: 
#                       - linux or macos
#                       - bash or zsh
#                       - openssl (for secret generation)
#
#
#	How to use this file:
# 		1. make sure your working directory is the cloned repository,
#		     then run a command like './swdev.sh help'
#		2. jump straight into sportyweb development:
#				'./swdev.sh init'
#			When 'USE_CONTAINER=true' is set in development/dev.env (default), 
#			this checks requirements, creates an image, runs it,
#			fetches elixir dependencies, compiles them, creates and 
#			seeds the db and finally starts the webserver.
#			Have fun!
#
#           You can also 'source swdev-helper.sh', which will set
#            an alias 'swdev' and add bash-completion for functions.
#            This is the default in the development container.
#
#       
#       Structure of this script:
#                          - Functions:
#                                   - Check System Requirements
#                                   - Container Management
#                                   - Create ENV-File, ERD
#                                   - Cleanup
#                                   - Wrapper functions, init, test, ...
#                          - Main script: settings, vars, ....
#
#                                                   
#       Meaning of the comments above the functions:
#                       - any: use on host or in container  
#                       - CH: use on host with USE_CONTAINER=true 
#                       - SW: use where sportyweb runs
###########################################################################
#
#		Check System Requirements
#
###########################################################################

#
#	Requirements for sportyweb
#

# SW - Checks if required commands for Sportyweb are available
check-required-packages() {
    read -r -a req_packages <<< $REQUIRED_PACKAGES
    for p in "${req_packages[@]}"
    do
        if ! command -v $p &> /dev/null
        then 
            echo "ERROR required command/package $p not found"
            return 1
        fi
    done

}

# SW - Checks if elixir is available in the correct version
check-elixir() {

	if ! command -v iex &> /dev/null
    then 
		echo "ERROR elixir/erlang not found or installed!"
        echo "      Please install elixir $ELIXIR_VERSION"
		return 1
	fi
	
    if [ "$(iex --version | sed -n 3p | cut -c -10)" = "IEx $ELIXIR_VERSION" ]
    then : 
	else
		echo "WARNING wrong elixir version found!"
        echo "      Please install elixir $ELIXIR_VERSION"
	fi
}

# SW - Checks if commands from recommended packages are available
check-recommended-packages() {
    read -r -a rec_packages <<< $RECOMMENDED_PACKAGES

    for p in "${rec_packages[@]}"
    do
        if ! command -v $p &> /dev/null
        then 
            echo "WARNING recommended command/package $p not found"
        fi
    done

}

#
#	Container based environment
#

# CH - Check if either podman or docker is installed
check-con-engine() {
    if ! command -v podman &> /dev/null
    then
        if ! command -v docker &> /dev/null
        then 
            echo "ERROR podman or docker is required!"
            return 1  
        fi
    fi
}

# CH - Check if podman-compose or docker-compose is installed
check-con-compose() {
    if ! command -v podman-compose &> /dev/null
    then
        if ! command -v docker compose &> /dev/null
        then 
            echo "ERROR podman-compose or docker compose is required!"
            return 1  
        fi
    fi
}

# any - Check if containers should be used
check-con-enabled() {
    if [[ "$IN_CONTAINER" == "true" ]]
    then
        echo "ERROR Function is run inside the container, but has to run on the host! Aborting..."
        return 1
    fi
    if [[ $USE_CONTAINER != "true" ]]
    then
        echo "ERROR the container-based environment is disabled in the $CURRENT_ENV_FILE file!"
        return 1
    fi
}


#
#	Wrapper
#

# SW - Check if the requirements for sportyweb are met
check-sw-required() {
    if [[ "$USE_CONTAINER" = true ]]
    then
        if [[ ! "$IN_CONTAINER" = true ]]
        then
            # This is executed when:
            #   - Development containers should be used
            #   AND
            #   - the script is run on the host
            echo "WARNING USE_CONTAINER is set to true and this function should be run in the container, but is run on the host."
            return 1
        fi
    fi

    check-required-packages
    check-elixir
    check-recommended-packages
}


# CH - check if the requirements for containers are met.
check-con-required() {
    check-con-enabled
    check-con-engine
    check-con-compose
}



###########################################################################
#
#		Container Managment
#
###########################################################################

#
#   Checks
#

# CH - check if the image exists
check-con-dev-image() {
    check-con-required
    if ! $CONTAINER_TOOL image inspect $DEV_IMAGE_NAME > /dev/null
    then 
		echo "ERROR Image for development not found, build with 'con-build-dev'"
		return 1
	fi
}

# CH - check if the container is running
check-con-dev-running() {
    check-con-dev-image
    #echo "INFO: Expected container name: $DEV_CONTAINER_NAME"

    if  ! $CONTAINER_TOOL ps --filter name=$DEV_CONTAINER_NAME --filter status=running --format={{.Names}} | grep $DEV_CONTAINER_NAME > /dev/null 2>&1
    then
		echo "ERROR Container for development is not running, start with './sw-dev up'"
		return 1
	fi
}

#
#   Build Images
#

# CH - Build the container
con-build-dev() {
    check-con-required
    echo "INFO Building the development container...."
 
    $CONTAINER_TOOL build --target $DEV_IMAGE_TARGET --tag $DEV_IMAGE_NAME:$DEV_IMAGE_TAG -f $CONTAINERFILE_PATH .
    
    echo "INFO The first start can take some time due to userns UID/GID mapping."
    echo "INFO Please be patient...."
    #echo "INFO If you're interested: https://github.com/podman-container-tools/podman/pull/28393 "

}

#
#   Usage/Management
#

# CH - Start the containers
up() {
    check-con-dev-image
    $COMPOSE_PROVIDER -f $COMPOSE_FILE_PATH up -d $COMPOSE_SERVICES
}


# CH - Stop all containers and remove them
down() {
    check-con-dev-image
    $COMPOSE_PROVIDER -f $COMPOSE_FILE_PATH down
}

# CH - Restart all containers
restart() {
    check-con-dev-image
    $COMPOSE_PROVIDER -f $COMPOSE_FILE_PATH restart $COMPOSE_SERVICES
}	

# CH - Start a shell inside the container
enter() {
    check-con-dev-running
    $CONTAINER_TOOL exec -w /workspaces/sportyweb -it $DEV_CONTAINER_NAME /bin/bash 
    }

# CH - Start a root shell inside the container
enter-root() {
    check-con-dev-running
    $CONTAINER_TOOL exec -w /workspaces/sportyweb -it --user root $DEV_CONTAINER_NAME /bin/bash 
    
}

# CH - Sends a command passed as arg ($*) to the development container
con-cmd() {
    check-con-dev-running
    $COMMAND_TO_CON bash -c "$*"
}



###########################################################################
#
#		Utilities and Tools
#
###########################################################################

# any - Creates the .env file with randomly generated secrets, that can be changed by the user
create-devenvfile() {
    if [[ ! -f $SCRIPTDIR/$CURRENT_ENV_FILE ]]
    then
        echo "cp $SCRIPTDIR/$ENV_FILE_TEMPLATE $SCRIPTDIR/$CURRENT_ENV_FILE"
        cp $SCRIPTDIR/$ENV_FILE_TEMPLATE $SCRIPTDIR/$CURRENT_ENV_FILE
        echo "INFO $SCRIPTDIR/$CURRENT_ENV_FILE created"

        # Generates a 64 characters long secret
        NEW_SECRET=$(LC_ALL=C openssl rand --base64 64 | sed -n '1p' | cut -c -64)
        # Replaces the value of SECRET_KEY_BASE
        sed -i "s~^#SECRET_KEY_BASE=.*~SECRET_KEY_BASE=$NEW_SECRET~g" $SCRIPTDIR/$CURRENT_ENV_FILE
        
        NEW_SECRET=$(LC_ALL=C openssl rand --base64 64 | sed -n '1p' | cut -c -64)
        # Replaces the value of S3_SECRET_KEY
        sed -i "s~^#S3_SECRET_KEY=.*~S3_SECRET_KEY=$NEW_SECRET~g" $SCRIPTDIR/$CURRENT_ENV_FILE
        
        NEW_SECRET=$(LC_ALL=C openssl rand --base64 64 | sed -n '1p' | cut -c -64)
        # Replaces the value of POSTGRES_PASSWORD
        sed -i "s~^#POSTGRES_PASSWORD=.*~POSTGRES_PASSWORD=$NEW_SECRET~g" $SCRIPTDIR/$CURRENT_ENV_FILE
        

        echo "INFO Secrets generated in $SCRIPTDIR/$CURRENT_ENV_FILE"

    else
        echo "INFO $SCRIPTDIR/$CURRENT_ENV_FILE exists already... Doing nothing..."
    fi
}



# any - generates an ERD
generate-erd() {
    # https://hexdocs.pm/ecto_erd/Mix.Tasks.Ecto.Gen.Erd.html#module-mermaid
    if [[ "$USE_CONTAINER" = true ]]
    then
        if [[ ! "$IN_CONTAINER" = true ]]
        then
            # This is executed when:
            #   - Development containers should be used
            #   AND
            #   - the script is run on the host
            check-con-dev-running
            $COMMAND_TO_CON mix ecto.gen.erd --output-path=documents/ecto_erd.mmd
            
            # Uses mermaid-cli to generate an erd from the previously generated .mmd
            # https://github.com/mermaid-js/mermaid-cli
            if [[ "$CONTAINER_TOOL" == "podman" ]]
            then
                podman run --userns keep-id --user ${UID} --rm -v $SCRIPTDIR/documents:/data:z ghcr.io/mermaid-js/mermaid-cli/mermaid-cli -i ecto_erd.mmd -o erd.pdf
            elif [[ "$CONTAINER_TOOL" == "docker" ]]
            then
                docker run --rm -u `id -u`:`id -g` -v $SCRIPTDIR/documents:/data minlag/mermaid-cli -i ecto_erd.mmd -o erd.pdf
            else
                echo "ERROR $CONTAINER_TOOL must be 'podman' or 'docker'"
                rm $SCRIPTDIR/documents/ecto_erd.mmd
                return 1
            fi
            rm $SCRIPTDIR/documents/ecto_erd.mmd
            echo "INFO: You can now view documents/erd.pdf"
            return 0
        fi
    fi
    if command -v mmdc &> /dev/null
    then
        mix ecto.gen.erd --output-path=ecto_erd.mmd && mmdc -i ecto_erd.mmd -o documents/erd.pdf
        rm ecto_erd.mmd
        echo "INFO: You can now view documents/erd.pdf"
        return 0
    else
        echo "WARNING: Can't generate an ERD!"
        echo "         Please run this on the host or"
        echo "         install mermaid-cli (https://github.com/mermaid-js/mermaid-cli)"
        return 1
    fi

}



# any - asks for user confirmation if some commands are not run in the project directory.
check-scriptdir() {
    if [[ ! $SCRIPTDIR == *"sportyweb"* ]]
    then
        echo "WARNING Script is not in *sportyweb* Path!"
        echo "SCRIPTDIR: $SCRIPTDIR"
        read -p "Do you want to continue?" -n 1 -r $REPLY
        if [[ ! $REPLY =~ ^[Yy]$ ]]
        then
            echo "Aborted..."
            return 1
        fi
    fi
}


# any - Shows available functions
help() {
    echo "Meaning of the comments above the functions:
            - any: use on host or in container  
            - CH: use on host with USE_CONTAINER=true 
            - SW: use where sportyweb runs"


    grep -B 1 "^[a-zA-Z-]*() {" "$SCRIPT_FILE" | sed 's-() {--g'

    echo "Meaning of the comments above the functions:
            - any: use on host or in container  
            - CH: use on host with USE_CONTAINER=true 
            - SW: use where sportyweb runs"
}



###########################################################################
#
#		Cleanup commands
#			
###########################################################################

# SW - Drop databases with Ecto
clean-db() {
    check-sw-required
    echo "INFO Dropping test and dev databases"
    MIX_ENV=dev mix ecto.drop
    MIX_ENV=test mix ecto.drop
}

# CH - Stop all containers, remoe them including named Volumes!
clean-con-dev() {
    check-con-required
    echo "INFO Removing containers, including named volumes"
    $COMPOSE_PROVIDER -f $COMPOSE_FILE_PATH down -v # "-v" drops volumes (db, /workspaces) TODO DAS TESTEN
	
}

# CH - Remove the image
clean-image-dev() {
    check-con-required
    echo "INFO Removing image $DEV_IMAGE_NAME:$DEV_IMAGE_TAG"
    $CONTAINER_TOOL image rm $DEV_IMAGE_NAME:$DEV_IMAGE_TAG
}

# any - Remove _build, deps, uploads and doc dirs
clean-data() {
    echo "INFO Trying to remove:
                        $SCRIPTDIR/_build
                        $SCRIPTDIR/deps
                        $SCRIPTDIR/uploads
                        $SCRIPTDIR/doc
    "
    check-scriptdir
    rm -rf $SCRIPTDIR/_build
    rm -rf $SCRIPTDIR/deps
    rm -rf $SCRIPTDIR/uploads
    rm -rf $SCRIPTDIR/doc
    echo "INFO removed folders (if they existed)."
}

# any - Delete .env
clean-devenvfile() {
    echo "INFO Trying to remove:
                        $SCRIPTDIR/$CURRENT_ENV_FILE
    "
    check-scriptdir
    rm $SCRIPTDIR/$CURRENT_ENV_FILE
    echo "INFO removed $SCRIPTDIR/$CURRENT_ENV_FILE."
}

#
#   Wrapper
#

# any - Remove created data
clean() {
    if [[ "$USE_CONTAINER" = true ]]
    then
        if [[ ! "$IN_CONTAINER" = true ]]
        then
            # This is executed when:
            #   - Development containers should be used
            #   AND
            #   - the script is run on the host
            clean-con-dev
            clean-image-dev
            clean-data
            return 0
        fi
    fi
    clean-db
    clean-data
}



###########################################################################
#
#		Init, Reset, Test, Lint
#
###########################################################################

# any - Setup the development environment
init() {
    echo "INFO: Initialising setup..."
    if [[ "$USE_CONTAINER" = true ]]
    then
        if [[ ! "$IN_CONTAINER" = true ]]
        then
            # This is executed when:
            #   - Development containers should be used
            #   AND
            #   - the script is run on the host
            init-con
            return 0
        fi
    fi
    # This is executed when:
    #   - the script is run inside a container
    #   OR
    #   - the script is run on the host and development containers should not be used
    init-test
    init-dev
    echo "INFO: Starting webserver..."# SW - Setup the mix environment in MIX_ENV=dev
    mix phx.server
}



# CH - Setup the container based development environment
init-con() {
    echo "INFO: Setting up the development container..."  
    check-con-required
    con-build-dev
    up
    con-cmd "/workspaces/sportyweb/$SCRIPT_FILE check-sw-required"
    con-cmd "/workspaces/sportyweb/$SCRIPT_FILE init-dev"
    con-cmd "/workspaces/sportyweb/$SCRIPT_FILE init-test"
    con-cmd "mix phx.server"
    return 0 # exit without proceeding
}


# SW - Setup the mix environment, $1 should be "dev" or "test"
init-mixenv() {
    echo "INFO: Setting up the MIX_ENV=$1 environment..."
    check-sw-required

    MIX_ENV=$1 mix deps.get

    MIX_ENV=$1 mix assets.setup
    MIX_ENV=$1 mix assets.build

    echo "INFO Drop $1 database "
    MIX_ENV=$1 mix ecto.drop

    echo "INFO Create $1 database"
    MIX_ENV=$1 mix ecto.create

    echo "INFO Run $1 database migrations"
    MIX_ENV=$1 mix ecto.migrate
   
}


# SW - Setup the mix environment MIX_ENV=dev
init-dev() {
    echo "INFO: Setting up the development environment..."
    check-sw-required

    # create S3 Bucket if it doesnt exists
    if [[ $USE_S3_STORAGE == "true" ]]
    then
        aws s3api create-bucket --bucket $S3_BUCKET --endpoint-url http://s3:9000
    fi
 
    init-mixenv "dev"

    echo "INFO Generate a dump of the SQL structure"
    mix ecto.dump

    echo "INFO Run seed file"
    mix run priv/repo/seeds.exs

    echo "INFO Generate the ExDoc project documentation"
    mix docs

    echo "INFO Development environment is ready..."
    echo "INFO To create an ERD, run on host: ./$SCRIPT_FILE con-generate-erd " 
    
}

# SW - Setup the mix environment MIX_ENV=test
init-test() {
    echo "INFO: Setting up the test environment..."
    check-sw-required
    init-mixenv "test"
}


# any - Run tests
test() {
    if [[ "$USE_CONTAINER" = true ]]
    then
        if [[ ! "$IN_CONTAINER" = true ]]
        then
            # This is executed when:
            #   - Development containers should be used
            #   AND
            #   - the script is run on the host
            con-cmd "/workspaces/sportyweb/$SCRIPT_FILE test $@"
            return 0
        fi
    fi
    echo "INFO: Initialize and run tests..."
    echo "INFO: You can append test commands like ./$SCRIPT_FILE test path/file ... "
    # This is executed when:
    #   - the script is run inside a container
    #   OR
    #   - the script is run on the host and development containers should not be used
    init-test
    MIX_ENV=test mix test $@
    #other tests
}


# any - Analyze the code
lint() {
    if [[ "$USE_CONTAINER" = true ]]
    then
        if [[ ! "$IN_CONTAINER" = true ]]
        then
            # This is executed when:
            #   - Development containers should be used
            #   AND
            #   - the script is run on the host
            con-cmd "/workspaces/sportyweb/$SCRIPT_FILE lint $@"
            return 0
        fi
    fi
    echo "INFO: Linting..."
    echo "INFO: You can append credo commands like ./$SCRIPT_FILE lint explain ... "
    # This is executed when:
    #   - the script is run inside a container
    #   OR
    #   - the script is run on the host and development containers should not be used
    mix credo $@
}

# any - Removes created data and initializes the environment again
reset() {
    clean
    init
}


###########################################################################
#
#		Main script, settings and variables
#
###########################################################################
set -e              # default behaviour, exit if a function or command doesn't return 0
set -o pipefail     # 
#set -x             # Only for debugging


CURRENT_ENV_FILE=${SW_ENV_FILE:-development/.env}  # env file for the environment, in .gitignore (contains secret)
ENV_FILE_TEMPLATE=development/template.env  # used as template to create the file above
ELIXIR_VERSION=1.18.4                       # Used to check if the expected version matches the installed
# commands from required packages for sportyweb 
# from package:  --------- inotify-tools poppler-utils imagemagick ---------
REQUIRED_PACKAGES="git gcc inotifywatch   pdfinfo       convert     ocrmypdf"
# commands from recommended packages to be checked
# from package:     awscli postgresql-client
RECOMMENDED_PACKAGES="aws pg_dump"
# needs to be the same as in swdev-helper.sh
SCRIPT_ALIAS="swdev"                        
SCRIPT_FILE="swdev.sh"

COMPOSE_SERVICES="sportyweb-dev postgresql"

# find the location of the script
SCRIPTDIR=$( dirname -- "$( readlink -f -- "$0"; )";)

# load vars from env file if it exists, if not create it
if [ -f $CURRENT_ENV_FILE ]
then
    source $CURRENT_ENV_FILE
else
    create-devenvfile
    source $CURRENT_ENV_FILE
fi

if [[ $USE_S3_STORAGE == "true" ]]
then
    COMPOSE_SERVICES="$COMPOSE_SERVICES s3"
fi

# command that is used to run commands inside the container
COMMAND_TO_CON="$CONTAINER_TOOL exec -w $CONTAINER_PROJECT_DIR -it $DEV_CONTAINER_NAME"

# A list of all functions in this script
FUNCTION_LIST=$(grep "^[a-zA-Z-]*() {" "$SCRIPT_FILE" | sed 's/[^a-zA-Z-]//g' | tr '\n' ' ' )

#                                                     ARG $1
# the first arg calls the function. Example ./swdev.sh init
# Checks if the "Command" is in the function list, else shows an error
read -r -a functions <<< $FUNCTION_LIST
for function in "${functions[@]}"
do
    if [[ "$1" == $function ]]
    then
         
        "$@"
        exit 0
    fi
done
echo "ERROR: $@ is no function or no function specified!"
echo "       use './$SCRIPT_FILE help' to view all functions!"
echo "       or read the beginning of './$SCRIPT_FILE' for information."
exit 1