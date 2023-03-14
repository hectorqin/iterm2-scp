#!/bin/bash

serverPWD=""
destination=""
interaction=0
mode=0
filename=()
host=""
user="root"
port="22"

logfile="$(dirname $0)/iterm2-scp.log"
# logfile=/dev/null

# server helper function
scp_helper_func(){ local s="";for i in $@; do s="$s '$i'"; done;echo $s; } && fs(){ scp_helper_func scp_send '-w' "'$(pwd)'" $*; } && js(){ scp_helper_func scp_receive '-w' "'$(pwd)'" $*; }

info()
{
    echo "INFO:" $* >> $logfile
}

error()
{
    echo "ERROR:" $* >> $logfile
}

parseCommand()
{
    while true; do
        # echo "check $1" >> $logfile
        case "${1}" in
            -i|--interaction)
            interaction=1
            shift ;
            ;;
            -w)
            shift ;
            if [[ -n "${1}" ]]; then
                serverPWD="$1"
                shift ;
            fi
            ;;
            -d)
            shift ;
            if [[ -n "${1}" ]]; then
                destination="$1"
                shift ;
            fi
            ;;
            -h)
            shift ;
            if [[ -n "${1}" ]]; then
                host="$1"
                shift ;
            fi
            ;;
            -u)
            shift ;
            if [[ -n "${1}" ]]; then
                user="$1"
                shift ;
            fi
            ;;
            -p)
            shift ;
            if [[ -n "${1}" ]]; then
                port="$1"
                shift ;
            fi
            ;;
            scp_receive)
            mode=1;
            shift ;
            ;;
            scp_send)
            mode=2;
            shift ;
            ;;
            *)
            if [[ -n "${1}" ]]; then
                filename[${#filename[*]}]="$1"
                shift ;
            else
                break ;
            fi
            ;;
        esac
    done
}

packPath()
{
    # $1 folder $2 path
    if [[ "$2" =~ ^/.* ]]; then
        echo "'$2'"
    else
        echo "'$1/$2'"
    fi
}

chooseFolder()
{
    FILE=$(osascript -e 'tell application "iTerm2" to activate' -e 'tell application "iTerm2" to set thefile to choose folder with prompt "Choose a folder to place received files in"' -e "do shell script (\"echo \"&(quoted form of POSIX path of thefile as Unicode text)&\"\")")
    echo $FILE
}

chooseFile()
{
    FILE=`osascript -e 'tell application "iTerm2" to activate' -e 'tell application "iTerm2" to set thefile to choose file with prompt "Choose file to send" with invisibles, multiple selections allowed' -e 'set filelist to ""' -e 'set blank to " "' -e 'repeat with i in thefile' -e 'set filelist to filelist & (quoted form of POSIX path of contents of i as Unicode text) & blank' -e 'end repeat' -e 'filelist' -e "do shell script (\"echo \"&(quoted form of filelist)&\"\")"`
    echo $FILE
}

chooseMode()
{
    local result=$(osascript -e 'tell application "iTerm2" to activate' -e 'tell application "iTerm2" to set opt to the button returned of (display dialog "Please choose upload files or folder" buttons {"Choose file", "Choose folder", "Choose all files in folder"})')

    local res1=$(echo $result | grep "folder" | grep "files")
    local res2=$(echo $result | grep "folder")
    if [[ "$res1" != "" ]]; then
        echo 2
    elif [[ "$res2" != "" ]]; then
        echo 1
    else
        echo 0
    fi
}

notify()
{
    osascript -e "display notification \"$1\" with title \"$2\""
}

exitNow()
{
    echo >> $logfile
    exit 0
}

main()
{
    echo "[ " $(date +'%Y-%m-%d %H:%M:%S') " ]" $* >> $logfile
    parseCommand $*
    info "Command parse result: mode=$mode serverPWD=$serverPWD destination=$destination filename=${filename[*]} user=$user host=$host port=$port"

    local process=$(ps aux | grep $1 | grep -v grep | grep -v iterm2-scp.sh | grep ssh)
    info $process

    shift ;
    if [[ -n "$process" ]]; then
        local ssh_user=$(echo "$process" | grep -Eo "\w+@" | grep -Eo "\w+")
        local ssh_host=$(echo "$process" | grep -Eo "@[0-9.]+" | grep -Eo "[0-9.]+")
        local ssh_port=$(echo "$process" | grep -Eo "\-p [0-9]+" | grep -Eo "[0-9]+")
        if [[ "$ssh_user" != "" ]]; then
            user="$ssh_user"
        fi
        if [[ "$ssh_host" != "" ]]; then
            host="$ssh_host"
        fi
        if [[ "$ssh_port" != "" ]]; then
            port="$ssh_port"
        fi
        if [[ "$host" == "" ]]; then
            error "Can't parse ssh host"
            exitNow
        fi
    else
        if [[ "$host" == "" ]]; then
            error "No ssh host, please use -h option"
            exitNow
        fi
    fi

    if [[ "$user" == "" ]]; then
        user="$USER"
    fi

    if [[ "$port" == "" ]]; then
        port="22"
    fi
    info "SSH parse result: user=$user host=$host port=$port"

    ssh -p $port $user@$host "hostname" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        notify "Please enable SSH ControlMaster or enable SSH public key login" "SSH can't reuse"
        exitNow
    fi

    # scp_send '-w' 'pwd' '-d' 'destination' '-i' 'localfile1' 'localfile2'
    # scp_send '-w' 'pwd' '-d' 'destination' 'localfile1' 'localfile2'
    # scp_receive '-w' 'pwd' '-d' 'destination' 'serverfile1' 'serverfile2'

    if [[ "$mode" == "1" ]]; then
        # download files
        if [[ ${#filename[*]} -lt 1 ]]; then
            notify "'Usage: js serverfile1 [serverfile2]'" "Please input filenames need to be download."
            exitNow
        fi
        local serverPath=""
        for path in ${filename[@]}
        do
            serverPath="$serverPath $(packPath "$serverPWD" "$path")"
        done
        info "Receive files on server: $serverPath"

        local saveDir=$(chooseFolder)

        if [[ "$saveDir" == "" ]];then
            notify "Canceld"
            exitNow
        fi
        info "Local saveDir: $saveDir"

        local command="scp -r -P $port $user@$host:\"$serverPath\" '$saveDir'"

        info "Run command: $command"
        eval $command >> $logfile
        info "File downloaded successfully!"
        notify "File downloaded successfully!"
    else
        # upload files
        if [[ "$destination" != "" ]]; then
            destination=$(packPath "'$serverPWD'" "'$destination'")
        else
            destination="$serverPWD"
        fi

        local chooseMode=$(chooseMode)
        local sendFile
        if [[ "$chooseMode" == "0" ]]; then
            sendFile=$(chooseFile)
        else
            sendFile=$(chooseFolder)
        fi
        if [[ "$sendFile" == "" ]];then
            notify "Canceld"
            exitNow
        fi

        local patern=""
        if [[ "$chooseMode" == "2" ]]; then
            patern="*"
        fi
        info "Local sendFile: $sendFile"

        local command="scp -r -P $port ${sendFile}$patern $user@$host:'$destination'"

        info "Run command: $command"
        eval $command >> $logfile
        info "File upload successfully!"
        notify "File upload successfully!"
    fi
}

main $*
exitNow