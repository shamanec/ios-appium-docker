#!/bin/bash
#=====================SERVICE AND CONTAINER FUNCTIONS=======================#
#===========================================================================#

start_container() {
  on_grid=$1
  echo "================================================================"
  #Generate logs dir name for the specific device
  LOGSDIR="logs/container_$deviceName-$device_udid"
  #Create the logs dir if not already present
  if [ ! -d "$LOGSDIR" ]; then
    now="$(date +'%d/%m/%Y %H:%M:%S')"
    echo "[$now] Creating logs folder for the device in logs/container_$deviceName-$device_udid"
    mkdir "logs/container_$deviceName-$device_udid"
  fi
  echo "[$now] Starting container for device $deviceName with UDID: $device_udid."
  #Read the config.json into variable so we dont read it when extracting values each time
  config_json=$(cat configs/config.json)
  #Get the WDA bundle id from the config.json file to provide to the container
  wda_bundle_id=$(echo "$config_json" | jq -r ".wda_bundle_id")
  if [ "$on_grid" == "no_grid" ]; then
    #Build custom part of the docker run command when not connecting to Selenium Grid
    hub_lines="	-e ON_GRID=false"
  else
    #Get the Selenium Grid arguments from the config.json file to provide to the container
    hub_host=$(echo "$config_json" | jq -r ".selenium_hub_host")
    hub_port=$(echo "$config_json" | jq -r ".selenium_hub_port")
    devices_host=$(echo "$config_json" | jq -r ".devices_host")
    hub_protocol=$(echo "$config_json" | jq -r ".selenium_hub_protocol_type")
    #Build custom part of the docker run command when connecting to Selenium Grid
    hub_lines="	-e SELENIUM_HUB_HOST=$hub_host \
	-e SELENIUM_HUB_PORT=$hub_port \
	-e ON_GRID=true \
	-e DEVICES_HOST=$devices_host \
	-e HUB_PROTOCOL=$hub_protocol \
	-p $hub_port:$hub_port"
  fi
  docker run --name "ios_device_$deviceName-$device_udid" \
    -p "$appium_port":"$appium_port" \
    -p "$wda_port":"$wda_port" \
    -p "$mjpeg_port":"$mjpeg_port" \
    -e DEVICE_UDID="$device_udid" \
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
    -v "$(pwd)/logs/container_$deviceName-$device_udid":/opt/logs \
    ios-appium >>"logs/container_$deviceName-$device_udid/containerLogs.txt" 2>&1 &
}

start_service() {
  on_grid=$1
  deviceName=""
  osVersion=""
  appium_port=""
  wda_port=""
  mjpeg_port=""
  while true; do
  #Read the config.json into variable so we dont unnecessarily open it too often
  config_json=$(cat configs/config.json)
  read -r -d '' -a devices_udids < <( echo "$config_json" | jq -r ".devicesList[].device_udid" 2>&1)
  for device_udid in "${devices_udids[@]}"; do
    #Read the respective device values from the config.json file
    deviceName=$(echo "$config_json" | jq -r ".devicesList[] | select(.device_udid==\"$device_udid\") | .device_name")
    osVersion=$(echo "$config_json" | jq -r ".devicesList[] | select(.device_udid==\"$device_udid\") | .device_os_version")
    appium_port=$(echo "$config_json" | jq -r ".devicesList[] | select(.device_udid==\"$device_udid\") | .appium_port")
    wda_port=$(echo "$config_json" | jq -r ".devicesList[] | select(.device_udid==\"$device_udid\") | .wda_port")
    mjpeg_port=$(echo "$config_json" | jq -r ".devicesList[] | select(.device_udid==\"$device_udid\") | .wda_mjpeg_port")
    #Check if the currently targeted device is connected to the machine
    output=$(./ios list | grep "$device_udid")
    #If the device is not connected to the machine
    if [ -z "$output" ]; then
        echo "================================================================"
        now="$(date +'%d/%m/%Y %H:%M:%S')"
        echo "[$now] Device with Name: $deviceName, OS Version: $osVersion and UDID: $device_udid is not connected to the machine."
        #Check if a container still exists for the not connected device - if there is one, remove it
        containerOutput=$(docker ps -a | grep "$device_udid")
        if [ -z "$containerOutput" ]; then
          echo "[$now] No leftover container for this device to kill"
        else
          echo "[$now] Killing leftover container for disconnected device with Name: $deviceName and UDID: $device_udid"
          containerID=$(docker ps -aqf "name=^ios_device_")
          docker stop "$containerID"
          docker rm "$containerID"
        fi
      #If the device is connected to the machine
     else
        #Check if a container already exists for this device
        containerOutput=$(docker ps -a | grep "$device_udid")
        #If container doesn't exist - create one
        if [ -z "$containerOutput" ]; then
          start_container "$on_grid"
        #If container already exists - do nothing
        else
          now="$(date +'%d/%m/%Y %H:%M:%S')"
          echo "[$now] ================================================================"
          echo "[$now] There is a container already running for device $deviceName with UDID: $device_udid. Nothing to do."
        fi
      fi
      sleep 2
    done
   done
}

case "$1" in
no_grid)
  start_service $1 >>"logs/deviceSync.txt" 2>&1 &
  ;;
*)
  start_service >>"logs/deviceSync.txt" 2>&1 &
  ;;
esac
