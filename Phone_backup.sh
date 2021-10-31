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
#                               PHONE_BACKUP.SH                               #
#                                                                             #
###############################################################################

#-----------------------------------------------------------------------------#
#     Author(s): Pakaoraki
#     Version: 1.0
#     Date: 08/10/2020
#     Last Modif. Date: 24/08/2021
#
#     Description: -Backup data from android to a PC linux PC folder
#                 using ADB tools.
#                  -Save contacts, SMS/MMS, phone calls logs databases and 
#                 generate inteligible VCARD/XML files.
#                  -Backup Apps/data, photos, ringtones.
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
     -v|--version               Displays version
    -lm|--list-music            Exclude backup for music and export a list of
                                files instead.
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
            -v|--version)
                echo "Version $VERSION"
                exit 0;
                ;;        
            -V|--verbose)
                verbose=true
                ;;
            -lm|--list-music)
                list_music=true
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
 ______  _                          ______              _                 
(_____ \| |                        (____  \            | |                     
 _____) ) | _   ___  ____   ____    ____)  ) ____  ____| |  _ _   _ ____     
|  ____/| || \ / _ \|  _ \ / _  )  |  __  ( / _  |/ ___) | / ) | | |  _ \   
| |     | | | | |_| | | | ( (/ /   | |__)  | ( | ( (___| |< (| |_| | | | |  
|_|     |_| |_|\___/|_| |_|\____)  |______/ \_||_|\____)_| \_)\____| ||_/   
                                                                   |_|                         
 ------------------- Phone Backup - v$VERSION ----------------------------
"

    # ADB Init
    #----------------------------
    
    # Start ADB server
    init_adb

    # Get device name
    DEVICE_NAME=$(adb shell getprop ro.product.model)
    DEVICE_NAME=${DEVICE_NAME// /-}
    pretty_print " => SOURCE DEVICE: " $fg_cyan "no_line"
    pretty_print "$DEVICE_NAME" $fg_yellow$ta_bold

    
    # Init Variables
    #----------------------------    
    
    # Get file conf if exist
    if test -f "$CONFIG_FILE"; then
        source "$CONFIG_FILE"
    fi
    
    # Path
    FOLDER_CURRENT_BACKUP=$JOUR"_"$DEVICE_NAME
    PATH_CURRENT_BACKUP=$PATH_BACKUP_FOLDER"/"$FOLDER_CURRENT_BACKUP
    PATH_PHOTO_LATEST="$PATH_BACKUP_FOLDER/$FOLDER_BACKUP_PHOTOS/Latest"
    PATH_PHOTO_TODAY="$PATH_BACKUP_FOLDER/$FOLDER_BACKUP_PHOTOS/$JOUR"
    
    
    # Check and change folder name if already exist
    i=1
    NEW_PATH_BACKUP=$PATH_CURRENT_BACKUP
    while (test -f "$NEW_PATH_BACKUP/$BOOL_STATE"); do
        NEW_PATH_BACKUP=$PATH_BACKUP_FOLDER"/"$FOLDER_CURRENT_BACKUP"_$i"
        i=$((i+1))
    done    
    if [[ "$NEW_PATH_BACKUP" != "$PATH_CURRENT_BACKUP" ]]; then
        pretty_print " Backup dir already exist:" $fg_cyan "no_line"
        pretty_print " $(basename $PATH_CURRENT_BACKUP)." $fg_cyan
        PATH_CURRENT_BACKUP="$NEW_PATH_BACKUP"
        pretty_print " => Création du dossier $PATH_CURRENT_BACKUP." $fg_cyan
    fi
    
    # Init Path
    PATH_CONTACTS_FOLDER="$PATH_CURRENT_BACKUP/$FOLDER_CONTACTS_NAME"
    PATH_MMS_SMS_FOLDER="$PATH_CURRENT_BACKUP/$FOLDER_MMS_SMS_NAME"
    PATH_APP_FOLDER="$PATH_CURRENT_BACKUP/$FOLDER_APP_NAME"
    PATH_PHOTOS_FOLDER="$PATH_CURRENT_BACKUP/$FOLDER_PHOTOS_NAME"
    PATH_MUSIC_FOLDER="$PATH_CURRENT_BACKUP/$FOLDER_MUSIC_NAME"
    PATH_FILES_FOLDER="$PATH_CURRENT_BACKUP/$FOLDER_FILES_NAME"
    PATH_BOOKMARK_FOLDER="$PATH_CURRENT_BACKUP/$FOLDER_BOOKMARKS_NAME"
    PATH_RINGTONES_FOLDER="$PATH_CURRENT_BACKUP/$FOLDER_RINGTONES_NAME"
    PATH_APK_FOLDER=""
    PATH_CONTACTS_DB="$PATH_CONTACTS_FOLDER/databases/contacts2.db"
    PATH_CONTACTS_CALL_LOG="$PATH_CONTACTS_FOLDER/databases/calllog.db"
     
    # Create current backup Folder
    if !(test -d "$PATH_CURRENT_BACKUP"); then
        mkdir -p "$PATH_CURRENT_BACKUP"
    fi
    
    # Check and auto-install dependencies
    check_dependencies
    
    # Check Abe-all.jar utility
    if (test -f "$PATH_ANDROID_UNARCHIVER"); then
        
        # Add execution permission if needed
        if ! [[ $(stat -c "%A" "$PATH_ANDROID_UNARCHIVER") =~ "x" ]]; then
            run_as_root chmod +x "$PATH_ANDROID_UNARCHIVER"
        fi
    else
        pretty_print " Missing $ANDROID_UNARCHIVER file ! Exiting..." \
            "$fg_red$ta_bold"
        script_exit "file missing" 2
    fi

    
    # Contacts, SMS/MMS & phone logs
    #----------------------------
    
    # Create Contacts folder
    if !(test -d "$PATH_CONTACTS_FOLDER"); then
        mkdir -p "$PATH_CONTACTS_FOLDER"
    fi
    
    # Get Contact and Phone call logs databases
    pretty_print ""
    pretty_print "*** BACKUP CONTACTS ***" $fg_green$ta_bold
    if [ `adb shell "if [ -e $ADB_CONTACTS ]; then echo 1; fi"` ]; then
        pretty_print " => Extract Contacts databases from $DEVICE_NAME..." \
        $fg_cyan
        echo -en "$fg_blue"
        adb pull -a "$ADB_CONTACTS" "$PATH_CONTACTS_FOLDER/"
        pretty_print " "
    fi
        
    # Create MMS/SMS folder
    if !(test -d "$PATH_MMS_SMS_FOLDER"); then
        pretty_print " => Create $PATH_MMS_SMS_FOLDER folder..." $fg_cyan
        mkdir -p "$PATH_MMS_SMS_FOLDER"
    fi
    
    # Get SMS and MMS databases
    pretty_print ""
    pretty_print "*** BACKUP SMS/MMS ***" $fg_green$ta_bold
    if [ `adb shell "if [ -e $ADB_MMS_SMS ]; then echo 1; fi"` ]; then
        pretty_print " => Extract SMS/MMS databases from $DEVICE_NAME..." \
            $fg_cyan
        echo -en "$fg_blue"
        adb pull -a "$ADB_MMS_SMS" "$PATH_MMS_SMS_FOLDER/"
        pretty_print " "
    fi
    if [ `adb shell "if [ -e $ADB_MMS_SMS_DATA ]; then echo 1; fi"` ]; then
    pretty_print " => Extract MMS datas databases from $DEVICE_NAME..." \
        $fg_cyan
        echo -en "$fg_blue"
        adb pull -a "$ADB_MMS_SMS_DATA" "$PATH_MMS_SMS_FOLDER/"
        pretty_print " "
    fi
     
     
    # Convert contacts & call logs data files
    #----------------------------
    pretty_print ""
    pretty_print "*** CONTACTS & CALL LOGS CONVERSION ***" $fg_green$ta_bold
    
    # ---- *** Make Contact VCARD file *** ---- #    
    if (test -f "$PATH_CONTACTS_DB"); then
        pretty_print " => Converting contacts.db to contacts_$JOUR.vcf" \
            $fg_cyan

        # VCARD V3 - Use a script to create the VCARD file
        bash $PATH_SCRIPT_CONTACT -V \
            -m=V3 \
            -o="$PATH_CONTACTS_FOLDER/contacts_"$JOUR"_V3.vcf" \
            "$PATH_CONTACTS_DB"
                               
        # VCARD V4 - Use a script to create the VCARD file
        bash $PATH_SCRIPT_CONTACT -V \
            -m=V4 \
            -o="$PATH_CONTACTS_FOLDER/contacts_"$JOUR"_V4.vcf" \
            "$PATH_CONTACTS_DB"
                 
                              
       # ./dump-contacts2db.sh "$PATH_CONTACTS_DB" > \
       #     "$PATH_CONTACTS_FOLDER/contacts_$JOUR_V3.vcf"
    else
        pretty_print "WARN: No contacts databases found..." $fg_yellow$ta_bold
    fi
     
    # ---- *** Make Phone call log XML file *** ---- #
    pretty_print " => Call logs: .xml conversion..." $fg_cyan
    
    # Create XML files compatible SuperBackup    
    bash $PATH_SCRIPT_CALLLOGS -V -m=SuperBackup \
        -o="$PATH_CONTACTS_FOLDER/Call_logs_SuperBackup_$JOUR.xml" \
        "$PATH_CONTACTS_CALL_LOG"
    
    # Create XML files compatible BackupAndRestore    
    bash $PATH_SCRIPT_CALLLOGS -V -m=BackupAndRestore \
        -o="$PATH_CONTACTS_FOLDER/Call_logs_BackupAndRestore_$JOUR.xml" \
        "$PATH_CONTACTS_CALL_LOG"
        
  
    # Apps 
    #----------------------------
    pretty_print ""
    pretty_print "*** BACKUP APPS ***" $fg_green$ta_bold
       
    # Create APP folder
    if !(test -d "$PATH_APP_FOLDER"); then
        pretty_print " => Create $PATH_APP_FOLDER folder..." $fg_cyan
        mkdir -p "$PATH_APP_FOLDER"
    fi
    
    # Create APK folder
    path_apk_dir="$PATH_APP_FOLDER/APK"
    if !(test -d "$path_apk_dir"); then
        pretty_print " => Create $path_apk_dir folder..." $fg_cyan
        mkdir -p "$path_apk_dir"
    fi
    
    # Backup ALL APK from installed apps
    path_apk_dir="$path_apk_dir/"
    pretty_print " => Backup all Apps APK..." $fg_cyan$ta_bold
    echo -en "$fg_blue"
    for APP in $(adb shell pm list packages -3 -f)
    do
        adb pull $( echo ${APP} \
                | sed "s/^package://" \
                | sed "s/base.apk=/base.apk ${path_apk_dir//'/'/'\/'}/" \
                | awk '{print $1" "$2".apk"}'  )           
    done
        
    # Backup DATA from all installed apps - NO SYSTEM APPS
    pretty_print ""
    backup_all_apps
    
    # Backup DATA from all installed apps
    pretty_print ""
    backup_all_apps "system"    
    
      
    # ----- *** Notes *** ----- #    

    # Export text
    pretty_print " => Notes: Export Content in Notes.txt." $fg_cyan

    # Create Notes dir
    mkdir -p "$PATH_APP_FOLDER/Notes"
    
    # Extract data from ADB previously backuped archive
    unpack_adb_archive "$ALL_APPS_PACKAGE_BCK"
    
    # Extract text from database and save it intext file
    PATH_APP_NOTE_UNTAR_DB="$PATH_APP_FOLDER/.${ALL_APPS_PACKAGE_BCK/.ab/}"
    PATH_APP_NOTE_UNTAR_DB+="/apps/com.simplemobiletools.notes.pro/db/notes.db"    
    sqlite3 "$PATH_APP_NOTE_UNTAR_DB" \
        "SELECT * FROM notes" \
        > "$PATH_APP_FOLDER/Notes/Notes.txt"
    
    # Fin
    pretty_print " => Notes: backup finished" $fg_cyan
    pretty_print " "
    
    # Clean 
    clean_unpacked_adb_archive "$ALL_APPS_PACKAGE_BCK"
    
    # ------------------------- #
    
    # --- *** Signal *** --- #
  
    # Backup
    pretty_print " => Extra backup for Signal." $fg_cyan$ta_bold
    if [ `adb shell "if [ -e $ADB_BACKUP_SIGNAL ]; then echo 1; fi"` ]; 
    then
        pretty_print " Signal   - Copy $ADB_BACKUP_SIGNAL..." $fg_cyan
        echo -en "$fg_blue"
        adb pull -a $ADB_BACKUP_SIGNAL "$PATH_APP_FOLDER/"        
        pretty_print " "
    fi
    
    # Fin
    pretty_print " => Signal: backup finished" $fg_cyan
    pretty_print " "
    
    # ------------------------- #
    
    
    # ----- *** Chrome *** ----- #
    pretty_print " => Extra backup for Chrome..." $fg_cyan$ta_bold
    
    # Create Chrome Backup folder    
    if !(test -d "$PATH_APP_FOLDER/Chrome"); then
        pretty_print " => Chrome: Create folder $PATH_APP_FOLDER/Chrome" \
        $fg_cyan
        mkdir -p "$PATH_APP_FOLDER/Chrome"
    fi 
    
    # Backup
    if [ `adb shell "if [ -e $ADB_APPS_CHROME_DATA ]; then echo 1; fi"` ]; 
    then
        pretty_print " => Chrome: Copy $ADB_APPS_CHROME_DATA..." \
            $fg_cyan
        echo -en "$fg_blue"
        adb pull -a $ADB_APPS_CHROME_DATA "$PATH_APP_FOLDER/Chrome/"
        pretty_print " "
    fi
    # Fin
    pretty_print " => Chrome: backup finished" $fg_cyan
    pretty_print " "
    
    # ------------------------- #
    
    # ----- *** Firefox *** ----- #
    pretty_print " => Extra backup for Firefox..." $fg_cyan$ta_bold
    
    # Create Whatsapp Backup folder
    if !(test -d "$PATH_APP_FOLDER/Firefox"); then
        pretty_print " => Firefox: Create folder $PATH_APP_FOLDER/Firefox" \
            $fg_cyan
        mkdir -p "$PATH_APP_FOLDER/Firefox"
    fi 
    
    # Backup
    if [ `adb shell "if [ -e $ADB_APPS_FIREFOX_DATA ]; then echo 1; fi"` ]; 
    then 
        pretty_print " => Firefox: Copy $ADB_APPS_FIREFOX_DATA..." \
            $fg_cyan
        echo -en "$fg_blue"
        adb pull -a $ADB_APPS_FIREFOX_DATA "$PATH_APP_FOLDER/Firefox/"
        pretty_print " "
    fi
    
    # Fin
    pretty_print " => Firefox: backup finished" $fg_cyan
    pretty_print " "
    
    # ------------------------- #

    
    # List all user application installed in a file
    pretty_print " => APPS: Export Apps list in " \
        $fg_cyan "no_line"
    pretty_print "\'$PATH_APP_FOLDER/List_installed_apps.txt\'" \
        $fg_cyan
    adb shell "pm list packages -e -3" \
        > "$PATH_APP_FOLDER/List_installed_apps.txt"
     

    # Backup Photos
    #----------------------------
    
    # Create Photos folder
    #if !(test -d "$PATH_PHOTOS_FOLDER"); then
    #    mkdir -p "$PATH_PHOTOS_FOLDER"
    #fi
    
    # DCIM (Camera) 
    pretty_print "*** BACKUP PHOTOS & VIDEOS ***" $fg_green$ta_bold
    if [ `adb shell "if [ -e $PATH_MEDIA_DCIM ]; then echo 1; fi"` ]; then
        pretty_print " => Folder DCIM found, backup in progress..." $fg_cyan
        
        # Backup des photos
        backup_images "$PATH_MEDIA_DCIM" \
                      "$PATH_PHOTO_TODAY/DCIM" \
                      "$PATH_PHOTO_LATEST/DCIM" 
    else
         pretty_print "INFO: No DCIM directory found !" $fg_cyan
    fi
    
    # Snapseed
    if [ `adb shell "if [ -e $PATH_MEDIA_SNAPSEED ]; then echo 1; fi"` ]; then
        pretty_print " => Fodler Snapseed found, backup in progress..." \
            $fg_cyan
       
        # Backup des photos
        backup_images "$PATH_MEDIA_SNAPSEED" \
                      "$PATH_PHOTO_TODAY/Snapseed" \
                      "$PATH_PHOTO_LATEST/Snapseed" 
    else
         pretty_print "INFO: No Snapseed directory found !" $fg_cyan
    fi 
    
    # Whatsapp
    if [ `adb shell "if [ -e $PATH_MEDIA_WHATSAPP ]; then echo 1; fi"` ]; then
        pretty_print " => Folder Whatsapp/Media found, backup in progress..." \
            $fg_cyan
        
        # Backup des photos
        backup_images "$PATH_MEDIA_WHATSAPP" \
                      "$PATH_PHOTO_TODAY/Media" \
                      "$PATH_PHOTO_LATEST/Media" 
    else
         pretty_print "INFO: No Whatsapp/Media found !" \
            $fg_cyan
    fi 
    
   
    # Backup Files
    #----------------------------
    pretty_print ""
    pretty_print "*** BACKUP FILES ***" $fg_green$ta_bold
    
    
    # Create Files folder
    if !(test -d "$PATH_FILES_FOLDER"); then
        message=" => Files: Create folder $PATH_FILES_FOLDER..."
        pretty_print "$message" $fg_cyan
        mkdir -p "$PATH_FILES_FOLDER"
    fi
    
    # Backup Download
    if [ `adb shell "if [ -e $PATH_DOWNLOADS_STORAGE ]; then echo 1; fi"` ];
    then
        pretty_print " => Backup Downloads files..." $fg_cyan
        echo -en "$fg_blue"
        adb pull -a "$PATH_DOWNLOADS_STORAGE" "$PATH_FILES_FOLDER/"
        pretty_print " "
    fi
    
    # Backup Documents
    if [ `adb shell "if [ -e $PATH_DOWNLOADS_STORAGE ]; then echo 1; fi"` ];
    then
        pretty_print " => Backup Documents files..." $fg_cyan
        echo -en "$fg_blue"
        adb pull -a "$PATH_DOCS_STORAGE" "$PATH_FILES_FOLDER/"
        pretty_print " "
    fi
    
    # Fin
    pretty_print " => Downloads files: backup finished" $fg_cyan
    
    
    # Backup Music
    #----------------------------    
    pretty_print ""
    pretty_print "*** BACKUP MUSIC ***" $fg_green$ta_bold
    
    # Create Music folder
    if !(test -d "$PATH_MUSIC_FOLDER"); then
        message=" => Music: Create folder $PATH_MUSIC_FOLDER..."
        pretty_print "$message" $fg_cyan
        mkdir -p "$PATH_MUSIC_FOLDER"
    fi   
    
   
    if [ `adb shell "if [ -e $PATH_MUSIC_STORAGE ]; then echo 1; fi"` ]; then
    
        # Backup Music files
        if [[ -z ${list_music-} ]]; then            
            pretty_print " => Folder Music found, copy in progress..." $fg_cyan
            echo -en "$fg_blue"
            adb pull -a "$PATH_MUSIC_STORAGE" "$PATH_MUSIC_FOLDER/"
            pretty_print " "
        
        # OR List files and export it
        else        
            pretty_print " => Export list of Music files..." $fg_cyan
            adb shell "find $PATH_MUSIC_STORAGE \
                -name '*.flac' \
                -o -name '*.mp3' \
                -o -name '*.m4a' \
                -o -name '*.ogg' " \
                > "$PATH_MUSIC_FOLDER/$FILE_MUSIC_BACKUP_NAME"
        fi
    else
        pretty_print "INFO: No Music directory found !" $fg_cyan
    fi
    
    
    # Download bookmark
    #----------------------------
    pretty_print ""
    pretty_print "*** BACKUP BOOKMARKS ***" $fg_green$ta_bold
    
    # Create Bookmarks folder
    if !(test -d "$PATH_BOOKMARK_FOLDER"); then
        message=" => Bookmarks: Create folder $PATH_BOOKMARK_FOLDER..."
        pretty_print "$message" $fg_cyan
        mkdir -p "$PATH_BOOKMARK_FOLDER"
    fi
    
    # ----- *** Chrome *** ----- #
    
    # Create Chrome folder
    if !(test -d "$PATH_BOOKMARK_FOLDER/Chrome"); then
        pretty_print " => Bookmarks: Create folder Chrome..." $fg_cyan
        mkdir -p "$PATH_BOOKMARK_FOLDER/Chrome"
    fi
    
    # Backup
    pretty_print " => Bookmarks: save Chrome datatabes." $fg_cyan
    if [ `adb shell "if [ -e $ADB_BOOKMARKS_CHROME ]; then echo 1; fi"` ]; then
        pretty_print " => Bookmarks:  -Copy $ADB_BOOKMARKS_CHROME..." \
            $fg_cyan
        echo -en "$fg_blue"
        adb pull -a $ADB_BOOKMARKS_CHROME "$PATH_BOOKMARK_FOLDER/Chrome/"   
        pretty_print " "    
    fi
    # ----------------------- #
    
    # --- *** Firefox *** --- #
    
    # Create Firefox folder    
    if !(test -d "$PATH_BOOKMARK_FOLDER/Firefox"); then
        pretty_print " => Bookmarks: Create folder Firefox..." $fg_cyan
        mkdir -p "$PATH_BOOKMARK_FOLDER/Firefox"
    fi
    
    # Backup places.sqlites
    pretty_print " => Bookmarks: save Firefox databases." $fg_cyan
    if [ `adb shell "if [ -e $ADB_BOOKMARKS_FIREFOX ]; then echo 1; fi"` ]; 
    then
        pretty_print " => Bookmarks:  -copy $ADB_BOOKMARKS_FIREFOX..." \
            $fg_cyan
        echo -en "$fg_blue"
        adb pull -a "$ADB_BOOKMARKS_FIREFOX" "$PATH_BOOKMARK_FOLDER/Firefox/"
        pretty_print " "
    fi    
    
    # Backup places.sqlites-shm
    if [ `adb shell "if [ -e "$ADB_BOOKMARKS_FIREFOX-shm" ]; then echo 1; fi"` ]; 
    then
        pretty_print " => Bookmarks:  -copy $ADB_BOOKMARKS_FIREFOX-shm..." \
            $fg_cyan
        echo -en "$fg_blue"
        adb pull -a "$ADB_BOOKMARKS_FIREFOX-shm" \
            "$PATH_BOOKMARK_FOLDER/Firefox/"
        pretty_print " "
    fi    
    
    # Backup places.sqlites-wal
    if [ `adb shell "if [ -e "$ADB_BOOKMARKS_FIREFOX-wal" ]; then echo 1; fi"` ]; 
    then
        pretty_print " => Bookmarks:  -copy $ADB_BOOKMARKS_FIREFOX-wal..." \
            $fg_cyan
        echo -en "$fg_blue"
        adb pull -a "$ADB_BOOKMARKS_FIREFOX-wal" \
            "$PATH_BOOKMARK_FOLDER/Firefox/"
        pretty_print " "
    fi
    
    # Traitement: extart data from BDD to an .csv file.
    pretty_print " => Bookmarks: Process and export Firefox datas to CSV ..." \
        $fg_cyan
    if (test -f "$PATH_BOOKMARK_FOLDER/Firefox/places.sqlite"); then
        sqlite3 "$PATH_BOOKMARK_FOLDER/Firefox/places.sqlite" -csv\
            "SELECT DISTINCT 
                b.title,p.url 
             FROM 
                moz_bookmarks b,
                moz_places p 
             INNER JOIN 
                moz_places on b.fk = p.id;" \
            > "$PATH_BOOKMARK_FOLDER/Firefox/Bookmarks.csv"
    else
        pretty_print " => Bookmarks: No Firefox databases found !" \
            $fg_yellow$ta_bold
    fi
    
    # ----------------------- #
    
    # Backup ringtones 
    #---------------------------- 
    pretty_print ""   
    pretty_print "*** BACKUP RINGTONES & NOTIFICATIONS ***" $fg_green$ta_bold
    
    # Create Ringtones folder
    if !(test -d "$PATH_RINGTONES_FOLDER"); then
        pretty_print " => Create folder $PATH_RINGTONES_FOLDER..." \
            $fg_cyan
        mkdir -p "$PATH_RINGTONES_FOLDER"
    fi    
    
    # Ringtones
    if [ `adb shell "if [ -e $PATH_RINGTONES_STORAGE ]; then echo 1; fi"` ];
    then
        pretty_print " => Ringtones directory found, copy in progress..." \
            $fg_cyan  
        echo -en "$fg_blue"
        adb pull -a "$PATH_RINGTONES_STORAGE" "$PATH_RINGTONES_FOLDER/"
    else
        pretty_print "INFO: No Ringtones directory found !" $fg_cyan
    fi
    pretty_print " "
    
    # Notifications
    if [ `adb shell "if [ -e $PATH_NOTIFICATIONS_STORAGE ]; then echo 1; fi"` ]; 
    then
        pretty_print " => Notifications directory found, copy in progress..." \
            $fg_cyan
            echo -en "$fg_blue"
        adb pull -a "$PATH_NOTIFICATIONS_STORAGE" "$PATH_RINGTONES_FOLDER/"
    else
        pretty_print "INFO: No Notifications directory found !" $fg_cyan
    fi
    pretty_print " "
   
    
    # End 
    #----------------------------
    
    # Leave boolean state
    echo "SUCCESS" > "$PATH_CURRENT_BACKUP/$BOOL_STATE"
    pretty_print " "
    pretty_print "----------------------------------------------------------"
    pretty_print "                  END OF BACKUP" $fg_green$ta_bold
    pretty_print "----------------------------------------------------------"
    # Kill adb server
    adb kill-server
    
}

# START
#----------------------------

    # Invoke main with args if not sourced
    # Approach via: https://stackoverflow.com/a/28776166/8787985
    if ! (return 0 2> /dev/null); then
        main "$@"
    fi


# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
