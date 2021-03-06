# ssh agent manager (sam) typically sourced by .bashrc
#xfce agent? NO! xfconf-query -c xfce4-session -p /startup/ssh-agent/enabled -n -t bool -s false
sam () 
{ 
    #DEBUG="INFO";
    [ "$DEBUG" ] && echo "Paging Sam!";

    SAM_ENV_FILE=$HOME/.ssh/.sam_env_file; 
    SAM_AUTH_SOCK=$HOME/.ssh/.sam_auth_sock;

    bye_sam () {
        if [ "$SSH_AUTH_SOCK" = "$SAM_AUTH_SOCK" ]; then
            echo "SAM identities validated from localhost:";
        else
            echo "SAM identities validated from ${SSH_CONNECTION%%' '*}:";
        fi
        ssh-add -l;
        unset DEBUG; 
        unset SA_Stat; 
        unset SAM_ENV_FILE; 
        unset SAM_AUTH_SOCK;
        unset SAM_KEYS;
        unset SAM_CONFIRM;
        unset SAM_DISPLAY;
    }

    if [ -f /usr/bin/ssh-askpass -a -n "$DISPLAY" ]; then
        export SSH_ASKPASS=${SSH_ASKPASS-/usr/bin/ssh-askpass};
        SAM_CONFIRM=${SSH_ASKPASS:+'-c'};
    fi

    #From ssh-add man-page
    # -l      Lists fingerprints of all identities currently represented by the agent.
    # Exit status is:   0 ssh-agent is reachable and has at least one key.
    #                   1 ssh-agent is reachable and has no keys
    #                   2 ssh-add is unable to contact the authentication agent.
    ssh-add -l &> /dev/null; SA_Stat=$?;
    if [ $SA_Stat -eq 2 ]; then
        #No agent in env, try stored agent
        if [ -e $SAM_ENV_FILE ]; then
            [ -n "$DEBUG" ] && echo "Using stored agent, is it viable?";
            source $SAM_ENV_FILE;
            ssh-add -l &> /dev/null; SA_Stat=$?;
        fi
    else
        [ "$DEBUG" ] && echo "agent from env is available.";
    fi

    [ -n "$DEBUG" ] && echo -n "SAM branching on condition: $SA_Stat, ";
    case $SA_Stat in
        2)  [ "$DEBUG" ] && echo "agent unreachable, start a new one.";
            eval "$(ssh-agent -k &> /dev/null)";
            killall ssh-agent;
            rm -f $SAM_AUTH_SOCK
            eval "$(ssh-agent -a $SAM_AUTH_SOCK -s | tee $SAM_ENV_FILE)";
            ;&
        *)  [ "$DEBUG" ] && echo "Check/add keys to agent.";
            if [ -f "$1" ]; then
                SAM_KEYS=$(ssh-add -l);
                [ "${SAM_KEYS#*$1}" != "$SAM_KEYS" ] && bye_sam && return;
            else
                [ $SA_Stat -eq 0 ] && bye_sam && return;
            fi
    esac
    for n in {1..3}; do
        ssh-add $SAM_CONFIRM $1 && break;
        [ "$DEBUG" ] && echo "Adding key failed, please try again."
    done;
    bye_sam;
}

