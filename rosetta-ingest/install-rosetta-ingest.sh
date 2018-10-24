#!/bin/bash

usage()
{
    echo "usage: install-rosetta-ingest.sh -c installConfDir -u username -p password -v version -l licenceFile [-h]"
}

set -e
set -o pipefail

version=
username=
password=
licenceFile=
installConfDir=`pwd`/rosetta-ingest-conf

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
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

if [ "$version" == "" ]; then
        usage
        echo "Must give a version"
        exit 1
fi

if [ "$username" == "" ]; then
        usage
        echo "Must give a username"
        exit 1
fi

if [ "$password" == "" ]; then
        usage
        echo "Must give a password"
        exit 1
fi

if [ "$licenceFile" == "" ]; then
        usage
        echo "Must give a licenceFile"
        exit 1
fi


loginToDocker() {
    echo "Logging into REGnosys docker registory"
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
    echo "Running Rosetta Ingest :rosetta-ingest-${version}"
    docker run --name rosetta-ingest-${version} \
            -d \
            -p 9000:5846 \
            -v `pwd`/rosetta-ingest-conf:/app/config \
            regnosys-docker-registry.jfrog.io/rosetta-ingest-service:${version}

    echo "Successfully running :rosetta-ingest-${version}"
    echo "To check logs, run  : docker logs rosetta-ingest-${version}"
}

loginToDocker
pullDockerImage
initConfDir
runRosettaIngest
