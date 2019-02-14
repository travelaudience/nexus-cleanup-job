#!/bin/bash

set -o pipefail

function output_help {
    echo "Create custom cleanup jobs and excute Nexus pre-configured tasks";
    echo "";
    echo "Example: `basename $0` -p "7 ^v2\/.*\/cache\/.*$ last_downloaded" -t "ab12c229-424a-4a69-8318-22dc21876c3b"";
    echo "";
    echo "Options:";
    echo "  -p       parameters for setting up custom cleanup script ";
    echo "                Should come as a string with spaced seperated values";
    echo "                   Values should come from OrientDb query, please look into image README for more info";
    echo "  -t      Nexus tasks IDs to run after custom cleanup";
    echo "";
}


function load_script {
    # check if the script is not already on Nexus
    output=$(curl -u ${NEXUS_AUTH} -X GET "${NEXUS_URL}/service/rest/v1/script" -H "accept: application/json" | grep dockerCleanup)
    if [ -z "$output" ];
    then
        local BODY;
        BODY=$(cat /scripts/dockerCleanup.groovy | tr -d '\n');
        echo $BODY;
        curl -u ${NEXUS_AUTH} -X POST "${NEXUS_URL}/service/rest/v1/script" -H "accept: application/json" -H "Content-Type: application/json" -d "{ \"name\": \"dockerCleanup\", \"content\": \"${BODY}\", \"type\": \"groovy\"}"
    fi
}

#  If you want to delete this script, run this function.
function delete_script {
    curl -u ${NEXUS_AUTH} -X DELETE "${NEXUS_URL}/service/rest/v1/script/dockerCleanup" -H "accept: application/json"
    if [ $? == 0 ];
    then
        echo 'The script deleted succesfully'
    else
        echo 'There was an error while deleting the script, please try deleting the script from Nexus ui'
    fi
}


function adjust_dates {
    local d;   
    d=$(date --date='-'${1}' day' +%Y-%m-%d)
    echo "$d"
}

function escape_url {
    escape=$(echo "${1}" | sed -e 's:\\:\\\\:g' )
    echo "$escape"
}

function run_final_cleanup {
    #  Triggering  needed tasks including hard cleanup task.
    for i in "$@" ;
    do
        echo "Running Task with ID $i"
        curl -u ${NEXUS_AUTH} -X POST "${NEXUS_URL}/service/rest/v1/tasks/$i/run" -H "accept: application/json";
    done
}


function create_curl {
    DATE=$(adjust_dates ${1});
    URL=$(escape_url ${2});
    TIMEFILTER="${3}";
    curl -u ${NEXUS_AUTH} -X POST "${NEXUS_URL}/service/rest/v1/script/dockerCleanup/run" -H "accept: application/json" -H "Content-Type: text/plain" -d "{\"repoName\":\"${NEXUS_REPO}\",\"startDate\":\"${DATE}\",\"url\":\"${URL}\",\"timeFilter\":\"${TIMEFILTER}\"}"
}


echo "==> Loading Cleanup script" & load_script;
echo "==> Running Custom Cleanup";
while getopts ":p:t:h" opt; do
    case $opt in
        p ) set -f # disable glob
            IFS=' ' # split on space characters
            array=($OPTARG)  # use the split+glob operator
            if [ "${#array[@]}" = 3 ] ;
            then
                create_curl ${array[@]}
            else
                echo  "${array[@]} is not valid, please have 3 parameters per query seperated by space ,/n format \"1 '^v2\/.*\/cache\/.*$' 'blob_created' \" "
            fi;;
        t ) set -f # disable glob
            IFS=' ' # split on space characters
            tasks=($OPTARG) ;; # use the split+glob operator
        h ) output_help;
            exit 0 ;;
        * ) echo "-$OPTARG is not supported "
            exit 1 ;;
    esac
done

echo "==> Running final Cleanup" 
run_final_cleanup ${tasks[@]}
printf "\n Cleanup Ended succesfully!"
