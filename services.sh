#!/bin/bash


#==========================SETUP FUNCTIONS==========================#
#===================================================================#
setup() {
 echo "Are you registering the devices on Selenium Grid? Yes/No"
 select yn in "Yes" "No"; do
	case $yn in
		Yes ) add-hub-host
		      add-hub-port
		      add-devices-host
		      add-hub-protocol
		      break;;
		No ) add-wda-bundleID
		     exit;;
	esac
 done
 add-wda-bundleID
}

add-hub-host() {
 read -p "Enter the IP address of the Selenium Hub Host: " hub_host
  while :
   do
    if [[ -z "$hub_host" ]]; then
      read -p "Invalid input, the Selenium Hub Host cannot contain spaces and cannot be empty. Enter the Selenium Hub Host again: " hub_host
    else
    case ${hub_host} in
       *\ *) read -p "Invalid input, the Selenium Hub Host cannot contain spaces and cannot be empty. Enter the Selenium Hub Host again: " hub_host;;
          *) break;;
    esac
    fi
   done
 sed -i "s/SELENIUM_HUB_HOST=.*/SELENIUM_HUB_HOST=$hub_host/g" configs/env.txt
}

add-hub-port() {
 read -p "Enter the Selenium Hub Port: " hub_port
  while :
   do
    if [[ -z "$hub_port" ]] || [[ "$hub_port" =~ ^[A-za-z]+$ ]]; then
     read -p "Invalid input, the Selenium Hub Port cannot contain spaces, cannot be empty and cannot contain characters. Enter the Selenium Hub Port again: " hub_port
     else
      case ${hub_port} in
        *\ *) read -p "Invalid input, the Selenium Hub Port cannot contain spaces, cannot be empty and cannot contain characters. Enter the Selenium Hub Port again: " hub_port;;
           *) break;;
      esac
    fi
   done
 sed -i "s/SELENIUM_HUB_PORT=.*/SELENIUM_HUB_PORT=$hub_port/g" configs/env.txt
}

add-devices-host() {
 read -p "Enter the IP address of the devices host machine: " devices_host
  while :
   do
    if [[ -z "$devices_host" ]]; then
      read -p "Invalid input, the devices host IP address cannot contain spaces and cannot be empty. Enter the devices host IP address again: " devices_host
    else
    case ${devices_host} in
       *\ *) read -p "Invalid input, the devices host IP address cannot contain spaces and cannot be empty. Enter the devices host IP address again: " devices_host;;
          *) break;;
    esac
    fi
   done
 sed -i "s/DEVICES_HOST_IP=.*/DEVICES_HOST_IP=$devices_host/g" configs/env.txt
}

add-hub-protocol() {
 echo "Please select the hub protocol: http/https"
 select protocol in "http" "https"; do
   sed -i "s/HUB_PROTOCOL=.*/HUB_PROTOCOL=$protocol/g" configs/env.txt
   break
 done
}

add-wda-bundleID() {
read -p "Enter your WebDriverAgent bundleID (Example: com.shamanec.WebDriverAgentRunner.xctrunner) " -r bundle_id
 while :
  do
   if [[ -z "$bundle_id" ]]; then
    echo "No bundleID provided, using default value: com.shamanec.WebDriverAgentRunner.xctrunner"
    bundle_id="com.shamanec.WebDriverAgentRunner.xctrunner"
    break
   else
    case ${bundle_id} in
      *\ *) read -p "Invalid input, WebDriverAgent bundleID cannot contain spaces. Enter the bundleID again: " -r bundle_id;;
      *) break;;
    esac
   fi
  done
 sed -i "s/WDA_BUNDLE_ID=.*/WDA_BUNDLE_ID=$bundle_id/g" configs/env.txt
}

#=====================SERVICE AND CONTAINER FUNCTIONS=======================#
#===========================================================================#

startContainer() {
 on_grid=$1
 echo "================================================================"
 LOGSDIR="logs/container_$deviceName-$udid"
 if [ ! -d "$LOGSDIR" ]
 then
  now="$(date +'%d/%m/%Y %H:%M:%S')"
  echo "[$now] Creating logs folder for the device in logs/container_$deviceName-$udid"
  mkdir "logs/container_$deviceName-$udid"
 fi
 echo "[$now] Starting container for device $deviceName with UDID: $udid."
 hub_host=$(cat configs/env.txt | grep "SELENIUM_HUB_HOST" | cut -d '=' -f 2)
 hub_port=$(cat configs/env.txt | grep "SELENIUM_HUB_PORT" | cut -d '=' -f 2)
 wda_bundle_id=$(cat configs/env.txt | grep "WDA_BUNDLE_ID" | cut -d '=' -f 2)
 devices_host=$(cat configs/env.txt | grep "DEVICES_HOST_IP" | cut -d '=' -f 2)
 hub_protocol=$(cat configs/env.txt | grep "HUB_PROTOCOL" | cut -d '=' -f 2)
 if [ "$on_grid" == "no-grid" ]
 then
  hub_lines="	-e ON_GRID=false"
 else
  hub_lines="	-e SELENIUM_HUB_HOST=$hub_host \
	-e SELENIUM_HUB_PORT=$hub_port \
	-e  ON_GRID=true \
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
	go-ios-docker >> "logs/container_$deviceName-$udid/containerLogs.txt" 2>&1 &
}

start-service() {
on_grid=$1
devices=configs/devices.txt
while true
do
while IFS= read -r line
 do
  udid=$(echo "$line" | cut -d '|' -f 3 | xargs)
  deviceName=$(echo "$line" | cut -d '|' -f 1 | xargs)
  osVersion=$(echo "$line" | cut -d '|' -f 2 | xargs)
  appium_port=$(echo "$line" | cut -d '|' -f 4 | xargs)
  wda_port=$(echo "$line" | cut -d '|' -f 5 | xargs)
  mjpeg_port=$(echo "$line" | cut -d '|' -f 6 | xargs)
  output=$(./gidevice list | grep "$udid")
  if [ -z "$output" ]
  then
   echo "================================================================"
   now="$(date +'%d/%m/%Y %H:%M:%S')"
   echo "[$now] Device with Name: $deviceName, OS Version: $osVersion and UDID: $udid is not connected to the machine."
   containerOutput=$(docker ps -a | grep "$udid")
   if [ -z "$containerOutput" ]
   then
    echo "[$now] No leftover container for this device to kill"
   else
    echo "[$now] Killing leftover container for disconnected device with Name: $deviceName and UDID: $udid"
    containerID=$(docker ps -aqf "name=^ios_device_")
    docker stop "$containerID"
    docker rm "$containerID"
  fi
  else
   containerOutput=$(docker ps -a | grep "$udid")
   if [ -z "$containerOutput" ]
   then
   startContainer "$on_grid"
   else
    now="$(date +'%d/%m/%Y %H:%M:%S')"
    echo "[$now] ================================================================"
    echo "[$now] There is a container already running for device $deviceName with UDID: $udid. Nothing to do."
   fi
  fi
 sleep 10
 done < "$devices"
done
}

stop-service() {
processID=$(ps aux | grep './services.sh start' | grep -v grep | awk '{print $2}')
if [ -z "$processID" ]
then
 echo "The service is not running. Nothing to do."
 exit 1
else
 echo "Are you sure you want to stop the listening service? Yes/No"
 select yn in "Yes" "No"; do
	case $yn in
		Yes ) 
		kill-service "$processID"
		echo "Do you also wish to destroy the devices containers? Yes/No"
		select yn in "Yes" "No"; do
		        case $yn in
			        Yes ) destroy-containers;;
				No ) echo "Closing..."
				 sleep 2
				 exit;;
			     esac
		      done
		exit;;
		No )
		 echo "Listening service not stopped. Closing..."
		 sleep 2
		 exit;;
	esac
 done
fi
}

kill-service() {
 kill -9 "$1"
 echo "Listening service stopped".
}

destroy-containers() {
 docker stop "$(docker ps -aqf "name=^ios_device_")"
 docker rm "$(docker ps -aqf "name=^ios_device_")"
 echo "Containers stopped and removed. Closing..."
 sleep 2
 exit
}

#======================ADD DEVICE TO LIST FUNCTIONS==========================#
#============================================================================#

add-device() {
if ! [ -s configs/devices.txt ]
then
 addFirstDevice
else
 addAdditionalDevice
fi
}

#This method lists the UDIDs of all connected real devices with selection
udidSelectionList(){
 devices_array=()
 IFS=$'\n' 
 read -r -d '' -a devices_array < <( ./gidevice list)
 echo "Select device from the list of connected devices: "
 select device in "${devices_array[@]}"; do
 #Read the device UDID based on the selection from the list
 device_udid=$(echo "$device" | cut -d ' ' -f 1)
 #Read the device OS version based on the selection from the list
 os_version=$(echo "$device" | awk -F'[()]' '{print $2}' | sed 's/v//')
 break
 done
}

#Method for adding the first device to devices.txt
addFirstDevice(){
 device_name=""
 device_udid=""
 os_version=""
 
 #Read non-hardcoded values from user input
 #Input and read device name
 read -p "Enter your device name: " -r device_name
 #If there is no input or the input contains spaces, reject it and ask again
 while :
 do
 if [[ -z "$device_name" ]]; then
 read -p "Invalid input, device name cannot contain spaces and cannot be empty. Enter your device name again: " -r device_name
 else
 case ${device_name} in
    *\ *) read -p "Invalid input, device name cannot contain spaces and cannot be empty. Enter your device name again: " -r device_name;;
    *) break;;
 esac
 fi
 done
 
 #List the UDIDs of all connected real devices with selection
 #TO DO find a way to show more information on the devices if possible
 udidSelectionList

 #Write the device to the devices.txt file
 echo "$device_name | $os_version | $device_udid | 4841 | 20001 | 20002 " >> configs/devices.txt
}

#Method for adding additional devices to devices.txt
addAdditionalDevice(){
 device_name=""
 device_udid=""
 os_version=""
 
 #Get the number of lines in the devices file if not empty
 numberOfLines=$(wc -l < configs/devices.txt)
 
 #Increment appium port based on number of lines (devices)
 appium_port="$((4840 + $numberOfLines + 1))"
 
 #Increment wda port based on number of lines (devices)
 wda_port="$((20000 + $numberOfLines + 1))"

 #Increment mjpeg port based on number of lines (devices)
 mjpeg_port="$((20100 + $numberOfLines + 1))"
 
 #Read non-hardcoded values from user input
 #Input and read device name
 read -p "Enter your device name: " -r device_name
 while :
 do
 if [[ -z "$device_name" ]]; then
 read -p "Invalid input, device name cannot contain spaces and cannot be empty. Enter your device name again: " -r device_name
 else
 case ${device_name} in
    *\ *) read -p "Invalid input, device name cannot contain spaces and cannot be empty. Enter your device name again: " -r device_name;;
    *) break;;
 esac
 fi
 done
 
 #Input and read device UDID
 #TO DO find a way to directly select UDID from the list instead of copy-paste
 udidSelectionList

 #Check if device is already in the devices.txt file list
 devicePresentCheck=$(cat configs/devices.txt | grep ${device_udid})
 if [ -z "$devicePresentCheck" ]
 then
  #Write to the devices file the first daevice
  echo "$device_name | $os_version | $device_udid | $appium_port | $wda_port | $mjpeg_port " >> configs/devices.txt
 else
  echo "The selected device from the list is already added in devices.txt"
  udidSelectionList
 fi
}


#====================SETUP DEPENDENCIES FUNCTIONS=====================#
#=====================================================================#

setup_developer_disk_images() {
 git clone https://github.com/shamanec/iOS-DeviceSupport.git DeveloperDiskImages
 cd DeveloperDiskImages/DeviceSupport
 unzip "*.zip"
 rm *.zip
}

#Build Docker image
docker-build() {
 docker build -t go-ios-docker .
}

#Delete Docker image from local repo
 remove-docker-image() {
 docker rmi "$(docker images -q go-ios-docker)"
}

#Install Docker and allow for commands without sudo - tested on Ubuntu 18.04.5 LTS
install-dependencies() {
 echo "You are about to install Docker, do you wish to continue? Yes/No"
 select yn in "Yes" "No"; do
  case $yn in
    Yes )
      installDocker
		  echo "You are about to allow Docker commands without sudo, do you wish to continue? Yes/No"
		  select yn in "Yes" "No"; do
			  case $yn in
				      Yes ) executeDockerNoSudo
					          break;;
				       No ) break;;
			  esac
			done
		  break;;
	   No ) break;;
  esac
 done
 echo "You are about to install unzip util, do you wish to continue? Yes/No"
 select yn in "Yes" "No"; do
	case $yn in
		Yes ) sudo apt-get update -y && sudo apt-get install -y unzip
			exit;;
		No ) exit;;
	esac
 done
 mkdir logs
 mkdir ipa
}

#INSTALL DOCKER - tested on Ubuntu 18.04.5 LTS
installDocker(){
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
executeDockerNoSudo(){
 #Add your username to docker group
 sudo usermod -aG docker "${USER}"
 #Confirm the user is added with:
 id -nG
}


#=======================BACKUP AND RESTORE=========================#
#==================================================================#

backup() {
 if [ ! -d "$(pwd)/backup" ]
 then
	mkdir backup
	mkdir backup/configs
 fi
 echo "Please select which project files to backup: "
 options=("All files" "services.sh" "Dockerfile" "configs/wdaSync.sh" "configs/nodeconfiggen.sh" "configs/env.txt" "configs/devices.txt")
 select opt in "${options[@]}"
 do
	case $opt in
		"All files")
			cp services.sh backup/services.sh \
			&& cp Dockerfile backup/Dockerfile \
			&& cp -r configs/* backup/configs
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
		*) echo "Invalid option selected. Please try again.."
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
 select opt in "${options[@]}"
 do
	case $opt in
		"All files")
			if [ ! -d "$(pwd)/backup" ]
 			then
  			echo "Backup folder does not exist, nothing restored. Closing..."
  			sleep 2
  			exit 0
 			fi
			check-file-existence "$(pwd)/backup"
			cp backup/services.sh services.sh \
			&& cp backup/Dockerfile Dockerfile \
			&& cp -r backup/configs/* configs 
			;;
		"backup/services.sh")
			check-file-existence "backup/services.sh"
			restore-file "$opt" services.sh
			;;
		"backup/Dockerfile")
			check-file-existence "backup/Dockerfile"
			restore-file "$opt" Dockerfile
			;;
		"backup/configs/wdaSync.sh")
			check-file-existence "backup/configs/wdaSync.sh"
			restore-file "$opt" configs/wdaSync.sh
			;;
		"backup/configs/nodeconfiggen.sh")
			check-file-existence "backup/configs/nodeconfiggen.sh"
			restore-file "$opt" configs/nodeconfiggen.sh
			;;
		"backup/configs/env.txt")
			check-file-existence "backup/configs/env.txt"
			restore-file "$opt" configs/env.txt
			;;
		"backup/configs/devices.txt")
			check-file-existence "backup/configs/devices.txt"
			restore-file "$opt" configs/devices.txt
			;;
		*) echo "Invalid option selected. Please try again.."
	esac
 break
 done
 echo "Files restored. Closing..."
 sleep 1
}

check-file-existence() {
 fileName=$1
 if [ ! -f "$fileName" ]
 then
  echo "$fileName does not exist, nothing restored. Closing..."
  sleep 2
  exit 0
 fi
}

restore-file() {
 backUpFilePath=$1
 targetPath=$2
 cp "$backUpFilePath" "$targetPath"
}


#==========================HELP==========================#
#========================================================#
echo_help() {
    echo "
      Usage: ./services.sh [option]
      Flags:
          -h    Print help
      Arguments:
          start                Starts the device listener which creates/destroys containers upon connecting/disconnecting
	  start-no-grid        Starts the device listener which creates containers that do not register Appium servers on Selenium Grid
          stop  	       Stops the device listener. Also provides option to destroy containers after stopping service.
          add-device	       Allows to add a device to devices.txt file automatically from connected devices
          restart-container    Allows to restart a container by providing the device UDID - TODO
	  create-container     Allows to start a single container without the listening service by providing the device UDID - TODO
          destroy-containers   Stops and removes all iOS device containers
	  setup-disk-images    Clones the developer disk images for iOS 13&14 and unzips them to mount to containers
	  build-image	       Creates a Docker image called 'ios-appium' based on the Dockerfile
          remove-image	       Removes the 'ios-appium' Docker image from the local repo
	  install-dependencies Install the neeeded dependencies to use the project - currently only Docker and unzip. Tested on Ubuntu 18.04.5
	  setup		       Provide Selenium Hub Host and Port if connecting to Selenium Grid. Provide WDA bundleId.
          backup               Backup all or particular project files before working on them.
          restore              Restore files from backup"
      exit 0
}


#=======================MAIN SCRIPT=======================#
#=========================================================#
case "$1" in
   start)
      start-service >> "logs/deviceSync.txt" 2>&1 &
      ;;
   start-no-grid)
      start-service no-grid >> "logs/deviceSync.txt" 2>&1 &
      ;;
   stop)
      stop-service
      ;;
   add-device)
      add-device
      ;;
   restart-container)
      echo "Functionality pending development."
      sleep 3
      exit 0
      ;;
   create-container)
      echo "Functionality pending development."
      sleep 3
      exit 0
      ;;
   destroy-containers)
      destroy-containers
      ;;
   setup-disk-images)
      setup_developer_disk_images
      ;;
   build-image)
      docker-build
      ;;
   remove-image)
      remove-docker-image
      ;;
   install-dependencies)
      install-dependencies
      ;;
   setup)
      setup
      ;;
   backup)
      backup
      ;;
   restore)
      restore
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


