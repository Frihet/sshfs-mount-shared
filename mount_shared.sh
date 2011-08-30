#!/bin/bash -ue
#  Mount/unmount remote sshfs file system (files.freecode.no / Shared )
#  Copyright (C) 2011  Christian Bryn <cb@freecode.no>
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.


function do_unmount {
    # unmount based on 'environment'
    if [ "${is_mounted}" == "true" ]; then
        if ( ! fusermount -u "${local_path}" ); then
            while :; do 
                choice=$( zenity --title "FC Shared Mounter" --text "Unmounting $local_path failed!\nYou may have open files - close your open documents and try again.\n" --list --radiolist --column "" --column "Choice" TRUE "Retry" FALSE "Force unmount" FALSE "Cancel" )
                case $choice in
                    "Retry")
                        fusermount -u "${local_path}" || continue
                        ;;
                    "Force unmount")
                        fusermount -z -u "${local_path}" || { zenity --error --text "Even forced unmount failed - backing out..."; break; }
                        ;;
                    "Cancel")
                        break
                        ;;
                esac
            done
        fi
    fi
}

# TODO: z_err, z_info

function p_err {
    # print errors
    # params: <string>
    local string="${@}"
    if [ "${logging}" == "true" ]; then
        printf "[ error ] %s - %s\n" "$(date)" "${string}" >> ${logfile}
    else
        printf "${b:-}${red:-}[ error ]${t_reset:-} %s - %s\n" "$(date)" "${string}"
    fi
}

function p_info {
    # print info
    # params: <string>
    local string="${@}"
    if [ "${logging}" == "true" ]; then
        printf "[ info ] %s -  %s\n" "$(date)" "${string}" >> ${logfile}
    else
        printf "${b:-}${yellow:-}[ info ]${t_reset:-} %s - %s\n" "$(date)" "${string}"
    fi
}

# fancy terminal stuff 
if [ -t 1 ]; then
    exec 3>&2 2>/dev/null
    b=$( tput bold ) || true
    red=$( tput setf 4 ) || true
    green=$( tput setf 2 ) || true
    yellow=$( tput setf 6 ) || true
    t_reset=$( tput sgr0 ) || true
    exec 2>&3; exec 3>&-
fi

# options

remote_server="files.freecode.no"
mount_options=""
username=$USER
local_path=~/Shared
remote_path="/shared/"
logging="false"


while getopts hu:m:Ur:s: o
do
    case $o in
        h)
            print_usage
            exit 0
            ;;
        u)
            username=$OPTARG
            ;;
        m)
            local_path=$OPTARG
            ;;
        U)
            # TODO: User feedback.
            do_unmount
            exit
            ;;
        r)
            remote_path=$OPTARG
            ;;
        s)
            remote_server=$OPTARG
            ;;
    esac
done

shift $(($OPTIND-1))

# TODO: check network connectivity
#if ( ping -q 

# TODO: make is_mounted a function
if ( mount | grep -q "${remote_server}:${remote_path}" ); 
then
    is_mounted="true"
else
    is_mounted="false"
fi

if [ "${is_mounted}" == "true" ]; then
    zenity --question --title "FC Shared" --text "FCNOOS Shared area is already mounted" --ok-label "Keep mounted" --cancel-label "Unmount" || { p_info "Unmounting ${remote_server}:${remote_path}"; do_unmount; }
    exit $?
elif [ "${is_mounted}" == "false" ]; then
    zenity --question --cancel-label "Abort" --text "Mount FCNOOS Shared as user ${username}?" || { p_info "User aborted, exiting..."; exit 0; }
else
    zenity --warning --text "Stete of mount not known. This should not happen. Call for help."
    exit 1
fi
if [ ! -d "${local_path}" ]; then 
    p_info "Creating local mount point ${local_path}"
    mkdir "${local_path}" || { zenity --error --text "Could not mount Shared!\nCould not create local directory ${local_path}"; exit 1; }
fi


if ( ! sshfs ${sshfs_opts:-} ${username}@${remote_server}:${remote_path} ${local_path}/ ); then 
    zenity --error --text "Mounting of ${remote_server}:${remote_path} at ${local_path} failed!\nChecking for local files..."
    files=$( find ${local_path}/ | wc -l )
    if [[ "${files}" -gt 1 ]]; then
        local_backup_path=~/Shared-local-$( date "+%Y-%m-%d_%H.%M" )
        zenity --question --text "Found local files - moving them to ${local_backup_path}" || { p_info "User aborted moving of files, exiting."; exit 0; }
        mkdir "${local_backup_path}" || { zenity --error --text "Could not create local directory ${local_backup_path}"; exit 1; }
        mv ${local_path}/* ${local_backup_path}/ || { zenity --error --text "Could not move files from ${local_path} to ${local_backup_path}"; exit 1; } 
    fi
    sshfs ${sshfs_opts:-} ${username}@${remote_server}:${remote_path} ${local_path}/ || { zenity --error --text "Still no go at mounting Shared - call for help!"; exit 1; }
fi
