#!/bin/bash

IMAGE_NAME=$1
COUNTER=0
SCAN_DONE=0
ERROR_COUNT=0

if [ -z ${IMAGE_NAME} ]; then
   echo "image_name arg is missing."
   exit 1
fi

echo "Checking image [${IMAGE_NAME}]"

# Wait for 60*5s to complete the scan
while [  ${COUNTER} -lt 60 ] ; do
    echo "$(date): Sleeping 5s"
    sleep 5
    scan_details=$(/snap/bin/gcloud beta container images describe ${IMAGE_NAME} --show-package-vulnerability --format=json)
    if [ $? -ne 0 ]; then
        echo "Error when getting image [${IMAGE_NAME}] details"
        let ERROR_COUNT=ERROR_COUNT+1
    fi
    if [ ${ERROR_COUNT} -eq 5 ]; then
        echo "Error: Can not get the image details."
        exit 1
    fi

    # Check image scan status is finished
    status=$(echo ${scan_details} | jq -r ".discovery_summary.discovery[0].discovered.analysisStatus")
    if  [ "${status}" == "FINISHED_SUCCESS" ]; then
        echo "Image scan success"
        SCAN_DONE=1
        break
    fi

    let COUNTER=COUNTER+1
done

if [ $SCAN_DONE -ne 1 ]; then
  echo "Timeout: Image scan not finished yet"
  exit 1
fi

# Calculate CRITICAL and HIGH vulnerabilities
critical=$(echo ${scan_details} | jq ".package_vulnerability_summary.vulnerabilities.CRITICAL | length")
high=$(echo ${scan_details} | jq ".package_vulnerability_summary.vulnerabilities.HIGH | length")

if [ ${critical} -eq 1 ]; then
    echo "Found ${critical} CRITICAL vulnerability"
    exit 1
fi

if [ ${critical} -ne 0 ]; then
    echo "Found ${critical} CRITICAL vulnerabilities"
    exit 1
fi

if [ ${high} -eq 1 ]; then
    echo "Found ${high} HIGH vulnerability"
    exit 1
fi

if [ ${high} -ne 0 ]; then
    echo "Found ${high} HIGH vulnerabilities"
    exit 1
fi

echo "No CRITICAL and HIGH vulnerabilities found"

exit 0
