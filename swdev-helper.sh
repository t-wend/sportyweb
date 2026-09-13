#
# This script creates an alias and adds shell completion
#

SCRIPT_FILE="./swdev.sh"
SCRIPT_ALIAS="swdev"

alias $SCRIPT_ALIAS=$SCRIPT_FILE


# searches for functions in the $SCRIPT_FILE, they need to look like this:
# func-name() {
# the sed command removes every non letter and '-'
FUNCTION_LIST=$(grep -o "^[a-zA-Z-]*() {" "$SCRIPT_FILE" | sed 's/[^a-zA-Z-]//g' )
#echo $FUNCTION_LIST
complete -W "$FUNCTION_LIST" $SCRIPT_ALIAS

echo "If this script was sourced, you can now use ’$SCRIPT_ALIAS’ in the sportyweb project directory!"
echo "Bash completion enabled!"
echo "These settings are not persistent! To make them persistent add them to your .bashrc (or .zshrc)!"
echo "Now run ’$SCRIPT_ALIAS init’ to setup the development container!"
