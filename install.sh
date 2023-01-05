#!/bin/bash
echo "we are going to install :)"
export DEBIAN_FRONTEND=noninteractive
if [ "$(id -u)" -ne 0 ]; then
        echo 'This script must be run by root' >&2
#        exit 1
fi



function set_env_if_empty(){
 echo "applying configs from $1========================================="
 for line in $(sed 's/\#.*//g' $1 | grep '=');do  
  IFS=\= read k v <<< $line
#   if [[ ! -z $k && -z "${!k}" ]]; then      
      export $k="$v"
      echo $k="$v"
#   fi
  
 done        

}

function runsh() {    
        pushd $2; 
        if [[ -f $1 ]];then
                echo "==========================================================="
                echo "===$1 $2"
                echo "==========================================================="        
                bash $1
        fi
        popd 
}

function do_for_all() {
        #cd /opt/$GITHUB_REPOSITORY
        bash common/replace_variables.sh
        runsh $1.sh common
        runsh $1.sh nginx
        if [[ $ENABLE_TELEGRAM == true ]]; then
                runsh $1.sh telegram
        else
                runsh uninstall.sh telegram
        fi
        if [[ $ENABLE_SS == true ]]; then
                runsh $1.sh shadowsocks
        else
                runsh uninstall.sh telegram
        fi
        if [[ $ENABLE_VMESS == true ]]; then
                runsh $1.sh vmess
        else
                runsh uninstall.sh telegram
        fi

        if [[ $ENABLE_MONITORING == true ]]; then
                runsh $1.sh monitoring
        else
                runsh uninstall.sh telegram
        fi
              
        if [[ $ENABLE_TROJAN_GO == true ]]; then
                runsh $1.sh trojan-go
        else
                runsh uninstall.sh telegram
        fi
        runsh $1.sh xray
        runsh $1.sh admin_ui
}


function check_for_env() {

        random_secret=$(hexdump -vn16 -e'4/4 "%08x" 1 "\n"' /dev/urandom)
        replace_empty_env USER_SECRET "setting 32 char user secret" $random_secret "^([0-9A-Fa-f]{32})$"
        replace_empty_env BASE_PROXY_PATH "setting 32 char for proxy path" $random_secret ".*"


        random_admin_secret=$(hexdump -vn16 -e'4/4 "%08x" 1 "\n"' /dev/urandom)
        replace_empty_env ADMIN_SECRET "setting 32 char admin secret" $random_admin_secret "^([0-9A-Fa-f]{32})$"


        export SERVER_IP=$(curl -Lso- https://api.ipify.org)
        replace_empty_env MAIN_DOMAIN "please enter valid domain name to use " "$SERVER_IP.sslip.io" "^([A-Za-z0-9\.]+\.[a-zA-Z]{2,})$"
        
        
        DOMAIN_IP=$(dig +short -t a $MAIN_DOMAIN.)
        

        echo "resolving domain $MAIN_DOMAIN -> IP= $DOMAIN_IP ServerIP-> $SERVER_IP"
        if [[ $SERVER_IP != $DOMAIN_IP ]];then
                echo "maybe it is an error! make sure that it is correct"
                sleep 5
        fi

        # replace_empty_env CLOUD_PROVIDER "If you are using a cdn please enter the cdn domain " "" /^([a-z0-9\.]+\.[a-z]{2,})?$/i

}

function replace_empty_env() {
        VAR=$1
        DESCRIPTION=$2
        DEFAULT=$3
        REGEX=$4
        if [[ -z "${!VAR}" ]]; then
                echo ''
                echo "============================"
                echo "$DESCRIPTION"
                
                if [[ -z "$DEFAULT" ]]; then
                        echo "Enter $VAR?"
                else
                        # echo "Enter $VAR (default value='$DEFAULT' -> to confirm enter)"
                        echo "using '$DEFAULT' for $VAR"
                fi

                # read -p "> " RESPONSE
                #if [[ -z "$RESPONSE" ]]; then
                #        RESPONSE=$DEFAULT
                #fi
                RESPONSE=$DEFAULT
                if [[ ! -z "$REGEX" ]];then
                        if [[ "$RESPONSE" =~ $REGEX ]];then
                                sed -i "s|$1=|$1=$RESPONSE|g" config.env 
                                cat config.env|grep -e "^$1"
                                if [[ "$!?" != "0" ]]; then
                                    echo "$1=$RESPONSE">> config.env
                                fi

                                export $1=$RESPONSE
                        else 
                                echo "!!!!!!!!!!!!!!!!!!!!!!"
                                echo "invalid response $RESPONSE -> regex= $REGEX"
                                echo "retry:"
                                replace_empty_env "$1" "$2" "$3" "$4"
                        fi

                fi
                
        fi
}

function main(){
        set_env_if_empty config.env.default
        set_env_if_empty config.env

        if [[ "$BASE_PROXY_PATH" == "" ]]; then
                replace_empty_env BASE_PROXY_PATH "" $USER_SECRET ".*"
        fi

        cd /opt/$GITHUB_REPOSITORY
        git pull

        if [[ -z "$DO_NOT_RUN" || "$DO_NOT_RUN" == false ]];then
                check_for_env
        fi

        if [[ -z "$DO_NOT_INSTALL" || "$DO_NOT_INSTALL" == false  ]];then
                do_for_all install
                systemctl daemon-reload
        fi

        if [[ -z "$DO_NOT_RUN" || "$DO_NOT_RUN" == false ]];then
                do_for_all run
                echo ""
                echo ""
                echo "==========================================================="
                echo "Finished! Thank you for helping Iranians to skip filternet."
                echo "Please open the following link in the browser for client setup"
                cat nginx/use-link
        fi

        bash status.sh
        systemctl restart hiddify-admin.service
}

mkdir -p log/system/
main |& tee log/system/0-install.log