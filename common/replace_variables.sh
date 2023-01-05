
HEX_TELEGRAM_DOMAIN=$(echo -n "$TELEGRAM_FAKE_TLS_DOMAIN"| xxd -ps | tr -d '\n')
CLOUD_PROVIDER=${CLOUD_PROVIDER:-$MAIN_DOMAIN}


TEMP_LINK_VALID_TIME="$(date '+%Y-%m-%dT(%H\|')$(printf '%02d)' $(($(date '+%H') +1)))"
IP=$(curl -Lso- https://api.ipify.org);

USERS=$(echo $USER_SECRET | tr ";" "\n")

DEF_USER=${USER_SECRET%%\;*}
DEF_GUID_SECRET="${DEF_USER:0:8}-${DEF_USER:8:4}-${DEF_USER:12:4}-${DEF_USER:16:4}-${DEF_USER:20:12}"

for template_file in $(find . -name "*.template"); do
    out_file=${template_file/.template/}
    cp $template_file $out_file
    if [[ "$ENABLE_MONITORING" == "false" ]];then
        sed -i "s|access_log /opt/GITHUB_REPOSITORY/log/nginx.log proxy;|access_log off;|g" $out_file
    fi
    sed -i "s|TEMP_LINK_VALID_TIME|$TEMP_LINK_VALID_TIME|g" $out_file 

    sed -i "s|ADMIN_SECRET|$ADMIN_SECRET|g" $out_file 

    if [[ "$out_file" != *"xtls"* ]];then
        sed -i "s|defaultusersecret|$DEF_USER|g" $out_file 
        sed -i "s|defaultuserguidsecret|$DEF_GUID_SECRET|g" $out_file 
    fi

    sed -i "s|defaultcloudprovider|$CLOUD_PROVIDER|g" $out_file 
    sed -i "s|defaultserverip|$IP|g" $out_file 
    sed -i "s|defaultserverhost|$MAIN_DOMAIN|g" $out_file 
    sed -i "s|telegramadtag|$TELEGRAM_AD_TAG|g" $out_file 
    sed -i "s|telegramtlsdomain|$TELEGRAM_FAKE_TLS_DOMAIN|g" $out_file 
    sed -i "s|sstlsdomain|$SS_FAKE_TLS_DOMAIN|g" $out_file 
    sed -i "s|hextelegramdomain|$HEX_TELEGRAM_DOMAIN|g" $out_file 
    sed -i "s|CDN_NAME|${CDN_NAME:-ar}|g" $out_file 
    sed -i "s|GITHUB_REPOSITORY|$GITHUB_REPOSITORY|g" $out_file 
    sed -i "s|GITHUB_USER|$GITHUB_USER|g" $out_file 
    sed -i "s|GITHUB_BRANCH_OR_TAG|$GITHUB_BRANCH_OR_TAG|g" $out_file 
    sed -i "s|BASE_PROXY_PATH|$BASE_PROXY_PATH|g" $out_file 

    

done


# cp xray/xtls-sni-config.json.template xray/xtls-sni-config.json

grep xray/xtls-sni-config.json -e defaultuserguidsecret| while read -r line ; do
    # echo "Processing $line"
	final=""
	for USER in $USERS
	do
        GUID_USER="${USER:0:8}-${USER:8:4}-${USER:12:4}-${USER:16:4}-${USER:20:12}"
		final=$final,${line//defaultuserguidsecret/"$GUID_USER"}
	done
    # your code goes here
	final=${final:1}
	sed -i "s|$line|$final|g" xray/xtls-sni-config.json
done
