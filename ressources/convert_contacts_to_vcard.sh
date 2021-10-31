#!/usr/bin/env bash

# Copyright (C) 2012-2020, Stéphane PAKULA, Stachre
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>,
# or write to the Free Software Foundation, Inc., 51 Franklin Street, 
# Fifth Floor, Boston, MA  02110-1301, USA.
#

###############################################################################
#                                                                             #
#                         CONVERT_CONTACTS_TO_VCARD.SH                        #
#                                                                             #
###############################################################################

#-----------------------------------------------------------------------------#
#     Author(s): Stéphane PAKULA, Stachre
#     From the original script dump-contacts2db.sh by Stachre
#     (https://github.com/stachre/dump-contacts2db)
#     Version: 1.0
#     Date: 12/10/2020
#     Last Modif. Date: 19/10/2020
#     Description:    Export contacts.db (sqlite) from android phone to VCARD 
#                  file.
#
#     Dependencies:  perl; base64; sqlite3 / libsqlite3-dev
#-----------------------------------------------------------------------------#


###############################################################################
#     VCARD MODEL
###############################################################################

# Source: https://en.wikipedia.org/wiki/VCard
#
#                                 *** VCARD V3 ***
# BEGIN:VCARD
# VERSION:3.0
# N:Gump;Forrest;;Mr.;
# FN:Forrest Gump
# ORG:Bubba Gump Shrimp Co.
# TITLE:Shrimp Man
# PHOTO;VALUE=URI;TYPE=GIF:http://www.example.com/dir_photos/my_photo.gif
# TEL;TYPE=WORK,VOICE:(111) 555-1212
# TEL;TYPE=HOME,VOICE:(404) 555-1212
# ADR;TYPE=WORK,PREF:;;100 Waters Edge;Baytown;LA;30314;United States of 
#America
# LABEL;TYPE=WORK,PREF:100 Waters Edge\nBaytown\, LA 30314\nUnited States of 
#America
# ADR;TYPE=HOME:;;42 Plantation St.;Baytown;LA;30314;United States of America
# LABEL;TYPE=HOME:42 Plantation St.\nBaytown\, LA 30314\nUnited States of 
#America
# EMAIL:forrestgump@example.com
# REV:2008-04-24T19:52:43Z
# END:VCARD
#
#                                 *** VCARD V4 ***
# BEGIN:VCARD
# VERSION:4.0
# N:Gump;Forrest;;Mr.;
# FN:Forrest Gump
# ORG:Bubba Gump Shrimp Co.
# TITLE:Shrimp Man
# PHOTO;MEDIATYPE=image/gif:http://www.example.com/dir_photos/my_photo.gif
# TEL;TYPE=work,voice;VALUE=uri:tel:+1-111-555-1212
# TEL;TYPE=home,voice;VALUE=uri:tel:+1-404-555-1212
# ADR;TYPE=WORK;PREF=1;LABEL="100 Waters Edge\nBaytown\, LA 30314\nUnited 
#States of America":;;100 Waters Edge;Baytown;LA;30314;United States of America
# ADR;TYPE=HOME;LABEL="42 Plantation St.\nBaytown\, LA 30314\nUnited States of 
#America":;;42 Plantation St.;Baytown;LA;30314;United States of America
# EMAIL:forrestgump@example.com
# REV:20080424T195243Z
# x-qq:21588891
# END:VCARD
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
    MODE=1 # 1: VCARD V3 (default), 2: VCARD V4
    MODE_CHOICE="null"
    SCRIPT_NAME="CONVERT_CONTACTS_TO_VCARD.sh"
    JOUR=`date +%Y_%m_%d`   

# File
#----------------------------
    FILE_SQLITE=""
    FILE_VCARD_OUTPUT=""
    
# File
#----------------------------
    PATH_FILE_DIR=""
    PATH_FILE_CSV=""
    
# VCARD V3
#----------------------------
    DEFAULT_VCARD_PHOTO_HEAD_V3="PHOTO;ENCODING=BASE64;JPEG:"
    VCARD_HEADER_V3="BEGIN:VCARD"$'\n'"VERSION:3.0"$'\n'
    VCARD_PHONE_FIELD_2_V3=":"

# VCARD V4
#----------------------------
    DEFAULT_VCARD_PHOTO_HEAD_V4="PHOTO;ENCODING=BASE64;MEDIATYPE=image/jpeg:"
    VCARD_HEADER_V4="BEGIN:VCARD"$'\n'"VERSION:4.0"$'\n'
    VCARD_PHONE_FIELD_2_V4=";VALUE=uri:tel:"

# VCARD COMMON
#----------------------------
    DEFAULT_VCARD_PHOTO_HEAD=""
    NEWLINE_QUOTED=`echo -e "'\n'"`
    MS_NEWLINE_QUOTED=`echo -e "'\r\n'"`
    VCARD_HEADER=""
    VCARD_PHONE_FIELD_1="TEL;TYPE="
    VCARD_PHONE_FIELD_2=""


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
Dumps contacts from an Android contacts2.db to stdout in vCard format

Usage: convert_contacts_to_vcard.sh [OPTIONS] <sqlite_file.db> 

Options:
     -h|--help                                  Displays this help
     -v|--version                               Displays version
     -V|--verbose                               Displays verbose output
    -nc|--no-colour                             Disables colour output
     -o|--output=FILE                           create a xml file
     -m|--mode=[V3|V4]                          Select mode (VCARD version)
     
Dependencies:  perl; base64; sqlite3 / libsqlite3-dev 
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
            V3)
                MODE=1
                ;;
            V4)
                MODE=2
                ;;
            *)  # Wrong mode 
                script_exit "ERROR: Wrong mode: $mode_param" 4
                ;;
        esac
#        CONFIG_FILE=$mode_param
    fi
    
    # Init var
    #---------------------------
    declare -i cur_contact_id=0
    declare -i prev_contact_id=0

    # Default VCARD version
    DEFAULT_VCARD_PHOTO_HEAD=$DEFAULT_VCARD_PHOTO_HEAD_V3
    VCARD_HEADER=$VCARD_HEADER_V3
    VCARD_PHONE_FIELD_2=$VCARD_PHONE_FIELD_2_V3
    
    # Output
    FILE_VCARD_OUTPUT="${FILE_SQLITE/'.db'/}_$JOUR.vcf"
    
    # Given file output    
    if [[ -n ${output_file-} ]]; then
        FILE_VCARD_OUTPUT=$output_file_param
        
        # Check if empty
        [[ ! -n $FILE_VCARD_OUTPUT ]] \
            && script_exit "ERROR: empty output name" 6
    fi
    
    # Force .xml file
    [[ ! $FILE_VCARD_OUTPUT == *".vcf"  ]] \
        && FILE_VCARD_OUTPUT="$FILE_VCARD_OUTPUT.vcf"        
        
    # store Internal Field Separator
    IFS_OLD=$IFS

    # Mode Choice
    #---------------------------

    # if mode empty, let choose mode prompt
    if !([[ -n ${mode-} ]]); then
        pretty_print "Veuillez choisir un mode de compatibilité:"
        pretty_print " 1: VCARD V3"
        pretty_print " 2: VCARD V4"
        read -p "Mode: " MODE
        
        # Check input
        if [ -z "${MODE##*[!1-2]*}" ]; then
            script_exit "ERROR: Wrong mode: $MODE" 4
        fi
    fi 
    
    # Init mode
    if [[ $MODE -eq 1 ]]; then # VCARD V3
        DEFAULT_VCARD_PHOTO_HEAD=$DEFAULT_VCARD_PHOTO_HEAD_V3
        VCARD_HEADER=$VCARD_HEADER_V3           
        VCARD_PHONE_FIELD_2=$VCARD_PHONE_FIELD_2_V3

    elif [[ $MODE -eq 2 ]]; then # VCARD V4
        DEFAULT_VCARD_PHOTO_HEAD=$DEFAULT_VCARD_PHOTO_HEAD_V4
        VCARD_HEADER=$VCARD_HEADER_V4
        VCARD_PHONE_FIELD_2=$VCARD_PHONE_FIELD_2_V4
        
    else
        script_exit "ERROR: Wrong mode: $MODE" 4
    fi
    
    # Fetch contact data
    #---------------------------

    # TODO: order by account, with delimiters if possible
    record_set=`sqlite3 $FILE_SQLITE \
                "SELECT 
                    raw_contacts._id, 
                    raw_contacts.display_name, 
                    raw_contacts.display_name_alt, 
                    mimetypes.mimetype, 
                    REPLACE(
                        REPLACE(data.data1, $MS_NEWLINE_QUOTED, '\n'), 
                        $NEWLINE_QUOTED, '\n'), 
                    data.data2, 
                    REPLACE(
                        REPLACE(data.data4, $MS_NEWLINE_QUOTED, '\n'), 
                        $NEWLINE_QUOTED, '\n'), 
                    data.data5, 
                    data.data6, 
                    data.data7, 
                    data.data8, 
                    data.data9, 
                    data.data10, 
                    quote(data.data15) 
                FROM 
                    raw_contacts, 
                    data, 
                    mimetypes 
                WHERE 
                    raw_contacts.deleted = 0 
                    AND raw_contacts._id = data.raw_contact_id 
                    AND data.mimetype_id = mimetypes._id 
                ORDER BY 
                    raw_contacts._id, mimetypes._id, data.data2"`
   
    # modify Internal Field Separator for parsing rows from recordset
    IFS=`echo -e "\n\r"`

    # Delete existing file
    #---------------------------  
    if (test -f $FILE_VCARD_OUTPUT); then
        rm $FILE_VCARD_OUTPUT
    fi

    # Traitement des données
    #---------------------------
    
    # Init 
    # iterate through contacts data rows
    # use "for" instead of piped "while" to preserve var values post-loop
    for row in $record_set
    do
        # modify Internal Field Separator for parsing cols from row
        IFS="|"

        i=0

        for col in $row
        do
            i=$[i+1]

            # contact data fields stored in generic value columns
            # schema determined by "mimetype", which varies by row
            case $i in
                1)    # raw_contacts._id
                    cur_contact_id=$col
                    ;;

                2)    # raw_contacts.display_name
                    cur_display_name=$col
                    ;;

                3)  # raw_contacts.display_name_alt
                    # replace comma-space with semicolon
                    cur_display_name_alt=${col/, /\;}
                    ;;

                4)    # mimetypes.mimetype
                    cur_mimetype=$col
                    ;;

                5)    # data.data1
                    cur_data1=$col
                    ;;

                6)    # data.data2
                    cur_data2=$col
                    ;;

                7)    # data.data4
                    cur_data4=$col
                    ;;

                8)    # data.data5
                    cur_data5=$col
                    ;;

                9)    # data.data6
                    cur_data6=$col
                    ;;

                10)    # data.data7
                    cur_data7=$col
                    ;;

                11)    # data.data8
                    cur_data8=$col
                    ;;

                12)    # data.data9
                    cur_data9=$col
                    ;;

                13)    # data.data10
                    cur_data10=$col
                    ;;

                14)    # data.data15
                    cur_data15=$col
                    ;;

            esac
        done

        # new contact
        if [ $prev_contact_id -ne $cur_contact_id ]; then
            if [ $prev_contact_id -ne 0 ]; then
                # echo current vcard prior to reinitializing variables
                
                # some contacts apps don't have IM fields; 
                # add to top of NOTE: field
                if [ ${#cur_vcard_im_note} -ne 0 ]
                    then cur_vcard_note=$cur_vcard_im_note"\n"$cur_vcard_note
                fi

                # generate and echo vcard
                if [ ${#cur_vcard_note} -ne 0 ]
                    then cur_vcard_note="NOTE:"$cur_vcard_note$'\n'
                fi
                cur_vcard+=$cur_vcard_nick$cur_vcard_org
                cur_vcard+=$cur_vcard_title$cur_vcard_tel
                cur_vcard+=$cur_vcard_adr$cur_vcard_email
                cur_vcard+=$cur_vcard_url$cur_vcard_note
                cur_vcard+=$cur_vcard_photo$cur_vcard_im                
                cur_vcard+="END:VCARD"
                
                # Write file
                echo $cur_vcard >> $FILE_VCARD_OUTPUT
            fi

            # init new vcard
            cur_vcard=$VCARD_HEADER
            cur_vcard=$cur_vcard"N:"$cur_display_name_alt$'\n'
            cur_vcard=$cur_vcard"FN:"$cur_display_name$'\n'
            cur_vcard_nick=""
            cur_vcard_org=""
            cur_vcard_title=""
            cur_vcard_tel=""
            cur_vcard_adr=""
            cur_vcard_email=""
            cur_vcard_url=""
            cur_vcard_im=""
            cur_vcard_im_note=""
            cur_vcard_note=""
            cur_vcard_photo=""
        fi

        # add current row to current vcard
        # again, "mimetype" determines schema on a row-by-row basis
        # TODO: handle following types
        #   * (6) vnd.android.cursor.item/sip_address
        #   * (7) vnd.android.cursor.item/identity 
        #                           (not exported by Android 4.1 Jelly Bean) 
        #   * (13) vnd.android.cursor.item/group_membership 
        #                           (not exported by Android 4.1 Jelly Bean) 
        #   * (14) vnd.com.google.cursor.item/contact_misc 
        #                           (not exported by Android 4.1 Jelly Bean) 
        case $cur_mimetype in
            vnd.android.cursor.item/nickname)
                if [ ${#cur_data1} -ne 0 ]
                    then cur_vcard_nick="NICKNAME:"$cur_data1$'\n'
                fi
                ;;

            vnd.android.cursor.item/organization)
                if [ ${#cur_data1} -ne 0 ]
                    then cur_vcard_org=$cur_vcard_org"ORG:"$cur_data1$'\n'
                fi
                
                if [ ${#cur_data4} -ne 0 ]
                    then cur_vcard_title="TITLE:"$cur_data4$'\n'
                fi
                ;;

            vnd.android.cursor.item/phone_v2)
                case $cur_data2 in
                    1)
                        cur_vcard_tel_type="HOME,VOICE"
                        ;;

                    2)
                        cur_vcard_tel_type="CELL,VOICE,PREF"
                        ;;

                    3)
                        cur_vcard_tel_type="WORK,VOICE"
                        ;;

                    4)
                        cur_vcard_tel_type="WORK,FAX"
                        ;;

                    5)
                        cur_vcard_tel_type="HOME,FAX"
                        ;;

                    6)
                        cur_vcard_tel_type="PAGER"
                        ;;

                    7)
                        cur_vcard_tel_type="OTHER"
                        ;;

                    8)
                        cur_vcard_tel_type="CUSTOM"
                        ;;

                    9)
                        cur_vcard_tel_type="CAR,VOICE"
                        ;;
                esac
                                
                # VCARD V4 required lowercase type
                [[ $MODE -eq 2 ]] && \
                    cur_vcard_tel_type=$(echo $cur_vcard_tel_type \
                                        | tr '[:upper:]' '[:lower:]')
                
                cur_vcard_tel+="$VCARD_PHONE_FIELD_1"$cur_vcard_tel_type
                cur_vcard_tel+="$VCARD_PHONE_FIELD_2"$cur_data1$'\n'
                ;;

            vnd.android.cursor.item/postal-address_v2)
                case $cur_data2 in
                    1)
                        cur_vcard_adr_type="HOME"
                        ;;

                    2)
                        cur_vcard_adr_type="WORK"
                        ;;
                esac

                # ignore addresses that contain only USA (MS Exchange)
                # TODO: validate general address pattern instead
                if [ $cur_data1 != "United States of America" ]; then
                    cur_vcard_adr+="ADR;TYPE="$cur_vcard_adr_type
                    
                    # VCARD V4
                    [[ $MODE -eq 2 ]] \
                        && cur_vcard_adr+=";LABEL=\"" \
                        && cur_vcard_adr+=$cur_vcard_adr_type"\""
                        
                    # VCARD V3 an V4    
                    cur_vcard_adr+=":;;"$cur_data4
                    cur_vcard_adr+=";"$cur_data7
                    cur_vcard_adr+=";"$cur_data8
                    cur_vcard_adr+=";"$cur_data9
                    cur_vcard_adr+=";"$cur_data10$'\n'
                    
                    # VCARD V3
                    [[ $MODE -eq 1 ]] && \
                        cur_vcard_adr+="LABEL;TYPE="$cur_vcard_adr_type \
                        && cur_vcard_adr+=":"$cur_data1$'\n'                    
                fi
                ;;

            vnd.android.cursor.item/email_v2)
                cur_vcard_email=$cur_vcard_email"EMAIL:"$cur_data1$'\n'
                ;;

            vnd.android.cursor.item/website)
                cur_vcard_url=$cur_vcard_url"URL:"$cur_data1$'\n'
                ;;

            vnd.android.cursor.item/im)
                 # handle entire string within each case to avoid unhandled cases
                 case $cur_data5 in
                    -1)
                        cur_vcard_im_note+="IM-Custom-"$cur_data6
                        cur_vcard_im_note+=": "$cur_data1"\n"
                        ;;

                    0)
                        cur_vcard_im+="X-AIM:"$cur_data1$'\n'
                        cur_vcard_im_note+="IM-AIM: "$cur_data1"\n"
                        ;;

                    1)
                        cur_vcard_im+="X-MSN:"$cur_data1$'\n'
                        cur_vcard_im_note+="IM-MSN: "$cur_data1"\n"
                        ;;

                    2)
                        cur_vcard_im+="X-YAHOO:"$cur_data1$'\n'
                        cur_vcard_im_note+="IM-Yahoo: "$cur_data1"\n"
                        ;;

                    3)
                        cur_vcard_im+="X-SKYPE-USERNAME:"$cur_data1$'\n'
                        cur_vcard_im_note+="IM-Skype: "$cur_data1"\n"
                        ;;

                    4)
                        cur_vcard_im+="X-QQ:"$cur_data1$'\n'
                        cur_vcard_im_note+="IM-QQ: "$cur_data1"\n"
                        ;;

                    5)
                        cur_vcard_im+="X-GOOGLE-TALK:"$cur_data1$'\n'
                        cur_vcard_im_note+="IM-Google-Talk: "$cur_data1"\n"
                        ;;

                    6)
                        cur_vcard_im+="X-ICQ:"$cur_data1$'\n'
                        cur_vcard_im_note+="IM-ICQ: "$cur_data1"\n"
                        ;;

                    7)
                        cur_vcard_im+="X-JABBER:"$cur_data1$'\n'
                        cur_vcard_im_note+="IM-Jabber: "$cur_data1"\n"
                        ;;

                    *)
                        cur_vcard_im_note+="IM: "$cur_data1"\n"
                        ;;
                esac
                ;;

            vnd.android.cursor.item/photo)
                if [ $cur_data15 != "NULL" ]; then
                    #  Remove the prefix "X'" and suffix "'" 
                    # from the sqlite3 quote(BLOB) hex output
                    photo=`echo $cur_data15 | sed -e "s/^X'//" -e "s/'$//"`
                
                    # Convert the hex to base64
                    # TODO: optimize
                    photo=`echo $photo \
                            | perl -ne 's/([0-9a-f]{2})/print chr hex $1/gie' \
                            | base64 --wrap=0`       
                    
                    # Justify photo print
                    photo_text_vcard="${DEFAULT_VCARD_PHOTO_HEAD:0:1}"
                    photo_text_vcard+=$(echo $DEFAULT_VCARD_PHOTO_HEAD$photo \
                                        | sed -r 's/^.{1}//' \
                                        | sed 's/.\{73\}/& /g' )
                    photo_text_vcard="$(echo $photo_text_vcard | fold -w74)"
                    cur_vcard_photo=$cur_vcard_photo$photo_text_vcard$'\n'
                    
                    # TODO: line wrapping; 
                    #       Android import doesn't like base64's wrapping
                    
                    # For testing
                    #echo $cur_data15 > "images/$cur_display_name.txt"
                    #echo $cur_data15 \
                    #    | perl -ne 's/([0-9a-f]{2})/print chr hex $1/gie' \
                    #    > "images/$cur_display_name.jpg"
                fi
                ;;

            vnd.android.cursor.item/note)
                # "NOTE:" and trailing \n appended when vCard is finished and echoed
                if [ ${#cur_vcard_note} -ne 0 ]
                    then cur_vcard_note=$cur_vcard_note"\n\n"$cur_data1
                    else cur_vcard_note=$cur_data1
                fi
                ;;
        esac    

        prev_contact_id=$cur_contact_id

        # reset Internal Field Separator for parent loop
        IFS=`echo -e "\n\r"`
    done

    #  set Internal Field Separator to other-than-newline 
    # prior to echoing final vcard
    IFS="|"

    # some contacts apps don't have IM fields; add to top of NOTE: field
    if [ ${#cur_vcard_im_note} -ne 0 ]
        then cur_vcard_note=$cur_vcard_im_note"\n"$cur_vcard_note
    fi

    # generate and echo vcard
    if [ ${#cur_vcard_note} -ne 0 ]
        then cur_vcard_note="NOTE:"$cur_vcard_note$'\n'
    fi
    cur_vcard+=$cur_vcard_nick$cur_vcard_org$cur_vcard_title$cur_vcard_tel
    cur_vcard+=$cur_vcard_adr$cur_vcard_email$cur_vcard_url$cur_vcard_note
    cur_vcard+=$cur_vcard_photo$cur_vcard_im
    cur_vcard=$cur_vcard"END:VCARD"
    
    # Write file
    echo $cur_vcard >> $FILE_VCARD_OUTPUT  
    
            
    # Clean
    #---------------------------
    
    # restore original Internal Field Separator
    IFS=$IFS_OLD
    
}

# START
#----------------------------
main "$@"

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
