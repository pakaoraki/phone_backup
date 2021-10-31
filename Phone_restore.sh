#!/usr/bin/env bash

# Phone backup/restore scripts
# Copyright (C) 2021 Pakaoraki <pakaoraki@gmx.com>
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
#                               PHONE_RESTORE.SH                              #
#                                                                             #
###############################################################################

#-----------------------------------------------------------------------------#
#     Author(s): Pakaoraki
#     Version: 1.0
#     Date: 08/10/2020
#     Last Modif. Date: 24/08/2021
#
#     Description: -Restore data from a linux folder PC to an android phone
#                   using ADB tools.
#                  -Restore contacts, SMS/MMS, phone calls logs databases and 
#                   files (Photos, Downloads, Documents, Ringtones,
#                   Notifications).
#                  -Restore Apps APK/data.
#
#     Note: -Need android 10 or+ but older version should work. 
#           -Tested on Lineage 17.1 : OK.
#           -Check Phone_backup.sh --help/-h for use.
#
#     Prerequisite: -Android phone (Android 10 or+).
#                   -ADB tools 
#                    (debian/ubuntu: sudo apt install adb android-tools-adb)
#                   -Abe (abe-all.jar) to unpack android backup .ab encrypted 
#                     files (included in folder).
#                     https://github.com/nelenkov/android-backup-extractor
#                   -perl, base64, sqlite3, libsqlite3-dev, java (>=7)
#                    (debian/ubuntu: sudo apt install base64, sqlite3,
#                     libsqlite3-dev)
#                   -aapt2 (Android Asset Packaging Tool)
#                    (https://developer.android.com/studio/command-line/aapt2).
#
#-----------------------------------------------------------------------------#

###############################################################################
#     INIT & IMPORT
###############################################################################
    
# A better class of script...
#----------------------------
    # Enable xtrace if the DEBUG environment variable is set
    if [[ ${DEBUG-} =~ ^1|yes|true$ ]]; then
        set -o xtrace       # Trace the execution of the script (debug)
    fi

    # Only enable these shell behaviours if we're not being sourced
    # Approach via: https://stackoverflow.com/a/28776166/8787985
    if ! (return 0 2> /dev/null); then
        # A better class of script...
        set -o errexit      # Exit on most errors (see the manual)
        set -o nounset      # Disallow expansion of unset variables
        set -o pipefail     # Use last non-zero exit code in a pipeline
    fi

    # Enable errtrace or the error trap handler will not work as expected
    set -o errtrace         # Ensure the error trap handler is inherited
    
# Import sources
#---------------------------- 
    # shellcheck source=source.sh
    source "$(dirname "${BASH_SOURCE[0]}")/source.sh"


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
Usage:
     -h|--help                  Displays this help
     -l|--latest                Select latest backup detected
     -v|--version               Displays version
    -ns|--no-system-apps        Don't restore system apps
    -fs|--force-system-apps     Force restore system apps
    -nc|--no-colour             Disables colour output
EOF
}

# parse_params()
#----------------------------
# DESC: Parameter parser
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: Variables indicating command-line parameters and options
function parse_params() {
    local param
    while [[ $# -gt 0 ]]; do
        param="$1"
        shift
        case $param in
            -h|--help)
                script_usage
                exit 0
                ;;
            -l|--latest)
                latest=true
                ;; 
            -v|--version)
                echo "Version $VERSION"
                exit 0;
                ;;        
            -V|--verbose)
                verbose=true
                ;;
            -fs|--force-system-apps)
                force_system_apps=true
                ;;
            -ns|--no-system-apps)
                no_system_apps=true
                ;;
            -nc|--no-colour)
                no_colour=true
                ;;
            -cr|--cron)
                cron=true
                ;;
            *)
                script_exit "Invalid parameter was provided: $param" 1
                ;;
        esac
    done
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
    cron_init
    colour_init
    #lock_init system
    
    # Tilte
    #----------------------------
    
    # http://patorjk.com/software/taag/
    # Style :"Stop"    
    pretty_print " 
 ______  _                          ______                                  
(_____ \| |                        (_____ \            _                    
 _____) ) | _   ___  ____   ____    _____) ) ____  ___| |_  ___   ____ ____ 
|  ____/| || \ / _ \|  _ \ / _  )  (_____ ( / _  )/___)  _)/ _ \ / ___) _  )
| |     | | | | |_| | | | ( (/ /         | ( (/ /|___ | |_| |_| | |  ( (/ / 
|_|     |_| |_|\___/|_| |_|\____)        |_|\____|___/ \___)___/|_|   \____)
 ------------------- Phone Backup - v$VERSION ----------------------------
"


    # Init Variables
    #----------------------------
    
    # Check and auto-install dependencies
    check_dependencies
    
    # Get file conf if exist
    if test -f "$CONFIG_FILE"; then
        source "$CONFIG_FILE"
    fi
    
    # Path
    PATH_RESTORE_FOLDER="$PATH_BACKUP_FOLDER/RESTORE"
    #PATH_BACKUP_FOLDER="/home/$USER/$FOLDER_BACKUP_NAME"
    PATH_PHOTO_LATEST="$PATH_BACKUP_FOLDER/$FOLDER_BACKUP_PHOTOS/Latest"
    PATH_PHOTO_TODAY="$PATH_BACKUP_FOLDER/$FOLDER_BACKUP_PHOTOS/$JOUR"    
    

    # Get Backups list
    #----------------------------    
    LIST_BACKUP=()
    for folder in $(ls -d $PATH_BACKUP_FOLDER/*); do                
        if test -f $folder/.state; then
            [[ $(cat $folder/.state) == "SUCCESS" ]] \
                && LIST_BACKUP+=( "$folder" ) 
        fi        
    done
    
    # Sorted by date
    IFS_BCK=$IFS
    IFS=$'\n' LIST_BACKUP=($(sort <<<"${LIST_BACKUP[*]}"))
    IFS=$IFS_BCK

    # Get the latest
    LATEST_BCK=${LIST_BACKUP[-1]}


    # List Backups / Latest
    #----------------------------
    if [[ -n ${latest-} ]]; then
        BCK_TO_RESTORE=$LATEST_BCK  
    else
        pretty_print "\
#--------------------------------- BACKUPS ----------------------------------#"\
    
        # On affiche la liste des backups valides disponibles
        local i=1    
        pretty_print " "
        pretty_print "| "                           $fg_green $ta_none
        pretty_print "LIST OF VALID BACKUP"         $fg_cyan$ta_bold
        pretty_print "+-------------------"         $fg_green
        if [[ ${#LIST_BACKUP[@]} -ne 0 ]]; then 
                for folder in ${LIST_BACKUP[@]};
                do 
                    local date=$(basename $folder \
                        | awk -v FS=_ -v OFS=/ '{print $3,$2,$1}' )
                    pretty_print " => Backup n°$i"  $fg_cyan$ta_bold "no_line"
                    [[ "$folder" == "$LATEST_BCK" ]] \
                        && pretty_print " (Latest)" $fg_cyan$ta_bold \
                        || pretty_print ""
                    pretty_print "    * Folder: $folder"
                    pretty_print "    * Date: $date"
                    pretty_print " "
                    i=$((i+1))
                done
        fi

        pretty_print " "
        pretty_print "Choose a backup to restore... " $fg_yellow$ta_bold
        read -p "Selection (1-$((i-1))):" choice
        while [ $choice -lt 1 ] || [ $choice -gt $((i-1)) ]; do
            pretty_print "Wrong selection! Please select a id between 1 and "$((i-1)) $fg_red$ta_bold
            read -p "Selection (1-$((i-1))):" choice
        done
        
        # Set backup to restore
        BCK_TO_RESTORE=${LIST_BACKUP[$((choice-1))]}
    fi
    
    # Print restore summary
    #----------------------------
    
    # Get date from folder name
    DATE_BCK_FOLDER=$(basename $BCK_TO_RESTORE \
                    | awk -v FS=_ -v OFS=_ '{print $1,$2,$3}' )
    DATE_BCK_TO_RESTORE=$(basename $BCK_TO_RESTORE \
                    | awk -v FS=_ -v OFS=/ '{print $3,$2,$1}' )
    # Print
    pretty_print " "
    pretty_print "| "                           $fg_green $ta_none
    pretty_print "BACKUP TO RESTORE"            $fg_cyan$ta_bold
    pretty_print "+-------------------"         $fg_green
#    pretty_print " * Folder:        "           $fg_yellow$ta_bold "no_line"
#    pretty_print "$BCK_TO_RESTORE"              $fg_green$ta_bold
#    pretty_print " * Date:          "           $fg_yellow$ta_bold "no_line"
#    pretty_print "$DATE_BCK_TO_RESTORE"         $fg_green$ta_bold
    
    # Get source device from folder name
    SRV_DEVICE="$(basename $BCK_TO_RESTORE | awk -v FS=_  '{print $4}')"
    
    # Init Path: Backup to restore
    contacts_logs_path="$BCK_TO_RESTORE/$FOLDER_CONTACTS_NAME/databases"
    mms_sms_path="$BCK_TO_RESTORE/$FOLDER_MMS_SMS_NAME/databases"
    mms_sms_data_path="$BCK_TO_RESTORE/$FOLDER_MMS_SMS_NAME/app_parts"
    ringtones_path="$BCK_TO_RESTORE/$FOLDER_RINGTONES_NAME"
    apps_path="$BCK_TO_RESTORE/$FOLDER_APP_NAME"
    apps_apk_path="$apps_path/APK"
    photos_path="$PATH_BACKUP_FOLDER/$FOLDER_BACKUP_PHOTOS/$DATE_BCK_FOLDER"
    photos_per_back_path="$BCK_TO_RESTORE/$FOLDER_PHOTOS_NAME"
    music_path="$BCK_TO_RESTORE/$FOLDER_MUSIC_NAME"
    downloads_path="$BCK_TO_RESTORE/$FOLDER_FILES_NAME/Download"
    documents_path="$BCK_TO_RESTORE/$FOLDER_FILES_NAME/Documents"
    
    # Start printing Summary
    print_file_name=";$fg_yellow$ta_bold- [ Folder      ]:"
    print_file_name+=";$fg_green$ta_bold"
    print_file_name+="$BCK_TO_RESTORE"
    print_file_name+="\n;$fg_yellow$ta_bold"
    print_file_name+="- [ Date        ]:"
    print_file_name+=";$fg_green$ta_bold"
    print_file_name+="$DATE_BCK_TO_RESTORE"
    
    # *** Source device ***
    print_file_name+="\n;$fg_yellow$ta_bold" 
    print_file_name+="- [ From Device ]:"
    
    if [[ "$SRV_DEVICE" != "" ]]; then  
        RESTORE_CONTACTS=true    
        print_file_name+=";$fg_green$ta_bold" 
        print_file_name+="$SRV_DEVICE"       
    else
        print_file_name+=";$fg_red$ta_bold"
        print_file_name+="UNKNOWN"
    fi
            
    # *** Check Contacts ***
    print_file_name+="\n;$fg_yellow$ta_bold" 
    print_file_name+="- [ Contacts    ]:"
    if test -f "$contacts_logs_path/contacts2.db" \
        && test -f "$contacts_logs_path/profile.db"; then  
        RESTORE_CONTACTS=true    
        print_file_name+=";$fg_green$ta_bold" 
        print_file_name+="OK"       
    else
        print_file_name+=";$fg_red$ta_bold"
        print_file_name+="MISSING"
    fi
    # --------------------- #
 
    # *** Check Phone call ***
    print_file_name+="\n;$fg_yellow$ta_bold" 
    print_file_name+="- [ Phones call ]:"
    if test -f "$contacts_logs_path/calllog.db"; then   
        RESTORE_CALLLOG=true   
        
        print_file_name+=";$fg_green$ta_bold" 
        print_file_name+="OK" 
    else
        print_file_name+=";$fg_red$ta_bold"
        print_file_name+="MISSING"
    fi
    # --------------------- #
    
    # *** Check MMS/SMS ***
    print_file_name+="\n;$fg_yellow$ta_bold" 
    print_file_name+="- [ MMS/SMS     ]:"
    if test -f "$mms_sms_path/mmssms.db"; then   
        RESTORE_MMS_SMS=true
        print_file_name+=";$fg_green$ta_bold" 
        print_file_name+="OK"
    else 
        print_file_name+=";$fg_red$ta_bold"
        print_file_name+="MISSING"
    fi
    # --------------------- #
    
    # *** Check list Apps ***

    # Get list of apps from APK folder 
    if test -d $apps_apk_path; then
        
        # Find apk from APK folder
        mapfile -d $'\0' LIST_APPS_TO_RESTORE \
            < <(find $apps_apk_path -type f -name "*.apk" -print0)  
      
        # Get the list of Apps Label to print    
        for app in "${LIST_APPS_TO_RESTORE[@]}"; do
            [[ "$LIST_APPS_TO_RESTORE_PRINT" != "" ]] && \
                LIST_APPS_TO_RESTORE_PRINT+=", "
            LIST_APPS_TO_RESTORE_PRINT+=$($AAPT2_CMD dump badging "$app" \
                2> /dev/null \
                | sed -n "s/^application-label:'\(.*\)'/\1/p" \
                || true )        
        done      

    # Legacy Apps backuped
    elif test -d $apps_path; then
        MODE_REST_APPS="LEGACY"

        # Get Apps list
        mapfile -d $'\0' LIST_APPS_TO_RESTORE \
            < <(find $apps_path -type f -name "*.ab" -print0)     
            
        # Get the list of Apps Label to print                     
        for app in "${LIST_APPS_TO_RESTORE[@]}"; do
            [[ "$LIST_APPS_TO_RESTORE_PRINT" != "" ]] && \
                LIST_APPS_TO_RESTORE_PRINT+=", "
            LIST_APPS_TO_RESTORE_PRINT+="$(basename $app)"            
        done                               
        LIST_APPS_TO_RESTORE_PRINT=${LIST_APPS_TO_RESTORE_PRINT//.ab/}
    else
        pretty_print " Impossible to list apps from $apps_apk_path or $apps_path " \
            $fg_yellow$ta_bold
    fi

    # Print the Apps list 
    print_file_name+="\n;$fg_yellow$ta_bold" 
    print_file_name+="- [ Apps        ]:"
    if [[ ${#LIST_APPS_TO_RESTORE[@]} -ne 0 ]]; then
        RESTORE_APPS=true
        
        print_file_name+="$fg_green$ta_bold;" 
        print_file_name+="$LIST_APPS_TO_RESTORE_PRINT"
    else
        print_file_name+=";$fg_red$ta_bold" 
        print_file_name+="NONE"
    fi
    # --------------------- #
    
    # *** Check Photos ***
    print_file_name+="\n;$fg_yellow$ta_bold" 
    print_file_name+="- [ Photos      ]:"
    
    if test -d $photos_path; then
        print_file_name+=";$fg_green$ta_bold" 
        print_file_name+="OK, latest and incremental"  
        RESTORE_PHOTOS=true            
    else
        if test -d $photos_per_back_path \
            && [[ "$(ls -A $photos_per_back_path)" ]]; then
            RESTORE_PHOTOS=true
            MODE_REST_PHOTOS="legacy"
            print_file_name+=";$fg_green$ta_bold" 
            print_file_name+="OK, legacy photo folder (Not latest)" 
        else
            RESTORE_PHOTOS=true
            print_file_name+=";$fg_green$ta_bold" 
            print_file_name+="ONLY Latest" 
        fi
    fi
    # --------------------- #
    
    # *** Check Ringtones *** 
    print_file_name+="\n;$fg_yellow$ta_bold" 
    print_file_name+="- [ Ringtones   ]:"
    if test -d $ringtones_path && [[ "$(ls -A $ringtones_path)" ]]; then
        RESTORE_RINGTONES=true
        
        print_file_name+=";$fg_green$ta_bold" 
        print_file_name+="Files found, OK"  
    else
        print_file_name+=";$fg_red$ta_bold" 
        print_file_name+="EMPTY"  
    fi
    # --------------------- #

    # *** Check Music ***
    print_file_name+="\n;$fg_yellow$ta_bold" 
    print_file_name+="- [ Music       ]:"    
    if test -d $music_path && [[ "$(ls -A $music_path)" ]]; then
        if ! test -f "$music_path/$FILE_MUSIC_BACKUP_NAME"; then
            RESTORE_MUSIC=true
            print_file_name+=";$fg_green$ta_bold" 
            print_file_name+="Files found, OK" 
        else
            print_file_name+=";$fg_yellow$ta_bold" 
            print_file_name+="No music files to restore."
        fi
    else
        print_file_name+=";$fg_red$ta_bold" 
        print_file_name+="EMPTY"  
    fi
    # --------------------- #
        
    # *** Check Downloads ***
    print_file_name+="\n;$fg_yellow$ta_bold" 
    print_file_name+="- [ Downloads   ]:"    
    if test -d $downloads_path && [[ "$(ls -A $downloads_path)" ]]; then
        RESTORE_DOWNLOADS=true
        print_file_name+=";$fg_green$ta_bold" 
        print_file_name+="Files found, OK" 
    else
        print_file_name+=";$fg_red$ta_bold" 
        print_file_name+="EMPTY"  
    fi
    # --------------------- #
    
    # *** Check Documents ***
    print_file_name+="\n;$fg_yellow$ta_bold" 
    print_file_name+="- [ Documents   ]:"   
    if test -d $documents_path && [[ "$(ls -A $documents_path)" ]]; then  
        RESTORE_DOCS=true
        print_file_name+=";$fg_green$ta_bold" 
        print_file_name+="Files found, OK" 
    else
        print_file_name+=";$fg_red$ta_bold" 
        print_file_name+="EMPTY" 
    fi    
    # --------------------- #
    
    # Print summary with column
    echo -en "$print_file_name" | column -t -W 3 -s ';'
    echo -en "$ta_none"
 
            
    # Confirmation
    #----------------------------   
    pretty_print ""  
    message="WARNING: the process will erase all your data on your phone !"
    pretty_print "$message" $fg_yellow$ta_bold 
    pretty_print "Do you want to restore this backup ? (O/n)" $fg_cyan$ta_bold
    read -p "Select :" choice
    
    if [ "$choice" != "${choice#[YyOo]}" ]; then
        pretty_print " => Start restore !" $fg_green$ta_bold 
    else
        pretty_print "Abord !" $fg_red$ta_bold 
        script_exit "" 1    
    fi

    
    # ADB Init
    #----------------------------
    
    # Start ADB server
    init_adb
    
    # Get target device name
    DEVICE_NAME=$(adb shell getprop ro.product.model)
    DEVICE_NAME=${DEVICE_NAME// /-}
    pretty_print " => TARGET DEVICE: " $fg_cyan "no_line"
    pretty_print "$DEVICE_NAME" $fg_yellow$ta_bold
    
   
    # Init Var
    #----------------------------
    BACKUP_CURRENT_PATH=$PATH_RESTORE_FOLDER"/"$JOUR"_"$DEVICE_NAME

    # Init path: Current data to backup before restore
    bck_curr_mms_sms="$BACKUP_CURRENT_PATH/$FOLDER_MMS_SMS_NAME"
    bck_curr_files="$BACKUP_CURRENT_PATH/$FOLDER_FILES_NAME"
    bck_curr_music="$BACKUP_CURRENT_PATH/$FOLDER_MUSIC_NAME"
    bck_curr_contacts="$BACKUP_CURRENT_PATH/$FOLDER_CONTACTS_NAME"
    bck_curr_ringtones="$BACKUP_CURRENT_PATH/$FOLDER_RINGTONES_NAME"
    bck_curr_photos="$BACKUP_CURRENT_PATH/$FOLDER_PHOTOS_NAME"
    bck_curr_download="$BACKUP_CURRENT_PATH/$FOLDER_FILES_NAME" 
  
    # Restore Contacts
    #----------------------------
    if [[ $RESTORE_CONTACTS ]]; then
        pretty_print ""
        pretty_print " *** RESTORE CONTACTS *** " $fg_green$ta_bold
        
        # Initial backup current        
        pretty_print " => backup current conctats in $bck_curr_contacts ..." \
            $fg_cyan
        mkdir -p "$bck_curr_contacts"
        echo -en "$fg_blue"
        adb pull -a "$ADB_CONTACTS" "$bck_curr_contacts"
        
        # Restore contacts
        pretty_print " => Restore contacts..." $fg_cyan
        echo -en "$fg_blue"
        adb push "$contacts_logs_path/contacts2.db" "$ADB_CONTACTS"
        echo -en "$fg_blue"
        adb push "$contacts_logs_path/profile.db" "$ADB_CONTACTS"
         
    else
        pretty_print "Skip restore Contacts !" $fg_yellow$ta_bold 
    fi

    
    # Restore Phones call
    #----------------------------
    if [[ $RESTORE_CALLLOG ]]; then
        pretty_print ""
        pretty_print " *** RESTORE CALL LOGS *** " $fg_green$ta_bold
        
        # Initial backup current        
        if ! test -f "$bck_curr_contacts/calllog.db" ; then
            pretty_print " => backup current  in $bck_curr_contacts ..." \
                $fg_cyan
            mkdir -p "$bck_curr_contacts"
            echo -en "$fg_blue"
            adb pull -a "$ADB_CONTACTS" "$bck_curr_contacts"
        fi
        
        # Restore contacts
        pretty_print " => Restore call logs..." $fg_cyan
        echo -en "$fg_blue"
        adb push "$contacts_logs_path/calllog.db" "$ADB_CONTACTS"                 
    else
        pretty_print "Skip restore Call logs !" $fg_yellow$ta_bold 
    fi
    
    
    # Restore SMS/MMS
    #----------------------------
    if [[ $RESTORE_MMS_SMS ]]; then
        pretty_print ""
        pretty_print " *** RESTORE MMS/SMS *** " $fg_cyan$ta_bold
        
        # Initial backup current       
        pretty_print " => backup current MMS/SMS in $bck_curr_mms_sms ..." \
            $fg_cyan
        mkdir -p "$bck_curr_mms_sms"
        if [ `adb shell "if [ -e $ADB_MMS_SMS ]; then echo 1; fi"` ]; then
            echo -en "$fg_blue"
            adb pull -a "$ADB_MMS_SMS"      "$bck_curr_mms_sms"
        fi
        if [ `adb shell "if [ -e $ADB_MMS_SMS_DATA ]; then echo 1; fi"` ]; then
            echo -en "$fg_blue"
            adb pull -a "$ADB_MMS_SMS_DATA" "$bck_curr_mms_sms"
        fi
        
        # Restore SMS/MMS
        pretty_print " => Restore MMS/SMS..." $fg_cyan
        if [[ "$(ls -A $mms_sms_path)" ]]; then
            echo -en "$fg_blue"
            adb push "$mms_sms_path"/*           "$ADB_MMS_SMS"
        fi
        # Restore media MMS if exist
        if [ ! `adb shell "if [ -e $ADB_MMS_SMS_DATA ]; then echo 1; fi"` ]; then
            adb shell mkdir "$ADB_MMS_SMS_DATA"
        fi
        if [[ "$(ls -A $mms_sms_data_path)" ]]; then
            echo -en "$fg_blue"
            adb push "$mms_sms_data_path"/*      "$ADB_MMS_SMS_DATA"
        fi        
    else
        pretty_print "Skip restore MMS/SMS !" $fg_yellow$ta_bold 
    fi 
        
    
    # Restore Apps
    #----------------------------
    if [[ $RESTORE_APPS ]]; then
        pretty_print ""
        pretty_print " *** RESTORE APPS *** " $fg_green$ta_bold
        
        # Disable ADB verification of APK
        adb_verif_value="null"        
        adb_verif_value=$(adb shell settings get global \
            verifier_verify_adb_installs)
        adb shell settings put global verifier_verify_adb_installs 0
        
        # Disable package verification of APK
        pkg_verif_value="null"
        pkg_verif_value=$(adb shell settings get global \
            package_verifier_enable)
        adb shell settings put global package_verifier_enable 0
    
        # Restore Apps
        if [[ "$MODE_REST_APPS" == "APK" ]]; then
        
            for app in "${LIST_APPS_TO_RESTORE[@]}"; do
                
                # Install Apps
                if test -f $app ; then
                    pretty_print " => Install $(basename $app)..." $fg_cyan
                    
                    # Install .apk
                    echo -en "$fg_blue"
                    adb install $app || true
                else
                    pretty_print " => $app is missing !" $fg_red$ta_bold
                fi
            done
            
            # Select .ab archives    
            ab_archive=""               
            if [[ "$DEVICE_NAME" == "$SRV_DEVICE" ]] \
                    && [[ -z ${no_system_apps-} ]] \
                    || [[ -n ${force_system_apps-} ]]; then
                
                # With system apps archive
                pretty_print " => Restore datas (apps system included)..." \
                    $fg_cyan
                ab_archive="$ALL_APPS_PACKAGE_SYSTEM_BCK"
            else
            
                # Without system apps archive 
                pretty_print " => Restore datas (apps system excluded)..." \
                    $fg_cyan
                ab_archive="$ALL_APPS_PACKAGE_BCK"
            fi
            
            # Restore data apps from .ab archives
            if test -f "$apps_path/$ab_archive"; then
                #basename_app="$(basename $ab_archive)"
                ab_archive_pass=${ab_archive//.ab/_pass}
                if test -f "$apps_path/.$ab_archive_pass"; then
                    pass=$(cat "$apps_path/.$ab_archive_pass")
                    pretty_print "Enter password: " $fg_cyan$ta_bold "no_line"
                    pretty_print " $pass" $fg_magenta$ta_bold 
                else
                    pretty_print " => Warning: Password Missing! " \
                        $fg_yellow$ta_bold 
                fi                
                
                # Restore in separate thread  
                echo -en "$fg_blue"              
                adb restore "$apps_path/$ab_archive" & X=$!
                
                # Start countdown dor 'adb restore' timeout
                countdown 60 & Y=$!                
                wait $X              
                
                # Stop countdown if 'adb restore' is successfuly
                # and escape script if not.
                [[ $(</dev/shm/coundown_state) == 1 ]] \
                    && pretty_print "ADB restore timeout, exit !" $fg_red$ta_bold \
                    && script_exit  "ADB restore failed !" 9 \
                    || (kill $Y 2&> /dev/null || true)
                
            else
                pretty_print " => Archive $ab_archive is missing " \
                $fg_red$ta_bold
            fi       
        
        # For older backup using different methods to backup apps 
        elif [[ "$MODE_REST_APPS" == "LEGACY" ]]; then
            
            for app in "${LIST_APPS_TO_RESTORE[@]}"; do
                basename_app="$(basename $app)"
                pretty_print " => Restore $basename_app ..." $fg_cyan 
                basename_app=${basename_app//.ab/}
                if test -f "$apps_path/$basename_app/.pass"; then
                    pass=$(cat "$apps_path/$basename_app/.pass")
                    pretty_print "Enter password: " $fg_cyan$ta_bold "no_line"
                    pretty_print " $pass" $fg_magenta$ta_bold 
                else
                    pretty_print " => Warning: Password Missing! " \
                        $fg_yellow$ta_bold 
                fi
                
                # Install App
                apk_path=""
                apk_path=$(find "$apps_path/$basename_app/" \
                    -type f \
                    -name "*base.apk" )
                [[ "$apk_path" != "" ]] && \
                    pretty_print " => Install app..." $fg_cyan && \
                    echo -en "$fg_blue" && \
                    adb install $apk_path 
                
                # Restore
                pretty_print " => Restore datas..." $fg_cyan 
                adb restore $app
            done
        fi
    fi
    
    # Reset default value
    adb shell settings put global verifier_verify_adb_installs $adb_verif_value
    adb shell settings put global package_verifier_enable $pkg_verif_value
        
    
    # Restore Photos
    #----------------------------
    if [[ $RESTORE_PHOTOS ]]; then
        pretty_print ""
        pretty_print " *** RESTORE PHOTOS *** "    $fg_green$ta_bold
        
        
        pretty_print " => backup current photos in $bck_curr_photos ..." \
            $fg_cyan
        
        # Backup current DCIM folder
        echo -en "$fg_blue"
        adb pull -a "$PATH_MEDIA_DCIM" "$bck_curr_photos/"
        
        # Backup current Snapseed folder
        echo -en "$fg_blue"
        adb pull -a "$PATH_MEDIA_DCIM" "$bck_curr_photos/"
                
        # Restore : mode legacy    
        if [[ "$MODE_REST_PHOTOS" == "legacy" ]]; then
            pretty_print " => Photos mode LEGACY" $fg_cyan    
            pretty_print " => Restore DCIM folder..." $fg_cyan   
            echo -en "$fg_blue" 
            adb push "$photos_per_back_path/DCIM"/*     "$PATH_MEDIA_DCIM/"
            pretty_print " => Restore Snapseed folder..." $fg_cyan 
            echo -en "$fg_blue"
            adb push "$photos_per_back_path/Snapseed"/* "$PATH_MEDIA_SNAPSEED/"
            photos_per_back_path
             
        # Restore : mode latest    
        elif [[ "$MODE_REST_PHOTOS" == "latest" ]]; then
            pretty_print " => Photos mode LATEST" $fg_cyan    
            
            # Restore DCIM folder
            pretty_print " => Restore DCIM folder..." $fg_cyan
            restore_files "$PATH_PHOTO_LATEST/DCIM" "$PATH_MEDIA_DCIM"
            #[[ "$(ls -A "$PATH_PHOTO_LATEST/DCIM")" ]] && \
            #    pretty_print " => Restore DCIM folder..." $fg_cyan && \
            #    adb push "$PATH_PHOTO_LATEST/DCIM"/*     "$PATH_MEDIA_DCIM/"
            
            # Restore Snapseed folder
            pretty_print " => Restore Snapseed folder..." $fg_cyan
            restore_files "$PATH_PHOTO_LATEST/Snapseed" "$PATH_MEDIA_SNAPSEED"
            #[[ "$(ls -A "$PATH_PHOTO_LATEST/Snapseed")" ]] && \
            #    pretty_print " => Restore Snapseed folder..." $fg_cyan && \
            #    adb push "$PATH_PHOTO_LATEST/Snapseed"/* "$PATH_MEDIA_SNAPSEED/"
        fi
    fi
    
        
    # Restore Music
    #----------------------------
    if [[ $RESTORE_MUSIC ]]; then
        pretty_print ""
        pretty_print " *** RESTORE MUSIC *** " $fg_green$ta_bold
        
        # Initial backup current        
        pretty_print " => backup current music files in $bck_curr_music..." \
            $fg_cyan
        mkdir -p "$bck_curr_music"
        echo -en "$fg_blue"
        adb pull -a "$PATH_MUSIC_STORAGE"   "$bck_curr_music"

        # Restore Music files
        pretty_print " => Restore music files..." $fg_cyan         
        if [[ "$(ls -A "$music_path")" ]];then
            restore_files "$music_path" "$PATH_MUSIC_STORAGE"
        fi      
    else
        pretty_print "Skip restore music files !" $fg_yellow$ta_bold 
    fi
    
    
    # Restore Downloads
    #----------------------------
    if [[ $RESTORE_DOWNLOADS ]]; then
        pretty_print ""
        pretty_print " *** RESTORE DOWNLOADS *** " $fg_green$ta_bold
        
        # Initial backup current        
        pretty_print " => backup current downloaded files in $bck_curr_files..." \
            $fg_cyan
        mkdir -p "$bck_curr_files"
        echo -en "$fg_blue"
        adb pull -a "$PATH_DOWNLOADS_STORAGE"   "$bck_curr_files"

        # Restore Downloads files
        pretty_print " => Restore downloaded files..." $fg_cyan         
        if [[ "$(ls -A "$downloads_path")" ]];then
            restore_files "$downloads_path" "$PATH_DOWNLOADS_STORAGE"
        fi      
    else
        pretty_print "Skip restore downloaded files !" $fg_yellow$ta_bold 
    fi
    
    
    # Restore Documents
    #----------------------------
    if [[ $RESTORE_DOWNLOADS ]]; then
        pretty_print ""
        pretty_print " *** RESTORE DOCUMENTS *** " $fg_green$ta_bold
        
        # Initial backup current        
        pretty_print " => backup current documents files in $bck_curr_files..." \
            $fg_cyan
        mkdir -p "$bck_curr_files"
        echo -en "$fg_blue"
        adb pull -a "$PATH_DOCS_STORAGE"        "$bck_curr_files"

        # Restore Downloads files
        pretty_print " => Restore documents files..." $fg_cyan         
        if [[ "$(ls -A "$documents_path")" ]];then
            restore_files "$documents_path" "$PATH_DOCS_STORAGE"
        fi    
    else
        pretty_print "Skip restore documents files !" $fg_yellow$ta_bold 
    fi
    
    
    # Restore Ringtones
    #----------------------------
    if [[ $RESTORE_RINGTONES ]]; then
        pretty_print ""
        pretty_print " *** RESTORE RINGTONES AND NOTIFICATIONS *** " \
            $fg_green$ta_bold
        
        # Initial backup current
        pretty_print " => backup current ringtones in $bck_curr_ringtones ..." \
            $fg_cyan
        mkdir -p "$bck_curr_ringtones"
        echo -en "$fg_blue"
        adb pull -a "$PATH_RINGTONES_STORAGE"      "$bck_curr_ringtones"
        pretty_print " => backup current ringtones in $bck_curr_ringtones ..." \
            $fg_cyan
        adb pull -a "$PATH_NOTIFICATIONS_STORAGE"      "$bck_curr_ringtones"
        
        # Restore Ringtones
        pretty_print " => Restore Ringtones..." $fg_cyan
        restore_files "$ringtones_path/Ringtones" "$PATH_RINGTONES_STORAGE"
        #[[ "$(ls -A "$ringtones_path/Ringtones")" ]] && \
        #    adb push "$ringtones_path/Ringtones"/* "$PATH_RINGTONES_STORAGE/"
        
        # Restore Notifications
        pretty_print " => Restore Notifications..." $fg_cyan
        restore_files "$ringtones_path/Notifications" \
            "$PATH_NOTIFICATIONS_STORAGE"
        #[[ "$(ls -A "$ringtones_path/Notifications")" ]] && \
        #    adb push "$ringtones_path/Notifications"/* \
        #        "$PATH_NOTIFICATIONS_STORAGE/"
      
    else
        pretty_print "Skip restore ringtones/Notifications !" $fg_yellow$ta_bold 
    fi
    
    
    # End 
    #----------------------------
    
    pretty_print " "
    pretty_print "----------------------------------------------------------"
    pretty_print "                  RESTORE TERMINE"
    pretty_print "----------------------------------------------------------"

    # Kill adb server
#    adb kill-server
    
}

# START
#----------------------------

    # Invoke main with args if not sourced
    # Approach via: https://stackoverflow.com/a/28776166/8787985
    if ! (return 0 2> /dev/null); then
        main "$@"
    fi


# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
