#!bin/bash
BASHRC_FILE="$HOME/.bashrc"
# echo $0
show_help() {
    echo "Usage: $(basename "$0") <script_path> <alias_name>"
    echo ""
    echo "This script creates an alias in your '$BASHRC_FILE' for the specified script file."
    echo "The script file will be referenced by its absolute path in the alias."
    echo ""
    echo "Arguments:"
    echo "  <script_path>    The full or relative path to the .sh script you want to alias."
    echo "                   The script must exist."
    echo "  <alias_name>     The name for the new alias (e.g., 'mygittask', 'run_report')."
    echo "                   Avoid spaces or special characters other than letters, numbers, and underscores."
    echo ""
    echo "Example:"
    echo "  $(basename "$0") /path/to/your/somecode.sh mycode"
    echo "  $(basename "$0") ./scripts/anothercode.sh another"
    echo ""
    echo "Options:"
    echo "  -h, --help       Show this help message and exit."
    echo ""
    echo "After running, you will need to source your '$BASHRC_FILE' or open a new terminal"
    echo "for the alias to become active, e.g., by running: source $BASHRC_FILE"
}

# --- Argument Parsing ---

# Check for help option first
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  show_help
  exit 0
fi

# Check for the correct number of input arguments
if [ "$#" -ne 2 ]; then
  echo "Error: Incorrect number of arguments. Expected 2, got $#." >&2
  echo "" >&2
  show_help
  exit 1
fi

TARGET_SCRIPT_FILE_PATH_ARG="$1"
ALIAS_NAME_ARG="$2"

echo "setting alias name '$ALIAS_NAME_ARG' in ~/.bashrc for command: '$TARGET_SCRIPT_FILE_PATH_ARG'..."

# Validate alias name (simple check for problematic characters)
if ! [[ "$ALIAS_NAME_ARG" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
  echo "Error: Alias name '$ALIAS_NAME_ARG' contains invalid characters." >&2
  echo "       Please use only alphanumeric characters, underscores, hyphens, or periods." >&2
  exit 1
fi

# --- Resolve script path to absolute and validate ---
ABSOLUTE_SCRIPT_PATH=""

# use realpath 
if command -v realpath &> /dev/null; then
  ABSOLUTE_SCRIPT_PATH=$(realpath "$TARGET_SCRIPT_FILE_PATH_ARG" 2>/dev/null) # Suppress realpath error, check below
# readlink -f as an alternative
elif command -v readlink &> /dev/null && readlink -f / &>/dev/null; then
  ABSOLUTE_SCRIPT_PATH=$(readlink -f "$TARGET_SCRIPT_FILE_PATH_ARG" 2>/dev/null) # Suppress readlink error

  if [[ "$TARGET_SCRIPT_FILE_PATH_ARG" != /* ]]; then # Check if path is not absolute
    echo "Error: <script_path> '$TARGET_SCRIPT_FILE_PATH_ARG' is relative and path resolution tools are unavailable." >&2
    echo "       Please provide an absolute path for the script file or install 'realpath'." >&2
    exit 1
  fi
  ABSOLUTE_SCRIPT_PATH="$TARGET_SCRIPT_FILE_PATH_ARG" # Use as is if absolute
fi


# Now, validate the resolved or given absolute path
if [ -z "$ABSOLUTE_SCRIPT_PATH" ] || [ ! -f "$ABSOLUTE_SCRIPT_PATH" ]; then
  echo "Error: Script file '$TARGET_SCRIPT_FILE_PATH_ARG' (resolved to '$ABSOLUTE_SCRIPT_PATH') not found or is not a regular file." >&2
  exit 1
fi

echo "[INFO] Script to alias will be: $ABSOLUTE_SCRIPT_PATH"

# --- Check if the script is executable and offer to make it ---
if [ ! -x "$ABSOLUTE_SCRIPT_PATH" ]; then
  echo "[INFO] The script '$ABSOLUTE_SCRIPT_PATH' is not currently executable."
  read -r -p "Do you want to make it executable (chmod +x)? (y/N): " choice
  if [[ "$choice" == "Y" || "$choice" == "y" ]]; then
    chmod +x "$ABSOLUTE_SCRIPT_PATH"
    if [ $? -ne 0 ]; then
      echo "Error: Failed to make script '$ABSOLUTE_SCRIPT_PATH' executable. Please check permissions." >&2
      # Decide if to exit or proceed with a non-executable script warning
      echo "       Proceeding, but the alias might not work correctly." >&2
    else
      echo "[SUCCESS] Script '$ABSOLUTE_SCRIPT_PATH' is now executable."
    fi
  else
    echo "[WARNING] Proceeding without making the script executable. The alias might not work as expected."
  fi
fi

# --- Prepare alias definition and comments ---
ALIAS_DEFINITION="alias $ALIAS_NAME_ARG='$ABSOLUTE_SCRIPT_PATH'"
ALIAS_COMMENT_LINE1="# Alias for $ALIAS_NAME_ARG (points to script originally specified as '$TARGET_SCRIPT_FILE_PATH_ARG')"
ALIAS_COMMENT_LINE2="# Added by $(basename "$0") on $(date +'%Y-%m-%d %H:%M:%S')"

echo $ALIAS_DEFINITION
echo $ALIAS_COMMENT_LINE1
echo $ALIAS_COMMENT_LINE2

# Create a backup of .bashrc before modifying for the first time
BASHRC_BACKUP=${BASHRC_FILE}.bak_$(date +'%y%m%d_%H%M')
cp "$BASHRC_FILE" "$BASHRC_BACKUP"
echo "[INFO] Backup of '$BASHRC_FILE' created at '$BASHRC_BACKUP'. "

echo "[ACTION] Adding new alias to '$BASHRC_FILE'..."
echo "" >> "$BASHRC_FILE" # Add a blank line for separation
echo "$ALIAS_COMMENT_LINE1" >> "$BASHRC_FILE"
echo "$ALIAS_COMMENT_LINE2" >> "$BASHRC_FILE"
echo "$ALIAS_DEFINITION" >> "$BASHRC_FILE"
echo "[SUCCESS] Alias '$ALIAS_NAME_ARG' for '$ABSOLUTE_SCRIPT_PATH' has been added. Run source ~/.bashrc, then type '$ALIAS_NAME_ARG' to use the command."

