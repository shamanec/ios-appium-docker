#!/bin/bash

#==========================CONTROL FUNCTIONS==========================#
#===================================================================#
control-function() {
  echo "Please select one of the options below: "
  control_options
  while true
  do
    echo "//====================================//"
    echo "Would you like to select another option?"
    select yn in "Yes" "No"; do
      case $yn in
      Yes)
        control_options
        break
        ;;
      No)
        exit
        ;;
      esac
    done
  done
}

control_options() {
  control_options=("Start listener - Grid" "Start listener - No Grid" "Stop listener" "Setup environment vars" "Setup dependencies" "Setup developer disk images" "Build Docker image" "Remove Docker image" "Add a device" "Destroy containers" "Backup project files" "Restore project files" "Help")
  select option in "${control_options[@]}"; do
    case $option in
    "Start listener - Grid")
      ./listener_script.sh
      break
      ;;
    "Start listener - No Grid")
      ./listener_script.sh no-grid
      break
      ;;
    "Stop listener")
      stop_service
      ;;
    "Setup environment vars")
      setup_environment_vars
      break
      ;;
    "Setup developer disk images")
      setup_developer_disk_images
      break
      ;;
    "Setup dependencies")
      install_dependencies
      break
      ;;
    "Build Docker image")
      docker_build
      break
      ;;
    "Remove Docker image")
      remove_docker_image
      break
      ;;
    "Add a device")
      add_device
      break
      ;;
    "Destroy containers")
      destroy_containers
      break
      ;;
    "Backup project files")
      backup
      break
      ;;
    "Restore project files")=
      restore
      break
      ;;
    "Help")
      echo_help
      break
      ;;
    esac
  done
}

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
  processID=$(ps aux | grep './listener_script.sh' | grep -v grep | awk '{print $2}')
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

kill_service() {
  kill -9 "$1"
  echo "Listening service stopped".
}

destroy_containers() {
  #Stop and remove all containers that contain 'ios_device' in their names
  docker stop "$(docker ps -aqf "name=^ios_device_")"
  docker rm "$(docker ps -aqf "name=^ios_device_")"
  echo "Containers stopped and removed. Closing..."
  sleep 2
  exit
}

#======================ADD DEVICE TO LIST FUNCTIONS==========================#
#============================================================================#

add_device() {
  #If there is no devices.txt file then execute the script for adding first device
  if ! [ -s configs/devices.txt ]; then
    add_first_device
  #If there is a devices.txt file already created execute the script for adding additional devices
  else
    add_additional_device
  fi
  while true
    do
      echo "Would you like to add another device?"
      select yn in "Yes" "No"; do
        case $yn in
        Yes)
          add_additional_device
          break
          ;;
        No)
          break
          ;;
        esac
      done
    done
}

#This method lists the UDIDs of all connected real devices with selection
device_selection_list() {
  udids_array=()
  versions_array=()
  IFS=$'\n'
  #Get all UDIDs parsed from the JSON respone on './ios list --details' into an array
  read -r -d '' -a udids_array < <(./ios list --details | jq -r '.deviceList[].Udid')
  #Get all OS versions parsed from the JSON respone on './ios list --details' into an array
  read -r -d '' -a versions_array < <(./ios list --details | jq -r '.deviceList[].ProductVersion')
  #Present a selection containing all UDIDs and OS versions paired index by index
  echo "Select device from the list of connected devices: "
  select device in "UDID: ${udids_array[@]},OS_VERSION: ${versions_array[@]}"; do
    #After making a selection parse the respective UDID and OS version into variables
    device_udid=$(echo $device | awk -F '[,]' '{print $1}' | awk -F '[: ]' '{print $3}')
    os_version=$(echo $device | awk -F '[,]' '{print $2}' | awk -F '[: ]' '{print $3}')
    break
  done
}

#Method for adding the first device to devices.txt
add_first_device() {
  device_name=""
  device_udid=""
  os_version=""

  #Read non-hardcoded values from user input
  #Input and read device name
  read -p "Enter your device name: " -r device_name
  #If there is no input or the input contains spaces, reject it and ask again
  while :; do
    if [[ -z "$device_name" ]]; then
      read -p "Invalid input, device name cannot contain spaces and cannot be empty. Enter your device name again: " -r device_name
    else
      case ${device_name} in
      *\ *) read -p "Invalid input, device name cannot contain spaces and cannot be empty. Enter your device name again: " -r device_name ;;
      *) break ;;
      esac
    fi
  done

  #List all connected real devices with selection - currently only UDID and OS version
  device_selection_list

  #Write the device to the devices.txt file
  echo "$device_name | $os_version | $device_udid | 4841 | 20001 | 20101 " >>configs/devices.txt
}

#Method for adding additional devices to devices.txt
add_additional_device() {
  device_name=""
  device_udid=""
  os_version=""

  #Get the number of lines in the devices file if not empty
  numberOfLines=$(wc -l <configs/devices.txt)

  #Increment appium port based on number of lines (devices)
  appium_port="$((4840 + $numberOfLines + 1))"

  #Increment wda port based on number of lines (devices)
  wda_port="$((20000 + $numberOfLines + 1))"

  #Increment mjpeg port based on number of lines (devices)
  mjpeg_port="$((20100 + $numberOfLines + 1))"

  #Read non-hardcoded values from user input
  #Input and read device name
  read -p "Enter your device name: " -r device_name
  while :; do
    if [[ -z "$device_name" ]]; then
      read -p "Invalid input, device name cannot contain spaces and cannot be empty. Enter your device name again: " -r device_name
    else
      case ${device_name} in
      *\ *) read -p "Invalid input, device name cannot contain spaces and cannot be empty. Enter your device name again: " -r device_name ;;
      *) break ;;
      esac
    fi
  done

  #Input and read device UDID
  device_selection_list

  #Check if device is already in the devices.txt file list
  devicePresentCheck=$(cat configs/devices.txt | grep ${device_udid})
  if [ -z "$devicePresentCheck" ]; then
    #Write to the devices file the first device
    echo "$device_name | $os_version | $device_udid | $appium_port | $wda_port | $mjpeg_port " >>configs/devices.txt
  else
    echo "The selected device is already added in devices.txt:"
    echo "Line $(cat configs/devices.txt | grep -n ${device_udid})"
    echo "================================================================================="
    device_selection_list
  fi
}

#====================SETUP DEPENDENCIES AND ENVIRONMENT FUNCTIONS=====================#
#=====================================================================#

setup_environment_vars() {
  echo "Are you registering the devices on Selenium Grid? Yes/No"
  select yn in "Yes" "No"; do
    case $yn in
    Yes)
      add_hub_host
      add_hub_port
      add_devices_host
      add_hub_protocol
      break
      ;;
    No)
      add_wda_bundleID
      exit
      ;;
    esac
  done
  add_wda_bundleID
}

add_hub_host() {
  read -p "Enter the IP address of the Selenium Hub Host: " hub_host
  while :; do
    if [[ -z "$hub_host" ]]; then
      read -p "Invalid input, the Selenium Hub Host cannot contain spaces and cannot be empty. Enter the Selenium Hub Host again: " hub_host
    else
      case ${hub_host} in
      *\ *) read -p "Invalid input, the Selenium Hub Host cannot contain spaces and cannot be empty. Enter the Selenium Hub Host again: " hub_host ;;
      *) break ;;
      esac
    fi
  done
  sed -i "s/SELENIUM_HUB_HOST=.*/SELENIUM_HUB_HOST=$hub_host/g" configs/env.txt
}

add_hub_port() {
  read -p "Enter the Selenium Hub Port: " hub_port
  while :; do
    if [[ -z "$hub_port" ]] || [[ "$hub_port" =~ ^[A-za-z]+$ ]]; then
      read -p "Invalid input, the Selenium Hub Port cannot contain spaces, cannot be empty and cannot contain characters. Enter the Selenium Hub Port again: " hub_port
    else
      case ${hub_port} in
      *\ *) read -p "Invalid input, the Selenium Hub Port cannot contain spaces, cannot be empty and cannot contain characters. Enter the Selenium Hub Port again: " hub_port ;;
      *) break ;;
      esac
    fi
  done
  sed -i "s/SELENIUM_HUB_PORT=.*/SELENIUM_HUB_PORT=$hub_port/g" configs/env.txt
}

add_devices_host() {
  read -p "Enter the IP address of the devices host machine: " devices_host
  while :; do
    if [[ -z "$devices_host" ]]; then
      read -p "Invalid input, the devices host IP address cannot contain spaces and cannot be empty. Enter the devices host IP address again: " devices_host
    else
      case ${devices_host} in
      *\ *) read -p "Invalid input, the devices host IP address cannot contain spaces and cannot be empty. Enter the devices host IP address again: " devices_host ;;
      *) break ;;
      esac
    fi
  done
  sed -i "s/DEVICES_HOST_IP=.*/DEVICES_HOST_IP=$devices_host/g" configs/env.txt
}

add_hub_protocol() {
  echo "Please select the hub protocol: http/https"
  select protocol in "http" "https"; do
    sed -i "s/HUB_PROTOCOL=.*/HUB_PROTOCOL=$protocol/g" configs/env.txt
    break
  done
}

add_wda_bundleID() {
  read -p "Enter your WebDriverAgent bundleID (Example: com.shamanec.WebDriverAgentRunner.xctrunner). Type and press Enter or press Enter to select default value: " -r bundle_id
  while :; do
    if [[ -z "$bundle_id" ]]; then
      echo "No bundleID provided, using default value: com.shamanec.WebDriverAgentRunner.xctrunner"
      bundle_id="com.shamanec.WebDriverAgentRunner.xctrunner"
      break
    else
      case ${bundle_id} in
      *\ *) read -p "Invalid input, WebDriverAgent bundleID cannot contain spaces. Enter the bundleID again: " -r bundle_id ;;
      *) break ;;
      esac
    fi
  done
  sed -i "s/WDA_BUNDLE_ID=.*/WDA_BUNDLE_ID=$bundle_id/g" configs/env.txt
}

setup_developer_disk_images() {
  #Clone the disk images from the repo into new folder name DeveloperDiskImages
  git clone https://github.com/shamanec/iOS-DeviceSupport.git DeveloperDiskImages
  #Get in to the new folder and unzip all the files
  cd DeveloperDiskImages/DeviceSupport
  unzip "*.zip"
  rm *.zip
}

#Build Docker image
docker_build() {
  image_name=$1
  if [ "$image_name" != "" ]; then
    docker build -t $image_name .
  else
    docker build -t ios-appium .
  fi
}

#Delete Docker image from local repo
remove_docker_image() {
  image_name=$1
  if [ "$image_name" != "" ]; then
    docker rmi "$(docker images -q $image_name)"
  else
    docker rmi "$(docker images -q ios-appium)"
  fi
}

#Install Docker and allow for commands without sudo - tested on Ubuntu 18.04.5 LTS
install_dependencies() {
  echo "You are about to install Docker, do you wish to continue? Yes/No"
  select yn in "Yes" "No"; do
    case $yn in
    Yes)
      install_docker
      echo "You are about to allow Docker commands without sudo, do you wish to continue? Yes/No"
      select yn in "Yes" "No"; do
        case $yn in
        Yes)
          execute_docker_no_sudo
          break
          ;;
        No) break ;;
        esac
      done
      break
      ;;
    No) break ;;
    esac
  done
  echo "You are about to install unzip util, do you wish to continue? Yes/No"
  select yn in "Yes" "No"; do
    case $yn in
    Yes)
      sudo apt-get update -y && sudo apt-get install -y unzip
      exit
      ;;
    No) exit ;;
    esac
  done
  mkdir logs
  mkdir ipa
}

#INSTALL DOCKER - tested on Ubuntu 18.04.5 LTS
install_docker() {
  #Update your existing list of packages
  sudo apt update
  #Install prerequisites
  sudo apt install apt-transport-https ca-certificates curl software-properties-common
  #Add GPG key
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  #Add the Docker repository
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
  #Update the packages with the new repo
  sudo apt update
  #Make sure you install from Docker repo
  apt-cache policy docker-ce
  #Finally install Docker
  sudo apt install docker-ce
}

#EXECUTING DOCKER COMMANDS WITHOUT SUDO
execute_docker_no_sudo() {
  #Add your username to docker group
  sudo usermod -aG docker "${USER}"
  #Confirm the user is added with:
  id -nG
}

#=======================BACKUP AND RESTORE=========================#
#==================================================================#

backup() {
  if [ ! -d "$(pwd)/backup" ]; then
    mkdir backup
    mkdir backup/configs
  fi
  echo "Please select which project files to backup: "
  options=("All files" "services.sh" "Dockerfile" "configs/wdaSync.sh" "configs/nodeconfiggen.sh" "configs/env.txt" "configs/devices.txt")
  select opt in "${options[@]}"; do
    case $opt in
    "All files")
      cp services.sh backup/services.sh &&
        cp Dockerfile backup/Dockerfile &&
        cp -r configs/* backup/configs
      ;;
    "services.sh")
      cp services.sh backup/services.sh
      ;;
    "Dockerfile")
      cp Dockerfile backup/Dockerfile
      ;;
    "configs/wdaSync.sh")
      cp configs/wdaSync.sh backup/configs/wdaSync.sh
      ;;
    "configs/nodeconfiggen.sh")
      cp configs/nodeconfiggen.sh backup/configs/nodeconfiggen.sh
      ;;
    "configs/env.txt")
      cp configs/env.txt backup/configs/env.txt
      ;;
    "configs/devices.txt")
      cp configs/devices.txt backup/configs/devices.txt
      ;;
    *) echo "Invalid option selected. Please try again.." ;;
    esac
    break
  done
  echo "Files backed up. Closing..."
  sleep 1
  exit 0
}

restore() {
  echo "Please select which project files to restore: "
  options=("All files" "backup/services.sh" "backup/Dockerfile" "backup/configs/wdaSync.sh" "backup/configs/nodeconfiggen.sh" "backup/configs/env.txt" "backup/configs/devices.txt")
  select opt in "${options[@]}"; do
    case $opt in
    "All files")
      if [ ! -d "$(pwd)/backup" ]; then
        echo "Backup folder does not exist, nothing restored. Closing..."
        sleep 2
        exit 0
      fi
      check_file_existence "$(pwd)/backup"
      cp backup/services.sh services.sh &&
        cp backup/Dockerfile Dockerfile &&
        cp -r backup/configs/* configs
      ;;
    "backup/services.sh")
      check_file_existence "backup/services.sh"
      restore_file "$opt" services.sh
      ;;
    "backup/Dockerfile")
      check_file_existence "backup/Dockerfile"
      restore_file "$opt" Dockerfile
      ;;
    "backup/configs/wdaSync.sh")
      check_file_existence "backup/configs/wdaSync.sh"
      restore_file "$opt" configs/wdaSync.sh
      ;;
    "backup/configs/nodeconfiggen.sh")
      check_file_existence "backup/configs/nodeconfiggen.sh"
      restore_file "$opt" configs/nodeconfiggen.sh
      ;;
    "backup/configs/env.txt")
      check_file_existence "backup/configs/env.txt"
      restore_file "$opt" configs/env.txt
      ;;
    "backup/configs/devices.txt")
      check_file_existence "backup/configs/devices.txt"
      restore_file "$opt" configs/devices.txt
      ;;
    *) echo "Invalid option selected. Please try again.." ;;
    esac
    break
  done
  echo "Files restored. Closing..."
  sleep 1
}

check_file_existence() {
  fileName=$1
  if [ ! -f "$fileName" ]; then
    echo "$fileName does not exist, nothing restored. Closing..."
    sleep 2
    exit 0
  fi
}

restore_file() {
  backUpFilePath=$1
  targetPath=$2
  cp "$backUpFilePath" "$targetPath"
}

#==========================HELP==========================#
#========================================================#
echo_help() {
  echo "
      Usage: ./services.sh [argument]
      Flags:
          -h    Print help
      Arguments:
          control                               Presents a selection of controls that consists of all available options that you can select from.
      Control options:
          1) Start listener - Grid              Starts the device listener which creates/destroys containers upon connecting/disconnecting
	  2) Start listener - No Grid           Starts the device listener which creates containers that do not register Appium servers on Selenium Grid
          3) Stop listener  	                Stops the device listener. Also provides option to destroy containers after stopping service.
	  4) Setup environment vars		Update the Selenium Grid host, Selenium Grid port, Selenium Grid protocol type, current devices host and WebDriverAgent bundleID in the env.txt file.
	  5) Setup dependencies			Install the neeeded dependencies to use the project - currently only Docker and unzip. Tested on Ubuntu 18.04.5
	  6) Setup developer disk images	Clones the developer disk images for iOS 13&14 and unzips them to mount to containers
	  7) Build Docker image			Creates a Docker image called 'ios-appium' based on the Dockerfile by default or with a provided name.
	  8) Remove Docker image		Removes the 'ios-appium' Docker image from the local repo by default or with a provided name.
	  9) Add a device			Allows to add a device to devices.txt file automatically from connected devices
	  10) Destroy containers		Stops and removes all iOS device containers
	  11) Backup project files		Backup all or particular project files before working on them.
	  12) Restore project files		Restore files from backup
	  13) Help				Print this section"
}

#=======================MAIN SCRIPT=======================#
#=========================================================#
case "$1" in
control)
  control-function
  ;;
-h)
  echo_help
  ;;
*)
  echo "Invalid option detected: $1"
  echo_help
  exit 1
  ;;
esac
