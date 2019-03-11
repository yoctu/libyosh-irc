# Irc Bash lib
[public:assoc] IRC

IRC['connection':'nick']=""
IRC['connection':'ident']=""
IRC['connection':'server']=""
IRC['connection':'port']=""

IRC['bot':'config':'command':'!set']="Irc::cli::bot::set::command"
IRC['bot':'config':'command':'!unset']="Irc::cli::bot::unset::command"


Irc::check::connection(){

    [[ -z "$IRCCONNECTION_PID" ]] && return 1

    ps -p "$IRCCONNECTION_PID" &>/dev/null || return 1

    return 0
}

Irc::connect(){
    [private] nick="${IRC['connection':'nick']}"
    [private] ident="${IRC['connection':'ident']:-$nick}"
    [private] server="${IRC['connection':'server']}"
    [private:int] port="${IRC['connection':'port']}"

    Type::variable::set nick ident server port || return

    if ! Irc::check::connection; then
        coproc IRCCONNECTION { nc $server $port; }
    else
        return 0
    fi

    Irc::check::connection || return

    echo "NICK $nick" >&${IRCCONNECTION[1]}
    echo "USER $nick 8 *: $nick" >&${IRCCONNECTION[1]}
    sleep 2

    Irc::check::connection || return
}

Irc::send::privMsg(){
    [private] chan="$1"
    [private] msg="${*:2}"

    [[ "$chan" =~ \#.* ]] && Irc::join "$chan"

    Irc::connect

    echo "PRIVMSG $chan :$msg" >&${IRCCONNECTION[1]}
}

Irc::join(){
    [private] chan="$1"

    Irc::connect

    echo "JOIN $chan" >&${IRCCONNECTION[1]}
}

Irc::cli::bot::set::command(){
    [private] command="$1"
    [private] args="${*:2}"

    IRC['bot':'config':'command':"$command"]="$args"
    printf '%s' "$command created!"
}

Irc::cli::bot::unset::command(){
    [private] command="$1"

    Type::variable::set command || return

    unset IRC[bot:config:command:$command]

    echo "$command removed"
}

Irc::cli::bot::args(){
    [private] OPTS="s:p:c:n:h"

    while getopts "${OPTS}" arg; do
        case "${arg}" in
            s) IRC['connection':'server']="$OPTARG"                     ;;
            p) IRC['connection':'port']="$OPTARG"                       ;;
            c) IRC['bot':'config':'channel']="$OPTARG"                  ;;
            n) IRC['connection':'nick']="$OPTARG"                       ;;
            h) Irc::cli::bot::help                                      ;;
    esac
    done
    shift $((OPTIND - 1))
}

Irc::cli::bot::help(){
    [private] help="
            -s          Server
            -p          Port
            -c          Channel
            -n          Nickname
            -h          Help
        "

    echo "$help"
    exit
}

Irc::cli::bot::main(){
    [private] channel="${IRC['bot':'config':'channel']}"
    [private] msg_user
    [private] msg_channel
    [private:array] msg_command

    Type::variable::set channel || return 1

    Irc::join "$channel"

    while read -ru ${IRCCONNECTION[0]} line; do
        [[ "$line" =~ :${IRC['connection':'server']} ]] && continue
        line="${line//$'\r'/}"
        if [[ "$line" =~ :(.*)\!.*PRIVMSG[[:space:]](.*)[[:space:]]:(.*) ]]; then
            msg_user="${BASH_REMATCH[1]}"
            msg_channel="${BASH_REMATCH[2]}"
            msg_command=(${BASH_REMATCH[3]})
            
            echo "Received message from $msg_user@$msg_channel: ${msg_command[0]}"
            if [[ -z "${IRC['bot':'config':'command':${msg_command[0]}]}" ]]; then
                echo "No command!"
                continue
            fi

            Irc::send::privMsg "$msg_channel" "$msg_user: $(${IRC['bot':'config':'command':${msg_command[0]}]} ${msg_command[*]:1})"
            ${IRC['bot':'config':'command':${msg_command[0]}]} ${msg_command[*]:1}
        fi
    
    done
}

CLI['bot':'args']="Irc::cli::bot::args"
CLI['bot':'main']="Irc::cli::bot::main"
