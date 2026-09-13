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
#			When 'USE_DEV_CONTAINER=true' is set in development/dev.env (default), 
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


###########################################################################
#
#		Check System Requirements
#
###########################################################################

#
#	Requirements for sportyweb
#
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

#
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

# Check if either podman or docker is installed
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

# Check if podman-compose or docker-compose is installed
check-con-compose() {
    if ! command -v podman-compose &> /dev/null
    then
        if ! command -v docker-compose &> /dev/null
        then 
            echo "ERROR podman-compose or docker-compose is required!"
            return 1  
        fi
    fi
}

check-con-enabled() {
    if [[ "$IN_CONTAINER" == "true" ]]
    then
        echo "ERROR Function is run inside the container, but has to run on the host! Aborting..."
        return 1
    fi
    if [[ $USE_DEV_CONTAINER != "true" ]]
    then
        echo "ERROR the container-based environment is disabled in the $ENV_FILE_DEV file!"
        return 1
    fi
}


# check if the requirements for sportyweb are met inside the container
check-con-sw-required() {
    check-con-dev-running
    echo "COMMAND_TO_CON: $COMMAND_TO_CON"
    $COMMAND_TO_CON ./$SCRIPT_FILE check-sw-required
}


#
#	Wrapper
#

# check if the requirements for sportyweb are met
check-sw-required() {
    if [[ "$USE_DEV_CONTAINER" = true ]]
    then
        if [[ ! "$IN_CONTAINER" = true ]]
        then
            # This is executed when:
            #   - Development containers should be used
            #   AND
            #   - the script is run on the host
            echo "WARNING USE_DEV_CONTAINER is set to true and this function (check-sw-required) should be run in the container, but is run on the host."
            return 0
        fi
    fi

    check-required-packages
    check-elixir
    check-recommended-packages
}


# check if the requirements for the container based environment are met.
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

check-con-dev-image() {
    check-con-required
    if ! $CONTAINER_TOOL image inspect $DEV_IMAGE_NAME > /dev/null
    then 
		echo "ERROR Image for development not found, build with 'con-build-dev'"
		return 1
	fi
}

check-con-dev-running() {
    check-con-dev-image
    #echo "INFO: Expected container name: $DEV_CONTAINER_NAME"

    if  ! $CONTAINER_TOOL ps --filter name=$DEV_CONTAINER_NAME --filter status=running --format={{.Names}} | grep $DEV_CONTAINER_NAME > /dev/null 2>&1
    then
		echo "ERROR Container for development is not running, start with '$SCRIPT_ALIAS up'"
		return 1
	fi
}

#
#   Build Images
#

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

up() {
    check-con-dev-image
    $CONTAINER_TOOL compose -f $COMPOSE_FILE_PATH up -d
}



down() {
    check-con-dev-image
    #check-con-dev-running
    $CONTAINER_TOOL compose -f $COMPOSE_FILE_PATH down
}


restart() {
    check-con-dev-image
    $CONTAINER_TOOL compose -f $COMPOSE_FILE_PATH restart
}	


enter() {
    check-con-dev-running
    $CONTAINER_TOOL exec -w /workspaces/sportyweb -it $DEV_CONTAINER_NAME /bin/bash 
    #$CONTAINER_TOOL compose -f ./development/compose.yml exec -w /workspaces/sportyweb sportyweb-dev bash 
}

enter-root() {
    check-con-dev-running
    $CONTAINER_TOOL exec -w /workspaces/sportyweb -it --user root $DEV_CONTAINER_NAME /bin/bash 
    #$CONTAINER_TOOL compose -f ./development/compose.yml exec -w /workspaces/sportyweb sportyweb-dev bash 
}

# Sends a command to the development container
con-cmd() {

    $COMMAND_TO_CON bash -c "$*"
}



###########################################################################
#
#		Utilities and Tools
#
###########################################################################

# Creates the environment var file, that can be changed by the user
create-devenvfile() {
    if [[ ! -f $SCRIPTDIR/$ENV_FILE_DEV ]]
    then
    echo "cp $SCRIPTDIR/$ENV_FILE_TEMPLATE $SCRIPTDIR/$ENV_FILE_DEV"
    cp $SCRIPTDIR/$ENV_FILE_TEMPLATE $SCRIPTDIR/$ENV_FILE_DEV
    echo "INFO $SCRIPTDIR/$ENV_FILE_DEV created"

    # Generates a 64 characters long secret and stores it in the $ENV_FILE_DEV
    #sed -i "s~^$1=.*~SECRET_KEY_BASE=$(mix phx.gen.secret)~g" $SCRIPTDIR/$ENV_FILE_DEV
    NEW_SECRET=$(LC_ALL=C openssl rand --base64 64 | sed -n '1p' | cut -c -64)
    sed -i "s~^#SECRET_KEY_BASE=.*~SECRET_KEY_BASE=$NEW_SECRET~g" $SCRIPTDIR/$ENV_FILE_DEV
    echo "INFO Secret generated in $SCRIPTDIR/$ENV_FILE_DEV"

    else
        echo "INFO $SCRIPTDIR/$ENV_FILE_DEV exists already... Doing nothing..."
    fi
}




con-generate-erd() {
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
}



# asks for user confirmation if some commands are not run in the
#  project directory.
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


# help
# ToDo
help() {
    FUNCTION_LIST=$(grep -o "^[a-zA-Z-]*() {" "$SCRIPT_FILE" | sed 's/[^a-zA-Z-]//g' )
    echo $FUNCTION_LIST
}



###########################################################################
#
#		Cleanup commands
#			
###########################################################################

#TODO benennung?
clean-system-db() {
    check-sw-required
    echo "INFO Dropping test and dev databases"
    MIX_ENV=dev mix ecto.drop
    MIX_ENV=test mix ecto.drop
}

clean-con-dev() {
    check-con-required
    echo "INFO Removing containers, including named volumes"
    $CONTAINER_TOOL compose -f $COMPOSE_FILE_PATH down -v   # "-v" drops volumes (db, /workspaces) TODO DAS TESTEN
	
}

clean-image-dev() {
    check-con-required
    echo "INFO Removing image $DEV_IMAGE_NAME:$DEV_IMAGE_TAG"
    $CONTAINER_TOOL image rm $DEV_IMAGE_NAME:$DEV_IMAGE_TAG
}

#TODO full path? IGNORE
clean-mixbuildcache() {
    echo "INFO Trying to remove:
                        $SCRIPTDIR/_build
                        $SCRIPTDIR/deps
    "
    check-scriptdir
    rm -rf $SCRIPTDIR/_build
    rm -rf $SCRIPTDIR/deps
    echo "INFO removed folders (if they existed)."
}

clean-devenvfile() {
    echo "INFO Trying to remove:
                        $SCRIPTDIR/$ENV_FILE_DEV
    "
    check-scriptdir
    rm $SCRIPTDIR/$ENV_FILE_DEV
    echo "INFO removed $SCRIPTDIR/$ENV_FILE_DEV."
}

#
#   Wrapper
#

clean-all() {
    if [[ "$IN_CONTAINER" == "true" ]]
    then
        #echo "INFO Cleaning inside the container, ecto.drop, deleting _build deps dev.env"
        clean-system-db
        clean-mixbuildcache
        clean-devenvfile
        return 0
    fi

    if [[ $USE_DEV_CONTAINER == "true" ]]
    then
        #echo "INFO Cleaning clean-con clean-devenvfile"
        clean-con-dev
        clean-image-dev
        clean-mixbuildcache
        clean-devenvfile
        
    else
        #echo "INFO Cleaning clean-mixbuildcache clean-devenvfile"
        clean-devenvfile
        clean-mixbuildcache
    fi
}



###########################################################################
#
#		Init, Reset, Test, Lint
#
###########################################################################


init() {
    echo "INFO: Initialising setup..."
    
    
    
    if [[ "$USE_DEV_CONTAINER" = true ]]
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
    echo "INFO Starting webserver..."
    mix phx.server
}




init-con() {
    echo "INFO: Setting up the development container..."  
    check-con-required
    #create-devenvfile
    con-build-dev
    up
    check-con-sw-required
    con-cmd "/workspaces/sportyweb/$SCRIPT_FILE init-dev"
    con-cmd "/workspaces/sportyweb/$SCRIPT_FILE init-test"
    con-cmd "/workspaces/sportyweb/$SCRIPT_FILE mix phx.server"
    return 0 # exit without proceeding
}




init-dev() {
    echo "INFO: Setting up the development environment..."
    check-sw-required

 
    mix deps.get

    mix assets.setup
    mix assets.build

    echo "INFO Drop dev database "
    mix ecto.drop

    echo "INFO Create dev database"
    mix ecto.create

    echo "INFO Run dev database migrations"
    mix ecto.migrate

    echo "INFO Generate a dump of the SQL structure"
    mix ecto.dump

    echo "INFO Run seed file"
    mix run priv/repo/seeds.exs

    echo "INFO Generate the ExDoc project documentation"
    mix docs

    echo "INFO Development environment is ready..."
    echo "INFO To create an ERD, run on host: ./$SCRIPT_FILE con-generate-erd " 
    
}




# 
init-test() {
    echo "INFO: Setting up the test environment..."
    check-sw-required
    #create-devenvfile
    

    echo "INFO Downloading dependencies"
    MIX_ENV=test mix deps.get

    echo "INFO Drop test database "
    MIX_ENV=test mix ecto.drop


    echo "INFO Create test databases"
    MIX_ENV=test mix ecto.create

    echo "INFO Run test database migrations"
    MIX_ENV=test mix ecto.migrate
}



test() {
    if [[ "$USE_DEV_CONTAINER" = true ]]
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
    echo "INFO: Running tests..."
    echo "INFO: You can append test commands like ./$SCRIPT_FILE test path/file ... "
    # This is executed when:
    #   - the script is run inside a container
    #   OR
    #   - the script is run on the host and development containers should not be used
    init-test
    MIX_ENV=test mix test $@
    #other tests
}



lint() {
    if [[ "$USE_DEV_CONTAINER" = true ]]
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


reset() {
    clean-all
    init
}


###########################################################################
#
#		Main script, settings and variables
#
###########################################################################
set -e              # default behaviour, exit if a function or command returns not 0
set -o pipefail     # 
#set -x             # Only for debugging


SCRIPT_ALIAS="swdev"                        # needs to be the same as in swdev-helper.sh
ENV_FILE_DEV=development/dev.env            # env-file for the development environment, in .gitignore (contains secret)
ENV_FILE_TEMPLATE=development/template.env  # used as template to create the file above
SCRIPT_FILE="swdev.sh"                      # overwritten by $SCRIPT_FILE in $ENV_FILE_DEV
CON_PROJECT_DIR="/workspaces/sportyweb"     # folder where the sportyweb repo is located inside the container

# find the location of the script
SCRIPTDIR=$( dirname -- "$( readlink -f -- "$0"; )";)


# load vars from env file if it exists, if not create it
if [ -f $ENV_FILE_DEV ]
then
    source $ENV_FILE_DEV
else
    create-devenvfile
    source $ENV_FILE_DEV
fi

# command that is used to run commands inside the container
COMMAND_TO_CON="$CONTAINER_TOOL exec -w $CON_PROJECT_DIR -it $DEV_CONTAINER_NAME"


# the first arg calls the function. Example ./swdev.sh init
"$@"
