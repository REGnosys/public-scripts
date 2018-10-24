#!/bin/bash

usage() {
    echo "usage: install-rosetta-ingest.sh [-i] [-c installConfDir]  [-v version] [-h] -u username -p password -l licenceFile"
}

checkArg() {
    if [ "${1}" == "" ]; then
        usage
        echo $2
        exit 1
    fi
}

set -e
set -o pipefail

interactive=
version=
username=
password=
licenceFile=
installConfDir=

while [ "$1" != "" ]; do
    case $1 in
        -v | --version )        shift
                                version=$1
                                ;;
        -u | --username )    shift
                                username=$1
                                ;;
        -p | --password )    shift
                                password=$1
                                ;;
        -l | --licenceFile )    shift
                                licenceFile=$1
                                ;;
        -c | --installConfDir ) shift
                                installConfDir=$1
                                ;;
        -i | --interactive )
                                interactive=true
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

if [ "$interactive" == "true" ]; then
    echo "Please enter the REGnosys Artifactory username"
    read username

    echo "Please enter the REGnosys Artifactory password"
    read password

    echo "Please enter the REGnosys Licence file path"
    read licenceFile

    echo "Please enter the install config dir (leave blank for current dir)"
    read installConfDir

    echo "Please enter the version of Rosetta Ingest you want to install (leave blank for latest version)"
    read version
fi

checkArg "$username" "Must give a username"
checkArg "$password" "Must give a password"
checkArg "$licenceFile" "Must give a licenceFile"

if [ ! -f "$licenceFile" ]; then
        echo "$licenceFile does not exist. Please specify a valid licence file."
        exit 1
fi

if [ "$installConfDir" == "" ]; then
        installConfDir=`pwd`/rosetta-ingest-conf
fi

if [ "$version" == "" ]; then
        version=latest
fi

loginToDocker() {
    echo "Logging into REGnosys docker registory with user ${username}"
    docker login -u $username -p $password  regnosys-docker-registry.jfrog.io
}

pullDockerImage() {
    echo "Pulling image rosetta-ingest-service:${version}"
    docker pull regnosys-docker-registry.jfrog.io/rosetta-ingest-service:${version}
}

initConfDir() {
    echo "Initialising the config directory: ${installConfDir}"
    if [ ! -d "$installConfDir" ]; then
        echo "Creating dir ${installConfDir}"
        mkdir -p ${installConfDir}
    fi

    echo "Copying ${licenceFile} to ${installConfDir}"
    cp ${licenceFile} ${installConfDir}

    echo "Fetching CDM Jar file with version $version"
    if [ "$version" == "latest" ]; then
        cdmJarFileName=cdm-latest.jar
        curl -o ${installConfDir}/${cdmJarFileName} "https://${username}:${password}@regnosys.jfrog.io/regnosys/libs-snapshot-local/com/isda/cdm/\[RELEASE\]/cdm-\[RELEASE\].jar"
    else
        cdmJarFileName=cdm-${version}.jar
        curl -o ${installConfDir}/${cdmJarFileName} "https://${username}:${password}@regnosys.jfrog.io/regnosys/libs-snapshot-local/com/isda/cdm/${version}/${cdmJarFileName}"
    fi
}

runRosettaIngest() {

    containerName="rosetta-ingest-${version}"
    
    containerNameExists=`docker ps -a --format '{{.Names}}' --filter Name=${containerName}`
    if [ "${containerNameExists}" == "${containerName}" ]; then
        docker stop ${containerName}
        docker rm ${containerName}
    fi

    echo "Running Rosetta Ingest : ${containerName}"
    docker run --name rosetta-ingest-${version} \
            -d \
            -p 9000:5846 \
            -v `pwd`/rosetta-ingest-conf:/app/config \
            regnosys-docker-registry.jfrog.io/rosetta-ingest-service:${version}

    echo
    echo
    echo "Successfully running :rosetta-ingest-${version}"

    echo "To check if service is running  : docker ps"  
    echo "To check logs : docker logs rosetta-ingest-${version}"  
    echo "To stop the service : docker stop rosetta-ingest-${version}"

    echo "API available at : http://localhost:9000/api/swagger"

}

loginToDocker
pullDockerImage
initConfDir
runRosettaIngest
