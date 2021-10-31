#!/usr/bin/env bash

###############################################################################
#                                                                             #
#                      CONVERT_CALLLOG_SQLITE_TO_XML.SH                       #
#                                                                             #
###############################################################################

#-----------------------------------------------------------------------------#
#     Author(s): Stéphane PAKULA
#     Version: 1.0
#     Date: 12/10/2020
#     Last Modif. Date: 12/10/2020
#     Description:    Export calllog.db (sqlite) from android phone to XML 
#                  file with compatibility with SuperBackup and 
#                  BackupAndRestore App.
#
#-----------------------------------------------------------------------------#


###############################################################################
#     CONST
###############################################################################
    
# A better class of script...
#----------------------------
    set -o errexit          # Exit on most errors (see the manual)
    set -o errtrace         # Make sure any error trap is inherited
    set -o nounset          # Disallow expansion of unset variables
    set -o pipefail         # Use last non-zero exit code in a pipeline
    #set -o xtrace          # Trace the execution of the script (debug)

# A better class of script...
#----------------------------
    VERSION="1.0"

###############################################################################
#     VARIABLES
###############################################################################

# Common
#----------------------------
    MODE=1 # 1: SuperBackup(default), 2: BackupANdRestore
    MODE_CHOICE="null"
    SCRIPT_NAME="CONVERT_CALLLOG_SQLITE_TO_XML.sh"
    JOUR=`date +%Y_%m_%d`   

# File
#----------------------------
    FILE_SQLITE=""
    FILE_XML_OUTPUT=""
    PATH_FILE_SQLITE=""
    
# File
#----------------------------
    PATH_FILE_DIR=""
    PATH_FILE_CSV=""
    

###############################################################################
#     FUNCTIONS
###############################################################################


# script_usage()
#----------------------------
# DESC: Usage help
# ARGS: None
# OUTS: None
function script_usage() {
    cat << EOF
Usage: convert_SMS_sqlite_to_xml.sh [OPTIONS] <sqlite_file.db> 
     -h|--help                                  Displays this help
     -v|--version                               Displays version
     -V|--verbose                               Displays verbose output
    -nc|--no-colour                             Disables colour output
    -lc|--let-csv                               Let the .csv temp file remain
     -o|--output=FILE                           create a xml file
     -m|--mode=[SuperBackup|BackupAndRestore]   Select mode (App compatibility)
EOF
}

# parse_params()
#----------------------------
# DESC: Parameter parser
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: Variables indicating command-line parameters and options
function parse_params() {
    local param
    local extra_input=()
    while [[ $# -gt 0 ]]; do
        param="$1"
        shift
        case $param in
            -h|--help)
                script_usage
                exit 0
                ;;
            -v|--version)
                echo "Version $VERSION"
                exit 0;
                ;;        
            -V|--verbose)
                verbose=true
                ;;
            -nc|--no-colour)
                no_colour=true
                ;;
            -lc|--let-csv)
                let_csv=true
                ;;
            -o=*|--output=*)
                output_file=true
                output_file_param="${param#*=}"
                ;;
            -m=*|--mode=*)
                mode=true
                mode_param="${param#*=}"
                ;;
            *)    # file 
           # echo ${param}
                extra_input+=("${param}") # save it in an array for later
                #shift # past argument
                ;;
     #       *)
     #           script_exit "Invalid parameter was provided: $param" 1
     #           ;;
        esac
    done
   # extra_input=()
    #echo "lolo: $extra_input"
    if [[ ${#extra_input[@]} -ne 0 ]]; then
        #echo  "size: "${#extra_input[@]}
        if [[ ${#extra_input[@]} -gt 1 ]]; then
            script_exit "Invalid parameter was provided: ${extra_input[1]}" 2
        else
            FILE_SQLITE=${extra_input[0]}
        fi
    else
        script_exit "No input file was provided !" 1
    fi

    #if []; then
    
    #elif []; then
    
    #fi
}

# script_trap_err()
#----------------------------
# DESC: Handler for unexpected errors
# ARGS: $1 (optional): Exit code (defaults to 1)
# OUTS: None
function script_trap_err() {
    local exit_code=1

    # Disable the error trap handler to prevent potential recursion
    trap - ERR

    # Consider any further errors non-fatal to ensure we run to completion
    set +o errexit
    set +o pipefail

    # Validate any provided exit code
    if [[ ${1-} =~ ^[0-9]+$ ]]; then
        exit_code="$1"
    fi

    # Output debug data if in Cron mode
    if [[ -n ${cron-} ]]; then
        # Restore original file output descriptors
        if [[ -n ${script_output-} ]]; then
            exec 1>&3 2>&4
        fi

        # Print basic debugging information
        printf '%b\n' "$ta_none"
        printf '***** Abnormal termination of script *****\n'
        printf 'Script Path:            %s\n' "$script_path"
        printf 'Script Parameters:      %s\n' "$script_params"
        printf 'Script Exit Code:       %s\n' "$exit_code"

        # Print the script log if we have it. It's possible we may not if we
        # failed before we even called cron_init(). This can happen if bad
        # parameters were passed to the script so we bailed out very early.
        if [[ -n ${script_output-} ]]; then
            printf 'Script Output:\n\n%s' "$(cat "$script_output")"
        else
            printf 'Script Output:          None (failed before log init)\n'
        fi
    fi

    # Exit with failure status
    exit "$exit_code"
}

# script_trap_exit()
#----------------------------
# DESC: Handler for exiting the script
# ARGS: None
# OUTS: None
function script_trap_exit() {
    cd "$orig_cwd"

    # Remove Cron mode script log
    if [[ -n ${cron-} && -f ${script_output-} ]]; then
        rm "$script_output"
    fi

    # Remove script execution lock
    if [[ -d ${script_lock-} ]]; then
        rmdir "$script_lock"
    fi

    # Restore terminal colours
    printf '%b' "$ta_none"
}

# script_exit()
#----------------------------
# DESC: Exit script with the given message
# ARGS: $1 (required): Message to print on exit
#       $2 (optional): Exit code (defaults to 0)
# OUTS: None
# NOTE: The convention used in this script for exit codes is:
#       0: Normal exit
#       1: Abnormal exit due to external error
#       2: Abnormal exit due to script error
function script_exit() {
    if [[ $# -eq 1 ]]; then
        printf '%s\n' "$1"
        exit 0
    fi

    if [[ ${2-} =~ ^[0-9]+$ ]]; then
        printf '%b\n' "$1"
        # If we've been provided a non-zero exit code run the error trap
        if [[ $2 -ne 0 ]]; then
            script_trap_err "$2"
        else
            exit 0
        fi
    fi

    script_exit 'Missing required argument to script_exit()!' 2
}

# script_init()
#----------------------------
# DESC: Generic script initialisation
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: $orig_cwd: The current working directory when the script was run
#       $script_path: The full path to the script
#       $script_dir: The directory path of the script
#       $script_name: The file name of the script
#       $script_params: The original parameters provided to the script
#       $ta_none: The ANSI control code to reset all text attributes
# NOTE: $script_path only contains the path that was used to call the script
#       and will not resolve any symlinks which may be present in the path.
#       You can use a tool like realpath to obtain the "true" path. The same
#       caveat applies to both the $script_dir and $script_name variables.
function script_init() {
    # Useful paths
    readonly orig_cwd="$PWD"
    readonly script_path="${BASH_SOURCE[0]}"
    readonly script_dir="$(dirname "$script_path")"
    readonly script_name="$(basename "$script_path")"
    readonly script_params="$*"

    # Important to always set as we use it in the exit handler
    readonly ta_none="$(tput sgr0 2> /dev/null || true)"
}

# colour_init()
#----------------------------
# DESC: Initialise colour variables
# ARGS: None
# OUTS: Read-only variables with ANSI control codes
# NOTE: If --no-colour was set the variables will be empty
function colour_init() {
    if [[ -z ${no_colour-} ]]; then
        # Text attributes
        readonly ta_bold="$(tput bold 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly ta_uscore="$(tput smul 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly ta_blink="$(tput blink 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly ta_reverse="$(tput rev 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly ta_conceal="$(tput invis 2> /dev/null || true)"
        printf '%b' "$ta_none"

        # Foreground codes
        readonly fg_black="$(tput setaf 0 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_blue="$(tput setaf 4 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_cyan="$(tput setaf 6 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_green="$(tput setaf 2 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_magenta="$(tput setaf 5 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_red="$(tput setaf 1 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_white="$(tput setaf 7 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_yellow="$(tput setaf 3 2> /dev/null || true)"
        printf '%b' "$ta_none"

        # Background codes
        readonly bg_black="$(tput setab 0 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_blue="$(tput setab 4 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_cyan="$(tput setab 6 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_green="$(tput setab 2 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_magenta="$(tput setab 5 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_red="$(tput setab 1 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_white="$(tput setab 7 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_yellow="$(tput setab 3 2> /dev/null || true)"
        printf '%b' "$ta_none"
    else
        # Text attributes
        readonly ta_bold=''
        readonly ta_uscore=''
        readonly ta_blink=''
        readonly ta_reverse=''
        readonly ta_conceal=''

        # Foreground codes
        readonly fg_black=''
        readonly fg_blue=''
        readonly fg_cyan=''
        readonly fg_green=''
        readonly fg_magenta=''
        readonly fg_red=''
        readonly fg_white=''
        readonly fg_yellow=''

        # Background codes
        readonly bg_black=''
        readonly bg_blue=''
        readonly bg_cyan=''
        readonly bg_green=''
        readonly bg_magenta=''
        readonly bg_red=''
        readonly bg_white=''
        readonly bg_yellow=''
    fi
}

# lock_init()
#----------------------------
# DESC: Acquire script lock
# ARGS: $1 (optional): Scope of script execution lock (system or user)
# OUTS: $script_lock: Path to the directory indicating we have the script lock
# NOTE: This lock implementation is extremely simple but should be reliable
#       across all platforms. It does *not* support locking a script with
#       symlinks or multiple hardlinks as there's no portable way of doing so.
#       If the lock was acquired it's automatically released on script exit.
function lock_init() {
    local lock_dir
    if [[ $1 = 'system' ]]; then
        lock_dir="/tmp/$script_name.lock"
    elif [[ $1 = 'user' ]]; then
        lock_dir="/tmp/$script_name.$UID.lock"
    else
        script_exit 'Missing or invalid argument to lock_init()!' 2
    fi

    if mkdir "$lock_dir" 2> /dev/null; then
        readonly script_lock="$lock_dir"
        verbose_print "Acquired script lock: $script_lock"
    else
        script_exit "Unable to acquire script lock: $lock_dir" 1
    fi
}

# pretty_print()
#----------------------------
# DESC: Pretty print the provided string
# ARGS: $1 (required): Message to print (defaults to a green foreground)
#       $2 (optional): Colour to print the message with. This can be an ANSI
#                      escape code or one of the prepopulated colour variables.
#       $3 (optional): Set to any value to not append a new line to the message
# OUTS: None
function pretty_print() {
    if [[ $# -lt 1 ]]; then
        script_exit 'Missing required argument to pretty_print()!' 2
    fi

    if [[ -z ${no_colour-} ]]; then
        if [[ -n ${2-} ]]; then
            printf '%b' "$2"
        else
            printf '%b' "$fg_green"
        fi
    fi

    # Print message & reset text attributes
    if [[ -n ${3-} ]]; then
        printf '%s%b' "$1" "$ta_none"
    else
        printf '%s%b\n' "$1" "$ta_none"
    fi
}

# verbose_print()
#----------------------------
# DESC: Only pretty_print() the provided string if verbose mode is enabled
# ARGS: $@ (required): Passed through to pretty_print() function
# OUTS: None
function verbose_print() {
    if [[ -n ${verbose-} ]]; then
        pretty_print "$@"
    fi
}


# convert_callslog_to_xml()
#----------------------------
# DESC: Use adb backup tool to backup app, then unpack it in a specific folder.
# ARGS: $1 (required): Source CSV file.
#       $2 (required): Destination xml file.
#       $2 (required): mode ["SuperBackup"|"BackupAndRestore"]
# OUTS: None
function convert_callslog_to_xml() {

    # usage: convert_callslog_to_xml "<file.csv>" "<file.xml> "SuperBackup" "   
    
    # Check
    if [[ $# -lt 3 ]]; then
        script_exit 'Missing required argument to convert_callslog_to_xml()!' 3
    fi
    
    # local variable
    local source_name=$1
    local dest_name=$2
    local mode=$3
    local count=$(cat $source_name  | wc -l)
    local temp_text=""
    local date_read=""
    local ifs_old=$IFS
    local date_int=""
    local name=""
    local header_xml_start=""
    #local current_date="$((`date +%s`*1000+`date +%-N`/1000000))"
    local current_date="$((10#`date +%s`*1000+10#`date +%-N`/1000000))"
    local backup_set="" # For BackupAndRestore
    
    # ---------------- CSV struct ---------------- #
    # ${column[0]}	:   number
    # ${column[1]}	:   duration
    # ${column[2]}	:   date
    # ${column[3]}	:   type
    # ${column[4]}	:   presentation
    # ${column[5]}	:   subscription_id
    # ${column[6]}	:   post_dial_digits
    # ${column[7]}	:   subscription_component_name
    # ${column[8]}	:   name
    # ${column[9]}	:   new

    # ------ *** Mode compatible "SuperBackup" App *** ------ #
    if [ $mode == "SuperBackup" ]; then
        [[ ! -z ${verbose-} ]] \
            && pretty_print \
            "$SCRIPT_NAME: Création du fichier $dest_name (APP:SuperBackup)" \
            $fg_blue
        
        # XML header
        echo '<?xml version="1.0" encoding="UTF-8"?>' > $dest_name
        echo "<alllogs count=\"$count\">" >> $dest_name
        
        # XML Call logs        
        while IFS=$';' read -r -a column
        do            
            # Make readable date
            date_read="$(date -d @"$((${column[2]}/1000))" +'%e %b %Y %T' )"
            date_read="$(echo $date_read | sed -e 's/^[[:space:]]*//' )"
            name=${column[8]}
            name=${name//'"'}
            
            # Make log call
            temp_text="     <log"
            temp_text+=" number=\"${column[0]}\""
            temp_text+=" time=\"$date_read\""
            temp_text+=" date=\"${column[2]}\""
            temp_text+=" type=\"${column[3]}\""
            temp_text+=" name=\"$name\""
            temp_text+=" new=\"${column[9]}\""
            temp_text+=" dur=\"${column[1]}\""
            temp_text+=" />"
            
            # Write file
            echo "$temp_text" >> $dest_name
            
            # reset variabme
            temp_text=""
            date_read=""
            name=""  
                     
        done < $source_name
        
        # XML END
        echo '</alllogs>' >> $dest_name
    
    # ------ *** Mode compatible "BackupAndRestore" App *** ------ #
    elif [ $mode == "BackupAndRestore" ]; then
        [[ ! -z ${verbose-} ]] \
            && pretty_print \
            "$SCRIPT_NAME: conversion en $dest_name (APP:BackupAndRestore)" \
            $fg_blue
        
        # Backup_set number
        backup_set="$(cat "/dev/urandom" | tr -dc 'a-z0-9' | fold -w 8 \
                    | head -n 1  2>&1 || EXIT_CODE=$?)"
        backup_set+="-$(cat "/dev/urandom" | tr -dc 'a-z0-9' | fold -w 4 \
                    | head -n 1  2>&1 || EXIT_CODE=$?)"
        backup_set+="-$(cat "/dev/urandom" | tr -dc 'a-z0-9' | fold -w 4 \
                    | head -n 1  2>&1 || EXIT_CODE=$?)"
        backup_set+="-$(cat "/dev/urandom" | tr -dc 'a-z0-9' | fold -w 4 \
                    | head -n 1  2>&1 || EXIT_CODE=$?)"
        backup_set+="-$(cat "/dev/urandom" | tr -dc 'a-z0-9' | fold -w 12 \
                    | head -n 1  2>&1 || EXIT_CODE=$?)"
       
        # XML header
        echo "<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>" \
            > $dest_name
        echo -e "<!--File Created By Phone_backup.sh for" >> $dest_name
        echo -e " Backup & Restore v10.08.004 on `date +'%D %T'`-->" \
            >> $dest_name
        header_xml_start="<!--"  
        header_xml_start+="\n\n"
        header_xml_start+="To view this file in a more readable format, "
        header_xml_start+="visit https://synctech.com.au/view-backup/"
        header_xml_start+="\n\n"
        header_xml_start+="-->\n"
        header_xml_start+="<calls count=\"$count\""
        header_xml_start+=" backup_set=\"$backup_set\""
        header_xml_start+=" backup_date=\"$current_date\""
        header_xml_start+=" type=\"full\">"
        echo -e $header_xml_start >> $dest_name
  
        # XML Call logs        
        while IFS=$';' read -r -a column
        do            
            # Make readable date
            date_read="$(date -d @"$((${column[2]}/1000))" +'%e %b %Y %T' )"
            date_read="$(echo $date_read | sed -e 's/^[[:space:]]*//' )"
            name=${column[8]}
            name=${name//'"'}
            
            # Make log call
            temp_text="  <call"
            temp_text+=" number=\"${column[0]}\""
            temp_text+=" duration=\"${column[1]}\""
            temp_text+=" date=\"${column[2]}\""
            temp_text+=" type=\"${column[3]}\""
            temp_text+=" presentation=\"${column[4]}\""
            temp_text+=" subscription_id=\"${column[5]}\""
            temp_text+=" post_dial_digits=\"${column[6]}\""
            temp_text+=" subscription_component_name=\"${column[7]}\""
            temp_text+=" readable_date=\"$date_read\""            
            temp_text+=" contact_name=\"$name\""
            temp_text+=" />"
             
            # Write file
            echo "$temp_text" >> $dest_name
            
            # reset variabme
            temp_text=""
            date_read=""
            name=""  
                     
        done < $source_name
        
        # XML END
        echo '</calls>' >> $dest_name
    
    else
        [[ ! -z ${verbose-} ]] \
            && pretty_print \
            "ERROR: convert_callslog_to_xml() Mauvais arguement Mode !" \
            $fg_red$ta_bold
        script_exit 1 "ERROR: in convert_callslog(), wrong mode used !"
    fi
    
    IFS=$ifs_old
    
}

###############################################################################
#     MAIN
###############################################################################


# DESC: Main control flow
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: None
function main() {

    # Init
    #----------------------------
    trap script_trap_err ERR
    trap script_trap_exit EXIT

    script_init "$@"
    parse_params "$@"
    colour_init
    #lock_init system

    # Check input
    #----------------------------
        
    # Check type file (.db)   
    if [[ $FILE_SQLITE != *".db" ]]; then
        script_exit "ERROR: Wrong type of input file: $FILE_SQLITE" 3
    fi
    
    # Check if file exite
    if (test -f "$FILE_SQLITE"); then
        # Get dir localtion
        PATH_FILE_DIR=$(dirname $(readlink -f $FILE_SQLITE))
    else
        script_exit "ERROR: File not found ! $FILE_SQLITE" 5
    fi
    
    # Check mode
    if [[ -n ${mode-} ]]; then
        case $mode_param in
            SuperBackup)
                MODE=1
                ;;
            BackupAndRestore)
                MODE=2
                ;;
            *)  # Wrong mode 
                script_exit "ERROR: Wrong mode: $mode_param" 4
                ;;
        esac
        CONFIG_FILE=$mode_param
    fi
    
    # Init var
    #---------------------------
    PATH_FILE_SQLITE=$(readlink -f $FILE_SQLITE)
    PATH_FILE_CSV="${PATH_FILE_SQLITE/'.db'/'.csv'}"
    FILE_XML_OUTPUT="${PATH_FILE_SQLITE/'.db'/}_$JOUR.xml"
    
    # Given file output    
    if [[ -n ${output_file-} ]]; then
        FILE_XML_OUTPUT=$(readlink -f $output_file_param)
        
        # Check if empty
        [[ ! -n $FILE_XML_OUTPUT ]] \
            && script_exit "ERROR: empty output name" 6
    fi
    
    # Force .xml file
    [[ ! $FILE_XML_OUTPUT == *".xml"  ]] \
        && FILE_XML_OUTPUT="$FILE_XML_OUTPUT.xml"

    # Mode Choice
    #---------------------------

    # if mode empty, let choose mode prompt
    if !([[ -n ${mode-} ]]); then
        pretty_print "Veuillez choisir un mode de compatibilité:"
        pretty_print " 1: SuperBackup App"
        pretty_print " 2: BackupAndRestore App"
        read -p "Mode: " MODE
        
        # Check input
        if [ -z "${MODE##*[!1-2]*}" ]; then
            script_exit "ERROR: Wrong mode: $MODE" 4
        fi

    fi
    
    # Export CSV
    #---------------------------
    sqlite3 "$FILE_SQLITE" -csv -separator ";" \
        "SELECT number,
                duration,
                date,
                type,
                presentation,
                subscription_id,
                post_dial_digits,
                subscription_component_name,
                name,
                new   
        FROM calls 
        ORDER BY date DESC;" \
        > $PATH_FILE_CSV
   
    # Create XML CSV
    #---------------------------
    
    # Create XML files compatible SuperBackup
    if [ $MODE -eq 1 ]; then
        [[ ! -z ${verbose-} ]] \
            && pretty_print \
            "$SCRIPT_NAME: Making XML file : mode SuperBackup" $fg_blue
        convert_callslog_to_xml "$PATH_FILE_CSV" \
        "$FILE_XML_OUTPUT" \
        "SuperBackup"
    fi
    # Create XML files compatible BackupAndRestore  
    if [ $MODE -eq 2 ]; then
        [[ ! -z ${verbose-} ]] \
            && pretty_print \
            "$SCRIPT_NAME: Making XML file : mode BackupAndRestore" $fg_blue
        convert_callslog_to_xml "$PATH_FILE_CSV" \
        "$FILE_XML_OUTPUT" \
        "BackupAndRestore"
    fi
        
    # Clean
    #---------------------------
    if [[ -z ${let_csv-} ]]; then
        rm $PATH_FILE_CSV
    fi
    
}

# START
#----------------------------
main "$@"

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
