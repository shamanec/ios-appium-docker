#!/bin/bash
#=====================SERVICE AND CONTAINER FUNCTIONS=======================#
#===========================================================================#

start_container() {
  on_grid=$1
  echo "================================================================"
  #Generate logs dir name for the specific device
  LOGSDIR="logs/container_$deviceName-$udid"
  #Create the logs dir if not already present
  if [ ! -d "$LOGSDIR" ]; then
    now="$(date +'%d/%m/%Y %H:%M:%S')"
    echo "[$now] Creating logs folder for the device in logs/container_$deviceName-$udid"
    mkdir "logs/container_$deviceName-$udid"
  fi
  echo "[$now] Starting container for device $deviceName with UDID: $udid."
  #Get the WDA bundle id from the env.txt file to provide to the container
  wda_bundle_id=$(cat configs/env.txt | grep "WDA_BUNDLE_ID" | cut -d '=' -f 2)
  if [ "$on_grid" == "no-grid" ]; then
    #Build custom part of the docker run command when not connecting to Selenium Grid
    hub_lines="	-e ON_GRID=false"
  else
    #Get the Selenium Grid arguments from the env.txt file to provide to the container
    hub_host=$(cat configs/env.txt | grep "SELENIUM_HUB_HOST" | cut -d '=' -f 2)
    hub_port=$(cat configs/env.txt | grep "SELENIUM_HUB_PORT" | cut -d '=' -f 2)
    devices_host=$(cat configs/env.txt | grep "DEVICES_HOST_IP" | cut -d '=' -f 2)
    hub_protocol=$(cat configs/env.txt | grep "HUB_PROTOCOL" | cut -d '=' -f 2)
    #Build custom part of the docker run command when connecting to Selenium Grid
    hub_lines="	-e SELENIUM_HUB_HOST=$hub_host \
	-e SELENIUM_HUB_PORT=$hub_port \
	-e ON_GRID=true \
	-e DEVICES_HOST=$devices_host \
	-e HUB_PROTOCOL=$hub_protocol \
	-p $hub_port:$hub_port"
  fi
  docker run --name "ios_device_$deviceName-$udid" \
    -p "$appium_port":"$appium_port" \
    -p "$wda_port":"$wda_port" \
    -p "$mjpeg_port":"$mjpeg_port" \
    -e DEVICE_UDID="$udid" \
    -e WDA_PORT="$wda_port" \
    -e MJPEG_PORT="$mjpeg_port" \
    -e APPIUM_PORT="$appium_port" \
    -e DEVICE_OS_VERSION="$osVersion" \
    -e DEVICE_NAME="$deviceName" \
    $hub_lines \
    -e WDA_BUNDLEID="$wda_bundle_id" \
    -v /var/run/usbmuxd:/var/run/usbmuxd \
    -v /var/lib/lockdown:/var/lib/lockdown \
    -v "$(pwd)"/DeveloperDiskImages/DeviceSupport:/opt/DeveloperDiskImages \
    -v "$(pwd)"/ipa:/opt/ipa \
    -v "$(pwd)/logs/container_$deviceName-$udid":/opt/logs \
    ios-appium >>"logs/container_$deviceName-$udid/containerLogs.txt" 2>&1 &
}

start_service() {
  on_grid=$1
  devices=configs/devices.txt
  while true; do
    #Read the device.txt file line by line
    while IFS= read -r line; do
      #Parse the respective device values for the current line from devices.txt file
      udid=$(echo "$line" | cut -d '|' -f 3 | xargs)
      deviceName=$(echo "$line" | cut -d '|' -f 1 | xargs)
      osVersion=$(echo "$line" | cut -d '|' -f 2 | xargs)
      appium_port=$(echo "$line" | cut -d '|' -f 4 | xargs)
      wda_port=$(echo "$line" | cut -d '|' -f 5 | xargs)
      mjpeg_port=$(echo "$line" | cut -d '|' -f 6 | xargs)
      #Check if the currently targeted device is connected to the machine
      output=$(./ios list | grep "$udid")
      #If the device is not connected to the machine
      if [ -z "$output" ]; then
        echo "================================================================"
        now="$(date +'%d/%m/%Y %H:%M:%S')"
        echo "[$now] Device with Name: $deviceName, OS Version: $osVersion and UDID: $udid is not connected to the machine."
        #Check if a container still exists for the not connected device - if there is one, remove it
        containerOutput=$(docker ps -a | grep "$udid")
        if [ -z "$containerOutput" ]; then
          echo "[$now] No leftover container for this device to kill"
        else
          echo "[$now] Killing leftover container for disconnected device with Name: $deviceName and UDID: $udid"
          containerID=$(docker ps -aqf "name=^ios_device_")
          docker stop "$containerID"
          docker rm "$containerID"
        fi
      #If the device is connected to the machine
      else
        #Check if a container already exists for this device
        containerOutput=$(docker ps -a | grep "$udid")
        #If container doesn't exist - create one
        if [ -z "$containerOutput" ]; then
          start_container "$on_grid"
        #If container already exists - do nothing
        else
          now="$(date +'%d/%m/%Y %H:%M:%S')"
          echo "[$now] ================================================================"
          echo "[$now] There is a container already running for device $deviceName with UDID: $udid. Nothing to do."
        fi
      fi
      sleep 10
    done <"$devices"
  done
}

stop_service() {
  #Get the process ID of the running listener script
  processID=$(ps aux | grep './services.sh control' | grep -v grep | awk '{print $2}')
  echo "The process ID is $processID"
  #If there is no running listener process do nothing
  if [ -z "$processID" ]; then
    echo "The service is not running. Nothing to do."
    exit 1
  #If there is a running listener process
  else
    echo "Are you sure you want to stop the listening service? Yes/No"
    select yn in "Yes" "No"; do
      case $yn in
      Yes)
	#Kill the running listener process and ask to destroy containers
        kill_service "$processID"
        echo "Do you also wish to destroy the devices containers? Yes/No"
        select yn in "Yes" "No"; do
          case $yn in
          Yes) destroy_containers ;;
          No)
            echo "Closing..."
            sleep 2
            exit
            ;;
          esac
        done
        exit
        ;;
      No)
	#Don't kill the running listener process and exit
        echo "Listening service not stopped. Closing..."
        sleep 2
        exit
        ;;
      esac
    done
  fi
}

case "$1" in
no-grid)
  start_service $1 >>"logs/deviceSync.txt" 2>&1 &
  ;;
*)
  start_service >>"logs/deviceSync.txt" 2>&1 &
  ;;
esac
