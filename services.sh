#!/bin/bash


startContainer() {
 echo "================================================================"
 echo "Starting container for device $deviceName with UDID: $udid."
 docker run --name "device_$deviceName-$udid" \
	-p "$appium_port":"$appium_port" \
	-p "$wda_port":"$wda_port" \
	-p "$mjpeg_port":"$mjpeg_port" \
	-e DEVICE_UDID="$udid" \
	-e WDA_PORT="$wda_port" \
	-e MJPEG_PORT="$mjpeg_port" \
	-e APPIUM_PORT="$appium_port" \
	-e DEVICE_OS_VERSION="$osVersion" \
	-e DEVICE_NAME="$deviceName" \
	-e SELENIUM_HUB_HOST=172.18.0.1 \
	-e SELENIUM_HUB_PORT=4444 \
	-v /var/run/usbmuxd:/var/run/usbmuxd \
	-v /var/lib/lockdown:/var/lib/lockdown \
	-v "$(pwd)"/DeveloperDiskImages/DeviceSupport:/opt/DeveloperDiskImages \
	-v "$(pwd)"/ipa:/opt/ipa \
	-v "$(pwd)"/stf:/opt/stf \
	ios-appium >> "logs/container_$deviceName-$udid.txt" 2>&1 &
}

start-service() {
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
   echo "The UDID is $udid"
   echo "Device with Name: $deviceName, OS Version: $osVersion and UDID: $udid is not connected to the machine."
   containerOutput=$(docker ps -a | grep "$udid")
   if [ -z "$containerOutput" ]
   then
    echo "No leftover container for this device to kill"
   else
    echo "Killing leftover container for disconnected device with Name: $deviceName and UDID: $udid"
    containerID=$(docker ps -aqf "name=^device_")
    docker stop "$containerID"
    docker rm "$containerID"
  fi
  else
   containerOutput=$(docker ps -a | grep "$udid")
   if [ -z "$containerOutput" ]
   then
   startContainer
   else
    echo "================================================================"
    echo "There is a container already running for device $deviceName with UDID: $udid. Nothing to do."
   fi
  fi
 sleep 10
 done < "$devices" >> "logs/deviceSync.txt" 2>&1
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
		kill-service $processID
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
kill -9 $1
echo "Listening service stopped".
}

destroy-containers() {
docker stop $(docker ps -aqf "name=^device_")
docker rm $(docker ps -aqf "name=^device_")
echo "Containers stopped and removed. Closing..."
sleep 2
exit
}

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
 select device in ${devices_array[@]}; do
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
 device_type=""
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
 device_type=""
 os_version=""
 
 #Get the number of lines in the devices file if not empty
 numberOfLines=$(wc -l < configs/devices.txt)
 
 #Using this line because for some reason I can't use the initial value for the number of lines
 lineIndex=$(echo "$(expr $numberOfLines)" | bc -l)
 
 #Increment appium port based on number of lines (devices)
 appium_port=$(expr 4840 + $numberOfLines + 1)
 
 #Increment wda port based on number of lines (devices)
 wda_port=$(expr 20001 + $numberOfLines + 2)

 #Increment mjpeg port based on number of lines (devices)
 mjpeg_port=$(expr 20001 + $numberOfLines + 3)
 
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

setup_developer_disk_images() {
git clone https://github.com/shamanec/iOS-DeviceSupport.git DeveloperDiskImages
cd DeveloperDiskImages/DeviceSupport
unzip "*.zip"
rm *.zip
}

#Build Docker image
docker-build() {
docker build -t ios-appium .
}

#Delete Docker image from local repo
remove-docker-image() {
docker rmi $(docker images -q ios-appium)
}

echo_help() {
    echo "
      Usage: ./services.sh [option]
      Flags:
          -h    Print help
      Arguments:
          start               Starts the device listener which creates/destroys containers upon connecting/disconnecting
          stop  	      Stops the device listener. Also provides option to destroy containers after stopping service.
          add-device	      Allows to add a device to devices.txt file automatically from connected devices
          restart-container   Allows to restart a container by providing the device UDID
          destroy-containers  Stops and removes all iOS device containers
	  build-image	      Creates a Docker image called 'ios-appium' based on the Dockerfile
          remove-image	      Removes the 'ios-appium' Docker image from the local repo
          backup              Backup the files before working on the implementation
          restore             Restore files from backup"
      exit 0
}

case "$1" in
   start)
      start-service
      ;;
   stop)
      stop-service
      ;;
   add-device)
      add-device
      ;;
   restart-container)
      restart-container
      ;;
   backup)
      backup
      ;;
   restore)
      restore
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
   -h)
      echo_help
      ;;
   *)
      echo "Invalid option detected: $1"
      echo_help
      exit 1
      ;;
esac


