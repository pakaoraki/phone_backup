#!/usr/bin/env bash

# Phone backup/restore scripts
# Copyright (C) 2021 Pakaoraki <pakaoraki@gmx.com>
#
# From https://github.com/ralish/bash-script-template/blob/main/template.sh
#      by Ralish
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

###############################################################################
#                                                                             #
#                                 SOURCE.SH                                   #
#                                                                             #
###############################################################################

#-----------------------------------------------------------------------------#
#     Author(s): Pakaoraki
#     Version: 1.0
#     Date: 23/07/2021
#     Description: Base functions for better class of scripts.
#                 
#-----------------------------------------------------------------------------#

###############################################################################
#     CONST
###############################################################################

# Common
#----------------------------
    VERSION="1.0"
    RESOURCES="ressources"

# Files name
#----------------------------
    FILE_MUSIC_BACKUP_NAME="List_music_files.txt"
    #PHONE_CALLS_CSV_FILE_NAME="Calllog.csv"
    SCRIPT_CONVERT_CONTACT="$RESOURCES/convert_contacts_to_vcard.sh"
    SCRIPT_CONVERT_SMS="$RESOURCES/convert_SMS_MMS_sqlite_to_xml.sh"
    SCRIPT_CONVERT_CALLLOGS="$RESOURCES/convert_calllog_sqlite_to_xml.sh"
    CONFIG_FILE="./backup.conf"
  
# Dependencies - binaries
#----------------------------
    
    # Android unarchiver
    ANDROID_UNARCHIVER_SOURCE="https://github.com/nelenkov/"
    ANDROID_UNARCHIVER_SOURCE+="android-backup-extractor/releases/"
    ANDROID_UNARCHIVER_SOURCE+="latest/download/abe.jar"
    ANDROID_UNARCHIVER="$RESOURCES/abe.jar"  
  
    # AAPT2
    AAPT2_VERSION="7.0.3-7396180"
    AAPT2_NAME="aapt2"
    AAPT2_CMD="$RESOURCES/$AAPT2_NAME"
    AAPT2_DOWNLOAD="https://dl.google.com/dl/android/maven2/com/android/tools/"
    AAPT2_DOWNLOAD+="build/aapt2/$AAPT2_VERSION/aapt2-$AAPT2_VERSION-linux.jar"

# Folders
#----------------------------
    FOLDER_BACKUP_NAME="Phone/BACKUP"
    FOLDER_BACKUP_PHOTOS="PHOTOS"
    FOLDER_CONTACTS_NAME="1-Contacts_and_logs"
    FOLDER_MMS_SMS_NAME="2-SMS_MMS"
    FOLDER_APP_NAME="3-Apps"
    FOLDER_PHOTOS_NAME="4-Photos"
    FOLDER_MUSIC_NAME="5-Music"
    FOLDER_FILES_NAME="6-Files"
    FOLDER_BOOKMARKS_NAME="7-Bookmarks"
    FOLDER_RINGTONES_NAME="8-Ringtones_and_Notifications"
    #FOLDER_APK="9-APK"    

# Backup Photos
#----------------------------
    BCK_IMG_TEMP_FILE=".temp_files.txt"
    BCK_IMG_COPIED_FILE="list_copied.txt"
    BCK_IMG_SKIPED_FILE="list_skiped.txt"
    BCK_IMG_REMOVED_FILE="files_removed.txt"

# Backup Applications
#----------------------------
    ALL_APPS_PACKAGE_BCK="all_data_apps.ab"
    ALL_APPS_PACKAGE_SYSTEM_BCK="all_data_apps_system.ab"

# ADB
#----------------------------

    # Backup folder
    ADB_BACKUP_SOURCE_FOLDER="/storage/0000-0000/BACKUP"
    ADB_BACKUP_SIGNAL="$ADB_BACKUP_SOURCE_FOLDER/Signal"
    ADB_BACKUP_SEEDVAULT="$ADB_BACKUP_SOURCE_FOLDER/.SeedVaultAndroidBackup"
    
    # Contacts and logs 
    ADB_CONTACTS="/data/data/com.android.providers.contacts/databases/"
    
    # SMS/MMS
    ADB_MMS_SMS="/data/user_de/0/com.android.providers.telephony/databases/"
    ADB_MMS_SMS_DATA="/data/user_de/0/com.android.providers.telephony/app_parts/"
    
    # Whatsapp
    ADB_APPS_WHATSAPP_KEY="/data/data/com.whatsapp/files/key"
    ADB_APPS_WHATSAPP_MAIN="/data/data/com.whatsapp/databases"    
    ADB_APPS_WHATSAPP_MESSAGES="/storage/emulated/0/whatsApp/Databases"
    
    # Apps Canonical Name
    ADB_APP_NOTES="com.simplemobiletools.notes.pro"
    ADB_APP_FALLOUT="com.bethsoft.falloutshelter"
    ADB_APP_CHROME="com.android.chrome"
    ADB_APP_FIREFOX="org.mozilla.firefox"
    ADB_APP_WAZE="package:com.waze"     
    ADB_APP_SIGNAL="org.thoughtcrime.securesms" 

    # Brownser Bookmarks and data location
    ADB_BOOKMARKS_CHROME="/data/data/com.android.chrome"
    ADB_BOOKMARKS_CHROME+="/app_chrome/Default/Bookmarks"
    ADB_BOOKMARKS_FIREFOX="/data/data/org.mozilla.firefox/"
    ADB_BOOKMARKS_FIREFOX+="files/places.sqlite"    
    ADB_APPS_FIREFOX_DATA="/data/data/org.mozilla.firefox/files"
    ADB_APPS_CHROME_DATA="/data/data/com.android.chrome"
    ADB_APPS_CHROME_DATA+="/app_chrome/Default"   
    
    
###############################################################################
#     VARIABLES
###############################################################################

# Common
#----------------------------
    JOUR=`date +%Y_%m_%d`   
    TIMESTAMP=`date +%d/%m/%Y-%T`    
    #CURRENT_FOLDER="`dirname \"$0\"`"
    SCRIPT_LOCATION="$(readlink -e $BASH_SOURCE)"
    #CURRENT_FOLDER_ABS="`( cd \"$CURRENT_FOLDER\" && pwd )`" 
    CURRENT_FOLDER_ABS="$(dirname """$SCRIPT_LOCATION""")"
    TIME_START=""
    TIME_END=""
    TIME=""
    #IS_FILE_CONF_LOAD="false" # Leave false
    BOOL_STATE=".state"
    #ANDROID_UNARCHIVER="abe-all.jar"
    PASSWORD=""

# Restore
#----------------------------
    LIST_APPS_TO_RESTORE=()
    LIST_APPS_TO_RESTORE_PRINT=""  

# Log
#----------------------------
    LOG_DIR=$CURRENT_FOLDER_ABS
    LOG_PATTERN=$LOG_DIR/sauvegarde_$JOUR
    LOG_FILE=$LOG_PATTERN.log
    
# Folders
#----------------------------
    FOLDER_CURRENT_BACKUP=""
    SOURCE_IMG=""
    DEST_TODAY_IMG=""
    LATEST_IMG=""

# ADB
#----------------------------
    DEVICE_NAME=""   
    SRV_DEVICE=""
       
# Path
#----------------------------
    PATH_BACKUP_FOLDER="/home/$USER/$FOLDER_BACKUP_NAME"
    PATH_RESTORE_FOLDER=""
    PATH_CURRENT_BACKUP=""
    PATH_CONTACTS_FOLDER=""
    PATH_MMS_SMS_FOLDER=""
    PATH_APP_FOLDER=""
    PATH_PHOTOS_FOLDER=""
    PATH_MUSIC_FOLDER=""
    PATH_FILES_FOLDER=""
    PATH_BOOKMARK_FOLDER=""
    PATH_RINGTONES_FOLDER=""
    PATH_APK_FOLDER=""
    PATH_CURRENT_BACKUP=""
    PATH_INTERNAL_MEM="/storage/emulated/0"
    PATH_MUSIC_STORAGE="$PATH_INTERNAL_MEM/Music/"
    PATH_DOWNLOADS_STORAGE="$PATH_INTERNAL_MEM/Download/" 
    PATH_MEDIA_DCIM="$PATH_INTERNAL_MEM/DCIM"
    PATH_MEDIA_SNAPSEED="$PATH_INTERNAL_MEM/Snapseed"
    PATH_MEDIA_WHATSAPP="$PATH_INTERNAL_MEM/WhatsApp/Media"
    PATH_RINGTONES_STORAGE="$PATH_INTERNAL_MEM/Ringtones"
    PATH_NOTIFICATIONS_STORAGE="$PATH_INTERNAL_MEM/Notifications"
    PATH_DOCS_STORAGE="$PATH_INTERNAL_MEM/Documents"       
    PATH_SCRIPT_CONTACT="$CURRENT_FOLDER_ABS/$SCRIPT_CONVERT_CONTACT"
    PATH_SCRIPT_SMS="$CURRENT_FOLDER_ABS/$SCRIPT_CONVERT_SMS"
    PATH_SCRIPT_CALLLOGS="$CURRENT_FOLDER_ABS/$SCRIPT_CONVERT_CALLLOGS"
    PATH_ANDROID_UNARCHIVER="$CURRENT_FOLDER_ABS/$ANDROID_UNARCHIVER"
    PATH_PHOTO_LATEST=""
    PATH_PHOTO_TODAY=""

# Restore bool
#----------------------------
    RESTORE_CONTACTS=false
    RESTORE_CALLLOG=false
    RESTORE_MMS_SMS=false
    RESTORE_APPS=false
    RESTORE_PHOTOS=false
    RESTORE_RINGTONES=false
    RESTORE_DOWNLOADS=false
    RESTORE_MUSIC=false
    RESTORE_DOCS=false
    MODE_REST_PHOTOS="latest"
    MODE_REST_APPS="APK"


###############################################################################
#     FUNCTIONS
###############################################################################

# A best practices Bash script template with many useful functions. This file
# is suitable for sourcing into other scripts and so only contains functions
# which are unlikely to need modification. It omits the following functions:
# - main()
# - parse_params()
# - script_usage()

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
# shellcheck disable=SC2034
function script_init() {
    # Useful variables
    readonly orig_cwd="$PWD"
    readonly script_params="$*"
    readonly script_path="${BASH_SOURCE[1]}"
    script_dir="$(dirname "$script_path")"
    script_name="$(basename "$script_path")"
    readonly script_dir script_name

    # Important to always set as we use it in the exit handler
    # shellcheck disable=SC2155
    readonly ta_none="$(tput sgr0 2> /dev/null || true)"
}

# colour_init()
#----------------------------
# DESC: Initialise colour variables
# ARGS: None
# OUTS: Read-only variables with ANSI control codes
# NOTE: If --no-colour was set the variables will be empty. The output of the
#       $ta_none variable after each tput is redundant during normal execution,
#       but ensures the terminal output isn't mangled when running with xtrace.
# shellcheck disable=SC2034,SC2155
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

# cron_init()
#----------------------------
# DESC: Initialise Cron mode
# ARGS: None
# OUTS: $script_output: Path to the file stdout & stderr was redirected to
function cron_init() {
    if [[ -n ${cron-} ]]; then
        # Redirect all output to a temporary file
        script_output="$(mktemp --tmpdir "$script_name".XXXXX)"
        readonly script_output
        exec 3>&1 4>&2 1> "$script_output" 2>&1
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

# log_rotate()
#----------------------------
# DESC: Change name of the log file if needed
# ARGS: $1 (required): Log file var name.
# OUTS: None
function log_rotate() {

    # Check
    if [[ $# -lt 1 ]]; then
        script_exit 'Missing required argument to log_rotate()!' 2
    fi

    # local
    local int=0
    local max_file=50
    local __log_file=$1
    local log_full_name=${!1}
    local name_pattern=$log_full_name
    
    while test -f "$log_full_name" && [ $int -le $max_file ]
    do  
        log_full_name=${name_pattern/.log/}"_$int.log"
        int=$((int+1))
    done
    
    # Update log var with new value
    eval $__log_file="'$log_full_name'"
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

# build_path()
#----------------------------
# DESC: Combines two path variables and removes any duplicates
# ARGS: $1 (required): Path(s) to join with the second argument
#       $2 (optional): Path(s) to join with the first argument
# OUTS: $build_path: The constructed path
# NOTE: Heavily inspired by: https://unix.stackexchange.com/a/40973
function build_path() {
    if [[ $# -lt 1 ]]; then
        script_exit 'Missing required argument to build_path()!' 2
    fi

    local new_path path_entry temp_path

    temp_path="$1:"
    if [[ -n ${2-} ]]; then
        temp_path="$temp_path$2:"
    fi

    new_path=
    while [[ -n $temp_path ]]; do
        path_entry="${temp_path%%:*}"
        case "$new_path:" in
            *:"$path_entry":*) ;;
            *)
                new_path="$new_path:$path_entry"
                ;;
        esac
        temp_path="${temp_path#*:}"
    done

    # shellcheck disable=SC2034
    build_path="${new_path#:}"
}

# check_binary()
#----------------------------
# DESC: Check a binary exists in the search path
# ARGS: $1 (required): Name of the binary to test for existence
#       $2 (optional): Set to any value to treat failure as a fatal error
# OUTS: None
function check_binary() {
    if [[ $# -lt 1 ]]; then
        script_exit 'Missing required argument to check_binary()!' 2
    fi

    if ! command -v "$1" > /dev/null 2>&1; then
        if [[ -n ${2-} ]]; then
            script_exit "Missing dependency: Couldn't locate $1." 1
        else
            verbose_print "Missing dependency: $1" "${fg_red-}"
            return 1
        fi
    fi

    verbose_print "Found dependency: $1"
    return 0
}

# check_superuser()
#----------------------------
# DESC: Validate we have superuser access as root (via sudo if requested)
# ARGS: $1 (optional): Set to any value to not attempt root access via sudo
# OUTS: None
function check_superuser() {
    local superuser
    if [[ $EUID -eq 0 ]]; then
        superuser=true
    elif [[ -z ${1-} ]]; then
        if check_binary sudo; then
            verbose_print 'Sudo: Updating cached credentials ...'
            if ! sudo -v; then
                verbose_print "Sudo: Couldn't acquire credentials ..." \
                    "${fg_red-}"
            else
                local test_euid
                test_euid="$(sudo -H -- "$BASH" -c 'printf "%s" "$EUID"')"
                if [[ $test_euid -eq 0 ]]; then
                    superuser=true
                fi
            fi
        fi
    fi

    if [[ -z ${superuser-} ]]; then
        verbose_print 'Unable to acquire superuser credentials.' "${fg_red-}"
        return 1
    fi

    verbose_print 'Successfully acquired superuser credentials.'
    return 0
}

# run_as_root()
#----------------------------
# DESC: Run the requested command as root (via sudo if requested)
# ARGS: $1 (optional): Set to zero to not attempt execution via sudo
#       $@ (required): Passed through for execution as root user
# OUTS: None
function run_as_root() {
    if [[ $# -eq 0 ]]; then
        script_exit 'Missing required argument to run_as_root()!' 2
    fi

    if [[ ${1-} =~ ^0$ ]]; then
        local skip_sudo=true
        shift
    fi

    if [[ $EUID -eq 0 ]]; then
        "$@"
    elif [[ -z ${skip_sudo-} ]]; then
        sudo -H -- "$@"
    else
        script_exit "Unable to run requested command as root: $*" 1
    fi
}

# init_adb()
#----------------------------
# DESC: Start adb server with root priviledge.
# ARGS: None
# OUTS: None
function init_adb() {
    
    # Start ADB server
    echo -en "$fg_cyan"
    local adb_error=""
    local mess_check=" Please authorize ADB device on your phone screen."
    local mess_press_key="Press any key to continue..."
    adb start-server    
    
    # Wait until accept credential on the phone
    pretty_print "$mess_check"
    echo -en "$fg_cyan$ta_bold"
    read -p "$mess_press_key"
    echo -en "$ta_none"
    
    # Mode root
    pretty_print " Enable ROOT mode..."
    echo -en "$fg_cyan"
    adb root || adb_error=$?    
    if [[ $adb_error -ne 0 ]]; then
        pretty_print " Need to restart ADB with root-priviledge." \
            $fg_yellow$ta_bold
        echo -en "$fg_cyan"
        run_as_root adb kill-server
        sleep 1
        run_as_root adb start-server
        pretty_print "$mess_check"
        echo -en "$fg_cyan$ta_bold"
        read -p "$mess_press_key"
        sleep 1
        echo -en "$ta_none$fg_cyan"     
        adb root
    fi
    pretty_print "$mess_check"
    echo -en "$fg_cyan$ta_bold"
    read -p "$mess_press_key"
    echo -en "$ta_none"
}

# check_dependencies()
#----------------------------
# DESC: Check dependencies
# ARGS: None
# OUTS: None
function check_dependencies() {

    # Local
    local err_mess=""
    local exit_code=""
    
    # convert_contacts_to_vcard
    if !(test -f $PATH_SCRIPT_CONTACT); then
        err_mess="Missing Script $SCRIPT_CONVERT_CONTACT: "
        err_mess+="$SCRIPT_CONVERT_CONTACT not found !"
         script_exit "$err_mess" 8
    fi
    
    # convert_calllog_sqlite_to_xml
    if !(test -f $PATH_SCRIPT_CALLLOGS); then
        err_mess="Missing Script $SCRIPT_CONVERT_CALLLOGS: "
        err_mess+="$PATH_SCRIPT_CALLLOGS not found !"
        script_exit "$err_mess" 8
    fi
    
    # convert_SMS_MMS_sqlite_to_xml
    if !(test -f $PATH_SCRIPT_SMS); then
        err_mess="Missing Script $SCRIPT_CONVERT_SMS: "
        err_mess+="$PATH_SCRIPT_SMS not found !"
        script_exit "$err_mess" 8
    fi
    
    # Get Android Unarchiver .jar
    if ! test -f "./$ANDROID_UNARCHIVER" ; then
        pretty_print " Android Backup Extractor is missing !" \
            $fg_yellow$ta_bold
        pretty_print " => Download ABE from source..." $fg_yellow
        wget --quiet "$ANDROID_UNARCHIVER_SOURCE" -P "./$RESOURCES/" \
            || exit_code=$?
        [[ $exit_code -ne 0 ]] && \
            pretty_print "failed to download $ANDROID_UNARCHIVER_SOURCE..." \
                $fg_red$ta_bold \
            && pretty_print "Exit script !" $fg_red$ta_bold \
            && script_exit 5 "Error download dependancies"
        chmod +x "./$ANDROID_UNARCHIVER"
    fi
    
    # Get AAPT2.jar
    if ! test -f "./$AAPT2_CMD" ; then
        pretty_print " AAPT2 is missing !" \
            $fg_yellow$ta_bold
        pretty_print " => Download AAPT2 from source..." $fg_yellow
        wget --quiet "$AAPT2_DOWNLOAD" -P "./$RESOURCES/" \
            || exit_code=$?
        [[ $exit_code -ne 0 ]] && \
            pretty_print "failed to download $AAPT2_DOWNLOAD..." \
                $fg_red$ta_bold \
            && pretty_print "Exit script !" $fg_red$ta_bold \
            && script_exit 5 "Error download dependancies"
        
        # Unpack file
        unzip -p "./$RESOURCES/$AAPT2_NAME-$AAPT2_VERSION-linux.jar" \
            "$AAPT2_NAME" > "./$AAPT2_CMD"
        
        # Add executable
        chmod +x "./$AAPT2_CMD"
        
        # Clean 
        rm "./$RESOURCES/$AAPT2_NAME-$AAPT2_VERSION-linux.jar"
    fi
    
    # Detect OS packet manager
    pkg_manager_cmd=""
    sqlite_pkg="sqlite3 libsqlite3-dev"
    adb_pck="adb android-tools-adb"
    
    # Debian/Ubuntu
    if check_binary "apt"; then
        pkg_manager_cmd="apt -y install"
        
    # Fedora
    elif check_binary "dnf"; then
        pkg_manager_cmd="dnf install -y"
        sqlite_pkg="sqlite libsqlite3x-devel"
        adb_pck="adb android-tools"
    fi

    # Install package if needed...
    if [[ "$pkg_manager_cmd" != "" ]]; then
        if ! check_binary "adb"; then
            pretty_print " => adb tools missing, installing it..."
            run_as_root $pkg_manager_cmd $adb_pck
        fi
        
        if ! check_binary "base64"; then
            pretty_print " => coreutils (base64) missing, installing it..."
            run_as_root $pkg_manager_cmd coreutils
        fi
        
        if ! check_binary "sqlite3"; then
            pretty_print " => Sqlite3 missing, installing it..."
            run_as_root $pkg_manager_cmd $sqlite_pkg
        fi
    else
        pretty_print "Impossible to detect the packet manager" \
        $fg_yellow$ta_bold 
    fi

}

# read_password()
#----------------------------
# DESC: Use read command to get password from user (hide caracters with *).
# ARGS: $1 (optional): Message to prompt (Default 'Enter Password:').
#       $2 (optional): Caracter for hiding password (default '*').
# OUTS: None
function read_password() {

    # Check
    if [[ $# -gt 2 ]]; then
        script_exit 'Missing required argument to read_password()!' 2
    fi
    
    # Local
    local message="Enter Password:"
    local hiding_char='*'
    [[ $# -ge 1 ]] && message="$1"
    [[ $# -eq 2 ]] && hiding_char="$2"
    
    unset PASSWORD
    prompt=$message
    while IFS= read -p "$prompt" -r -s -n 1 char
    do
        if [[ $char == $'\0' ]]
        then
            break
        fi
        prompt="$hiding_char"
        PASSWORD+="$char"
    done
    echo
}

# countdown()
#----------------------------
# DESC: Print a countdown.
# ARGS: $1 (optional): countdown time in second.       
# OUTS: /dev/shm/coundown_state set to 1 when finish (shared memory).
function countdown {

    # local
    local max_second=10

    if [[ $# -eq 1 ]]; then
        max_second=$1
    fi
    
    echo 0 >/dev/shm/coundown_state

	for i in `seq $max_second -1 1`; do 
		tput sc
		pretty_print "($i second left)   " $fg_yellow$ta_bold "no_line"
		tput rc
		sleep 1
	done
	tput rc
	pretty_print "                    "

    # Acknowledge when timer is over ins shared memory 
	echo 1 >/dev/shm/coundown_state

}

# backup_app()
#----------------------------
# DESC: Use adb backup tool to backup app, then unpack it in a specific folder.
# ARGS: $1 (required): App Name.
#       $2 (required): cononical android app name (ex: com.whatsapp).
# OUTS: None
function backup_app() {

    # usage: backup_app "<app_name>" "<canonical_app_name>"   
    
    # Check
    if [[ $# -lt 2 ]]; then
        script_exit 'Missing required argument to backup_app()!' 2
    fi

    # local variable
    local app_name=$1
    local android_app=$2
    local pass_notes=""
    local app_folder=$PATH_APP_FOLDER/$app_name
    
    # Create Whatsapp Notes folder
    pretty_print " => $app_name: Create dir $app_folder"
    if !(test -d "$app_folder"); then
        mkdir -p "$app_folder"
    fi 
    
    pretty_print " => backup: $app_name..."
    pretty_print " $app_name: Please choose a password on your phone screen."
    
    # Backup
    adb backup -f "$app_folder/$app_name.ab" -apk "$android_app"
       
    # Stop countdown if a'db backup' is successfuly and escape script if not.
    [[ $(</dev/shm/coundown_state) == 1 ]] \
        && [[ $(wc -c  "$app_folder/$app_name.ab" | awk '{print $1}') -eq 0 ]]  \
        && script_exit "Adb backup failed !" 9 \
        || kill $Y
    
    # Get password
    pretty_print " $app_name: Please enter the same password here."
    read_password
    pretty_print " "

    # Unpack
    pretty_print " => $app_name: Extract encrypted $app_name.ab package..."
    #java -jar ./abe-all.jar unpack "$app_folder/$app_name.ab" \
    java -jar $PATH_ANDROID_UNARCHIVER unpack "$app_folder/$app_name.ab" \
        "$app_folder/$app_name.tar" \
        $pass_notes
        
    # Save password
    pretty_print " => $app_name: Export password for app_name backup..."
    #echo "pass: "$pass_notes
    echo $pass_notes > "$app_folder/.pass"
    
    # Untar
    pretty_print " => $app_name: Extract $app_name.tar..."
    tar -C "$app_folder/" -xf "$app_folder/$app_name.tar"

}

# backup_all_apps()
#----------------------------
# DESC: Use adb backup tool to backup all app, then unpack it in a specific folder.
# ARGS: $1 (optional): Options [system|no_system].
# OUTS: None
function backup_all_apps() {

    # usage: backup_app "no_system"   
    #        backup_app "system"  
    
    # Check
    if [[ $# -gt 1 ]]; then
        script_exit 'Missing required argument to backup_all_app()!' 2
    fi

    # Local
    local options="no_system" 
    local package_name="$ALL_APPS_PACKAGE_BCK"

    # Check options
    [[ $# -eq 1 ]] && options=$1
    if [[ "$options" != "system" ]] && [[ "$options" != "no_system" ]]; then
        script_exit 'Wrong argument to backup_all_app()!' 2
    fi

    # Create Applications folder if needed
    if !(test -d "$PATH_APP_FOLDER"); then
        pretty_print " => Backup Applications: Create folder $PATH_APP_FOLDER" \
            $fg_cyan
        mkdir -p "$PATH_APP_FOLDER"
    fi 
    
    # Message
    message=" => Backup All Apps: Please choose a password on your phone "
    message+="screen."
    
    # Note: 'adb backup' have a 1 minute timeout that ignore backup if user skip
    #       entering password.

    # Backup Apps (No system Apps)
    if [[ "$options" == "no_system" ]]; then
        pretty_print " => Backup All Apps (System apps exluded)" \
            $fg_cyan$ta_bold
        pretty_print "$message" $fg_cyan
        
        # ADB Backup
        echo -en "$fg_green"
        
        # Backup in separate process
        adb backup -f "$PATH_APP_FOLDER/$package_name" \
            -all -obb -noapk -nosystem & X=$!
           
    # Backup Apps (System Apps)    
    elif [[ "$options" == "system" ]]; then
        pretty_print " => Backup All Apps (System apps included)" \
            $fg_cyan$ta_bold
        pretty_print "$message" $fg_cyan
        package_name="$ALL_APPS_PACKAGE_SYSTEM_BCK"
        
        # ADB Backup
        echo -en "$fg_green"
        adb backup -f "$PATH_APP_FOLDER/$package_name" \
            -all -obb -noapk -system & X=$!
    fi
    
    # Start countdown of 60s in separate process
    countdown 60 & Y=$!
    
    # Wait 'adb backup' to finish
    wait $X
    
    # Stop countdown if 'adb backup' is successfuly and escape script if not.
    [[ $(</dev/shm/coundown_state) == 1 ]] \
        && [[ $(wc -c  "$PATH_APP_FOLDER/$package_name" \
            | awk '{print $1}') -eq 0 ]]  \
        && pretty_print "ADB backup timeout, exit !" $fg_red$ta_bold \
        && script_exit "ADB backup failed !" 9 \
        || (kill $Y 2&> /dev/null || true)

    # Get password
    pretty_print " => Backup All Apps: Please enter the same password here." \
        $fg_cyan
    echo -en "$fg_green"
    read_password

    # Check given password
    nb_attemp=15
    while [[ $nb_attemp -ne 0 ]] \
        && ! check_password_ab "$package_name" "$PASSWORD"; do
        nb_attemp=$((nb_attemp-1))
        pretty_print " => Backup All Apps: Wrong password, please retry." \
            $fg_red$ta_bold
        pretty_print " => Backup All Apps: Please enter the same password here." \
            $fg_cyan
        echo -en "$fg_green"
        read_password
    done
   
    if check_password_ab "$package_name" "$PASSWORD";then
        pretty_print " => Backup All Apps: Password verified successfuly." \
            $fg_cyan
    else
        pretty_print " => ERROR: bad password, cancel the backup." \
            $fg_red$ta_bold
        scrip_exit "bad password" 3
    fi
    
    # Save password
    pretty_print " => Backup All Apps: Export password for $package_name backup..." \
        $fg_cyan
    echo $PASSWORD > "$PATH_APP_FOLDER/.${package_name//.ab/}_pass"    
}

# unpack_adb_archive()
#----------------------------
# DESC: Decrypt and unpack adb archive in an hidden folder with same 
#       basename as archive.
# ARGS: $1 (required) : adb archive file name.
# OUTS: Update var with new file name.
function unpack_adb_archive() {
    
    # Check
    if [[ $# -lt 1 ]]; then
        script_exit 'Missing required argument to unpack_adb_archive()!' 2
    fi

    # Local
    local adb_archive_name="$1" 
    local pass=""
    
    # Unpack
    if test -f "$PATH_APP_FOLDER/$adb_archive_name"; then
        
        # Get password
        if test -f "$PATH_APP_FOLDER/.${adb_archive_name/.ab/_pass}"; then
            pretty_print " => Unpack Apps: recover password..." $fg_cyan
            pass=$(cat "$PATH_APP_FOLDER/.${adb_archive_name/.ab/_pass}")
        else
            mess=" => Unpack Apps: failed to recover password,"
            mess+=" file not found."
            pretty_print "$mess" $fg_red$ta_bold
        fi
        
        pretty_print " => Unpack Apps: Unpack encrypted $adb_archive_name" \
            $fg_cyan
        echo -en "$fg_blue"
        java -jar $PATH_ANDROID_UNARCHIVER unpack \
            "$PATH_APP_FOLDER/$adb_archive_name" \
            "$PATH_APP_FOLDER/.${adb_archive_name//.ab/}.tar" \
            $pass
        pretty_print ""
          
        # Untar
        mkdir -p "$PATH_APP_FOLDER/.${adb_archive_name//.ab/}/"
        pretty_print " => Unpack Apps: Extract ${adb_archive_name//.ab/}.tar..." \
            $fg_cyan
        tar -C "$PATH_APP_FOLDER/.${adb_archive_name//.ab/}/" -xf \
            "$PATH_APP_FOLDER/.${adb_archive_name//.ab/}.tar"
    else
         pretty_print " => Error: $PATH_APP_FOLDER/$adb_archive_name is missing !" \
            $fg_red$ta_bold
    fi 
    

}

# check_password_ab()
#----------------------------
# DESC: Check password use to unpack .ab archive.
# ARGS: $1 (required) : adb archive file name.
#       $2 (required) : password.
# OUTS: None
function check_password_ab() {
  
    # Check
    if [[ $# -lt 2 ]]; then
        script_exit 'Missing required argument to check_password_ab()!' 2
    fi
    
    # Local
    local adb_archive_name="$1" 
    local pass="$2"
    local etat=1
    
    if test -f "$PATH_APP_FOLDER/$adb_archive_name"; then
        mkdir -p "$PATH_APP_FOLDER/.temp"
        
        java -jar $PATH_ANDROID_UNARCHIVER unpack \
            "$PATH_APP_FOLDER/$adb_archive_name" \
            "$PATH_APP_FOLDER/.temp/.${adb_archive_name//.ab/}.tar" \
            $pass 2&> /dev/null
        [[ $? -eq 0 ]] && etat=0
        
        # Clean
        rm -R "$PATH_APP_FOLDER/.temp"
    fi
    
    return $etat
    
}

# clean_unpacked_adb_archive()
#----------------------------
# DESC: Removes unpacked files from given archive.
# ARGS: $1 (required) : adb archive file path.
# OUTS: None
function clean_unpacked_adb_archive() {
    
    # Check
    if [[ $# -lt 1 ]]; then
        script_exit 'Missing required argument to clean_unpacked_adb_archive()!' 2
    fi

    # Local
    local adb_archive_name="$1"
    
    # Clean 
    if test -d "$PATH_APP_FOLDER/.${adb_archive_name//.ab/}"; then
        rm -R "$PATH_APP_FOLDER/.${adb_archive_name//.ab/}"
    fi
    if test -f "$PATH_APP_FOLDER/.${adb_archive_name//.ab/}.tar"; then
        rm "$PATH_APP_FOLDER/.${adb_archive_name//.ab/}.tar"
    fi
}

# file_rotate()
#----------------------------
# DESC: Increment given file name if file exist.
# ARGS: $1 (required) : file name.
# ARGS: $2 (required) : workdir.
# OUTS: Update var with new file name.
function file_rotate() {
       
    # Check
    if [[ $# -lt 2 ]]; then
        script_exit 'Missing required argument to file_rotate()!' 2
    fi
    
    # Local     
    local __file=$1
    local file=${!1}
    local file_pattern=$file
    local basedir=$2
    local i=0
    local extension=${file##*.}

    while test -f "$basedir/$file"; do
        [[ "."$extension != "$file" ]] && \
            file="${file_pattern%.*}_$i.$extension" || file=$file_pattern"_"$i
        i=$((i+1))
    done 
    
    # Update var with new file name
    eval $__file="'$file'"
}

# adb_pull_list()
#----------------------------
# DESC: Catch list of file from pipe and process them for copy with adb pull.
# ARGS: None
# OUTS: None
function adb_pull_list() {

    # Get input lines
    while IFS= read -r line; do
    
        filename=$(basename "$line")
        #filename_path=${line/"$SOURCE_IMG"/}
        new_filename=${line/"$SOURCE_IMG"/"$LATEST_IMG"}
        #"$LATEST_IMG/$filename_path"
        
        echo $filename >> "$DEST_TODAY_IMG/$BCK_IMG_TEMP_FILE"
        
        if ! test -f "$new_filename" ; then
            pretty_print "[COPY]: $line" $fg_cyan
            echo "$line" >> "$DEST_TODAY_IMG/$BCK_IMG_COPIED_FILE"
            echo -en "$fg_cyan"
            adb pull -a "$line" "$new_filename"
        else
            echo "$line" >> "$DEST_TODAY_IMG/$BCK_IMG_SKIPED_FILE"
            pretty_print "[SKIP]: $line" $fg_yellow
        fi       
       
    done

}

# backup_images()
#----------------------------
# DESC: Backup images repertory with incremental behavior: keep Latest dir as
#       mirror state of given photos directory and backup old pics in
#       incremental dir.
# ARGS: $1 (required): Source directory.
#       $2 (required): Today directory.
#       $3 (required): Latest images directory.
# OUTS: None
function backup_images() {

    # Check
    if [[ $# -lt 3 ]]; then
        script_exit 'Missing required argument to backup_images()!' 2
    fi

    # Init 
    SOURCE_IMG=$1
    DEST_TODAY_IMG=$2
    LATEST_IMG=$3
    
    # Create directory
    mkdir -p $DEST_TODAY_IMG
    mkdir -p $LATEST_IMG
    
    # Files rotate
    file_rotate BCK_IMG_COPIED_FILE  "$DEST_TODAY_IMG"
    file_rotate BCK_IMG_SKIPED_FILE  "$DEST_TODAY_IMG"
    file_rotate BCK_IMG_REMOVED_FILE "$DEST_TODAY_IMG"
    
    # Create sub-folder if exist in source
    #list_folder=$(adb shell find "$SOURCE_IMG" -mindepth 1 -maxdepth 1 -type d) 
    #for folder in $list_folder; do
    adb shell find "$SOURCE_IMG" -mindepth 1 -maxdepth 1 -type d -print0 | \
        while IFS= read -r -d '' folder; do
        #echo "$LATEST_IMG/$(basename $folder)"
        mkdir -p "$LATEST_IMG/$(basename $folder)"        
    done

    # List and copy images if not allready present in Latest directory
    #adb shell find "$SOURCE_IMG" \
    #    -iname "*.jpg" \
    #    | tr -d '\015' | adb_pull_list "$LATEST_IMG" "$DEST_TODAY_IMG"
    adb shell find "$SOURCE_IMG" \
        -iname "*.jpg"  -o \
        -iname "*.png"  -o \
        -iname "*.jpeg" -o \
        -iname "*.gif"  -o \
        -iname "*.mp4" \
        | tr -d '\015' | adb_pull_list "$LATEST_IMG" "$DEST_TODAY_IMG"    
    
    # Move old photos in today directory if not present
    find $LATEST_IMG -type f -print0 | while IFS= read -r -d '' file; do                
        file_name=$(basename "$file")
        if ! grep -Fq "$file_name" "$DEST_TODAY_IMG/$BCK_IMG_TEMP_FILE"; then
            
            # Change from Latest to Today dir for the target file
            new_file_path=${file/"$LATEST_IMG"/"$DEST_TODAY_IMG"}
            
            # Create tree folder if needed
            parent_folders="$(dirname "$file")"
            parent_folders=${parent_folders/"$LATEST_IMG"/"$DEST_TODAY_IMG"}
            mkdir -p "$parent_folders"
            
            # Print
            echo "$file" >> "$DEST_TODAY_IMG/$BCK_IMG_REMOVED_FILE"
            pretty_print "[REMOVED]: $file" $fg_yellow
            
            # Move the files to today dir
            mv "$file" "$new_file_path"
        fi
    done
    
    # Delete temp file
    #rm "$DEST_TODAY_IMG/.temp_files.txt"

}

# is_space_available()
#----------------------------
# DESC: Compare the size of files to copy and space available.
# ARGS: $1 (required): path to remote destination folder (from android).
#       $2 (required): path to the local folder to copy. 
# OUTS: None
function is_space_available() {

    # Check
    if [[ $# -lt 2 ]]; then
        script_exit 'Missing required argument to is_space_available()!' 2
    fi
    
    # local
    local dest_folder=$1
    local source_folder=$2
    local space_available=0
    local size_to_copy=0
    
    space_available=$(adb shell df "$dest_folder" | tail -1 | awk '{print $4}')
    size_to_copy=$(du -s "$source_folder" | awk '{print $1}')
    
    if [[ $space_available -lt $size_to_copy ]];then
        # 1 = false
        return 1 
    else
        # 0 = true
        return 0
    fi

}

# restore_files()
#----------------------------
# DESC: Restore files.
# ARGS: $1 (required): path to the local folder to copy. 
#       $2 (required): path to remote destination folder (from android).
# OUTS: None
function restore_files() {

    # Check
    if [[ $# -lt 2 ]]; then
        script_exit 'Missing required argument to is_space_available()!' 2
    fi
    
    # local
    local dest_folder=$2
    local source_folder=$1
    local basename_dest=$(basename $dest_folder)
    local dest_media="$dest_folder"
    
    # Check source folder
    if [[ ! "$(ls -A "$source_folder")" ]];then
        pretty_print "$source_folder is empty, abord !" $fg_red$ta_bold
        return 0
    fi
    
    # Check target media instead of target folder
    [[ $dest_folder == "$PATH_INTERNAL_MEM"* ]] \
        && dest_media="$PATH_INTERNAL_MEM"
    
    # Check space
    pretty_print " => Check available space on device:" $fg_cyan "no_line"
    if is_space_available $dest_media $source_folder ; then
    
        pretty_print " OK on internal storage." $fg_cyan
        
        # Copy files
        pretty_print " => Copy files to $dest_folder" $fg_cyan
        adb shell mkdir -p $dest_folder
        echo -en "$fg_blue"
        adb push "$source_folder"/* "$dest_folder/"
    else
        
        pretty_print " not enought on internal storage !" $fg_yellow$ta_bold
        
        # Detect if sd card exist and check space ont it
        pretty_print " => Check available space on SDCARD if available." \
            $fg_cyan 
        pattern='[[:alnum:]][[:alnum:]][[:alnum:]][[:alnum:]]'
        pattern+='-[[:alnum:]][[:alnum:]][[:alnum:]][[:alnum:]]'
        sdcard_id=$(adb shell ls storage | grep $pattern || true)
        if [[ "$sdcard_id" != "" ]] \
            && is_space_available "/storage/$sdcard_id" $source_folder; then
            
            pretty_print " => SDCARD detected: $sdcard_id" $fg_cyan
          
            # Switch destination folder to sd card
            dest_folder=${dest_folder/$PATH_INTERNAL_MEM/"/storage/$sdcard_id"}
            
            # Copy files
            adb shell mkdir -p $dest_folder
            pretty_print " => Copy files to $dest_folder" $fg_cyan
            echo -en "$fg_blue"
            adb push "$source_folder"/* "$dest_folder/"
        else            
            pretty_print "No space avalaible to copy $basename_dest !" \
                $fg_red$ta_bold
            pretty_print "Please make space or add " $fg_red$ta_bold "no_line"
            pretty_print "an SDCARD for additionnel storage" $fg_red$ta_bold
        fi
    fi

}

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
