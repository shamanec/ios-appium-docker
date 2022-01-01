#!/bin/bash

#==========================CONTROL FUNCTIONS==========================#
#=====================================================================#
control-function() {
  echo "Please select one of the options below: "
  control_options
  while true; do
    echo "//====================================//"
    echo "Would you like to select another control option?"
    select yn in "Yes" "No"; do
      case $yn in
      Yes)
        echo "Please select one of the options below: "
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
  control_options=("Start listener - Grid" "Start listener - No Grid" "Stop listener" "Setup environment vars" "Setup dependencies" "Setup developer disk images" "Build Docker image" "Remove Docker image" "Add a device" "Destroy containers" "Backup project files" "Restore project files" "Setup udev listener" "Remove udev listener" "Start single container" "Help")
  select option in "${control_options[@]}"; do
    case $option in
    "Start listener - Grid")
      ./listener_script.sh
      break
      ;;
    "Start listener - No Grid")
      ./listener_script.sh no_grid
      break
      ;;
    "Stop listener")
      stop_listener
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
    "Restore project files")
      restore
      break
      ;;
    "Setup udev listener")
      setup_udev
      break
      ;;
    "Remove udev listener")
      remove_udev
      break
      ;;
    "Start single container")
      start_single_container
      break
      ;;
    "Help")
      echo_help
      break
      ;;
    esac
  done
}

#=====================UDEV LISTENER FUNCTIONS===================#
#===============================================================#
#The reason there are 2 separate rules is that I couldn't manage to get usbmuxd successfully running along with the device events
#Maybe I am doing something wrong but if I tried to trigger usbmuxd and the device via the same service file usbmuxd just wouldn't start properly and the device was not accessible to the container
#It might not be a problem if usbmuxd is already running, but it is when connecting first device

#This function creates 90-usbmuxd.rules file that will start containers in case registered device is connected to the machine
create_devices_rules() {
  config_json=$(cat configs/config.json)
  if [[ -f 90-usbmuxd.rules ]]; then
    rm 90-usbmuxd.rules
  fi
  touch 90-usbmuxd.rules
  #Read all the device udids from the config file into an array
  read -r -d '' -a devices_udids < <(echo "$config_json" | jq -r ".devicesList[].device_udid" 2>&1)
  #Create separate line in the service rules for each device added in config.json
  for device_udid in "${devices_udids[@]}"; do
    #We identify the device by serial and manufacturer because they are available when you connect a device
    #This allows us to run the ios_device2docker container creation only if the specific device is added to the machine
    echo "ACTION==\"add\", SUBSYSTEM==\"usb\", ENV{DEVTYPE}==\"usb_device\", ATTR{manufacturer}==\"Apple Inc.\", ATTR{serial}==\"$device_udid\", OWNER=\"$(whoami)\", MODE=\"0666\", RUN+=\"/usr/local/bin/ios_device2docker $device_udid\"" >>90-usbmuxd.rules
  done
  #We execute the ios_device2docker container removal everytime an iOS device is removed from the machine
  #The reason we do it everytime is that the attributes like 'serial' are not available upon disconnecting a device
  echo "SUBSYSTEM==\"usb\", ENV{DEVTYPE}==\"usb_device\", ENV{PRODUCT}==\"5ac/12[9a][0-9a-f]/*|5ac/1901/*|5ac/8600/*\", ACTION==\"remove\", RUN+=\"/usr/local/bin/ios_device2docker\"" >>90-usbmuxd.rules
}

#This function create 39-usbmuxd.rules file that will start usbmuxd if an iOS device is added to the machine
create_usbmuxd_rule() {
  if [[ -f 39-usbmuxd.rules ]]; then
    rm 39-usbmuxd.rules
  fi
  touch 39-usbmuxd.rules
  #We create a service file that starts (or attempts to start) usbmuxd in udev mode everytime an iOS device is connected to the machine
  #This is mostly important upon connecting the first device, for next devices usbmuxd is already running but I couldn't make it work in other way
  echo "SUBSYSTEM==\"usb\", ENV{DEVTYPE}==\"usb_device\", ENV{PRODUCT}==\"5ac/12[9a][0-9a-f]/*|5ac/1901/*|5ac/8600/*\", OWNER=\"$(whoami)\", ACTION==\"add\", RUN+=\"/usr/sbin/usbmuxd -u -v -z\"" >>39-usbmuxd.rules
}

#This function reads the configs/default_ios_device2docker file and creates a new one with the current project dir
generate_ios_device2docker() {
  local project_dir=$(pwd)
  sed -e "s|project_dir|$project_dir|g" configs/default_ios_device2docker >ios_device2docker
}

#This function copies the usbmuxd and devices rules to /etc/udev/rules.d and reloads the udev rules
copy_and_reload_udev_rules() {
  sudo cp 90-usbmuxd.rules /etc/udev/rules.d/
  sudo cp 39-usbmuxd.rules /etc/udev/rules.d/
  sudo chmod 755 /etc/udev/rules.d/90-usbmuxd.rules
  sudo chmod 755 /etc/udev/rules.d/39-usbmuxd.rules
  sudo udevadm control --reload-rules
  rm 90-usbmuxd.rules
  rm 39-usbmuxd.rules
}

#This function completely sets up the udev listener
setup_udev() {
  create_devices_rules
  create_usbmuxd_rule
  copy_and_reload_udev_rules
  generate_ios_device2docker
  sudo cp ios_device2docker /usr/local/bin/ && sudo chmod 755 /usr/local/bin/ios_device2docker
  rm ios_device2docker
}

#This function completely removes the udev listener
remove_udev() {
  sudo rm /etc/udev/rules.d/90-usbmuxd.rules
  sudo rm /etc/udev/rules.d/39-usbmuxd.rules
  sudo udevadm control --reload-rules
  sudo rm /usr/local/bin/ios_device2docker
}

#===============================================================#

#=====================CONTAINER FUNCTIONS=======================#
#===========================================================================#

stop_listener() {
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

#Kill the service by the PID provided as argument 1 when calling it in the above function
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

start_single_container() {
  #Input and read device UDID
  device_selection_list

  wda_bundle_id=$(cat configs/config.json | jq -r ".wda_bundle_id")

  docker run --name "ios_device_$device_udid" \
    -p 4841:4841 \
    -p 20001:20001 \
    -p 20101:20101 \
    -e DEVICE_UDID="$device_udid" \
    -e WDA_PORT="20001" \
    -e MJPEG_PORT="20101" \
    -e APPIUM_PORT="4841" \
    -e DEVICE_OS_VERSION="$os_version" \
    -e DEVICE_NAME="iPhone_Device" \
    -e WDA_BUNDLEID="$wda_bundle_id" \
    -e ON_GRID=false \
    -v /var/run/usbmuxd:/var/run/usbmuxd \
    -v /var/lib/lockdown:/var/lib/lockdown \
    -v "$(pwd)"/DeveloperDiskImages/DeviceSupport:/opt/DeveloperDiskImages \
    -v "$(pwd)"/ipa:/opt/ipa \
    -v "$(pwd)/container_logs":/opt/logs \
    ios-appium >>single_container.txt 2>&1 &
}

#======================ADD DEVICE TO LIST FUNCTIONS==========================#
#============================================================================#

add_device() {
  add_device_to_config
  while true; do
    echo "Would you like to add another device?"
    select yn in "Yes" "No"; do
      case $yn in
      Yes)
        add_device_to_config
        break
        ;;
      No)
        return
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

#Method for adding devices to config.json
add_device_to_config() {
  device_name=""
  device_udid=""
  os_version=""

  #Get the number of registered devices in the config.json file
  number_of_devices=$(cat configs/config.json | jq -r '.devicesList| length')

  #Increment appium port based on number of lines (devices)
  appium_port="$((4840 + $number_of_devices + 1))"

  #Increment wda port based on number of lines (devices)
  wda_port="$((20000 + $number_of_devices + 1))"

  #Increment mjpeg port based on number of lines (devices)
  mjpeg_port="$((20100 + $number_of_devices + 1))"

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

  #Check if device is already in the config.json file list
  devicePresentCheck=$(cat configs/config.json | jq '.devicesList[].device_udid' | grep ${device_udid})
  if [ -z "$devicePresentCheck" ]; then
    #Rewrite the initial json into a new json by injecting the additional device in the 'devicesList' array and store it into variable
    new_json=$(cat <configs/config.json | jq '.' | jq ".devicesList += [{\"device_name\": \"$device_name\", \"device_udid\": \"$device_udid\", \"device_os_version\": \"$os_version\", \"appium_port\": $appium_port, \"wda_port\": $wda_port, \"wda_mjpeg_port\": $mjpeg_port}]" 2>&1)
    #Make the new json prettier and echo it in the config.json file completely rewriting it
    echo $new_json | json_pp -json_opt pretty,canonical >configs/config.json
  else
    echo "The selected device is already registered in the config.json file:"
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
  update_config_json_value selenium_hub_host $hub_host
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
  update_config_json_value selenium_hub_port $hub_port
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
  update_config_json_value devices_host $devices_host
}

add_hub_protocol() {
  echo "Please select the hub protocol: http/https"
  select protocol in "http" "https"; do
    update_config_json_value selenium_hub_protocol_type $protocol
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
  update_config_json_value wda_bundle_id $bundle_id
}

#This function updates key provided with argument 1 to value provided with argument 2 in the config.json
update_config_json_value() {
  config_json=$(cat <configs/config.json)
  echo $config_json | jq ".$1 = \"$2\"" | json_pp -json_opt pretty,canonical >configs/config.json
}

setup_developer_disk_images() {
  #Clone the disk images from the repo into new folder name DeveloperDiskImages
  git clone https://github.com/shamanec/iOS-DeviceSupport.git DeveloperDiskImages
  #Get in to the new folder and unzip all the files
  cd DeveloperDiskImages/DeviceSupport
  unzip "*.zip"
  rm *.zip
}

#Build Docker image with default name
docker_build() {
  docker build -t ios-appium .
}

#Delete Docker image with default name from local repo
remove_docker_image() {
  docker rmi "$(docker images -q ios-appium)"
}

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

  echo "Installing unzip util..."
  sudo apt-get update -y && sudo apt-get install -y unzip

  echo "Installing jq util..."
  sudo apt-get update -y && sudo apt-get install -y jq

  echo "Installing usbmuxd..."
  sudo apt-get install -y usbmuxd

  mkdir logs
  mkdir ipa
}

#tested on Ubuntu 18.04.5 LTS
install_docker() {
  sudo apt update
  #Install prerequisites
  sudo apt install apt-transport-https ca-certificates curl software-properties-common
  #Add GPG key
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  #Add the Docker repository
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
  #Update the packages with the new repo
  sudo apt update
  apt-cache policy docker-ce
  sudo apt install docker-ce
}

execute_docker_no_sudo() {
  #Add your username to docker group
  sudo usermod -aG docker "${USER}"
}

#=======================BACKUP AND RESTORE=========================#
#==================================================================#

backup() {
  if [ ! -d "$(pwd)/backup" ]; then
    mkdir backup
    mkdir backup/configs
  fi
  echo "Please select which project files to backup: "
  options=("All files" "services.sh" "Dockerfile" "configs/wdaSync.sh" "configs/nodeconfiggen.sh" "configs/config.json")
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
    "configs/config.json")
      cp configs/config.json backup/configs/config.json
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
  options=("All files" "backup/services.sh" "backup/Dockerfile" "backup/configs/wdaSync.sh" "backup/configs/nodeconfiggen.sh" "backup/configs/config.json")
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
    "backup/configs/config.json")
      check_file_existence "backup/configs/config.json"
      restore_file "$opt" configs/config.json
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
          control                               Presents a selection of controls that consists of all available options that you can select from
      Control options:
          1) Start listener - Grid              Starts the device listener which creates/destroys containers upon connecting/disconnecting
	  2) Start listener - No Grid           Starts the device listener which creates containers that do not register Appium servers on Selenium Grid
          3) Stop listener  	                Stops the device listener. Also provides option to destroy containers after stopping service
	  4) Setup environment vars		Update the Selenium Grid host, Selenium Grid port, Selenium Grid protocol type, current devices host and WebDriverAgent bundleID in the env.txt file
	  5) Setup dependencies			Install the neeeded dependencies to use the project - currently only Docker and unzip. Tested on Ubuntu 18.04.5
	  6) Setup developer disk images	Clones the developer disk images for iOS 13&14 and unzips them to mount to containers
	  7) Build Docker image			Creates a Docker image called 'ios-appium' based on the Dockerfile by default
	  8) Remove Docker image		Removes the 'ios-appium' Docker image from the local repo
	  9) Add a device			Allows to add a device to config.json file automatically from connected devices
	  10) Destroy containers		Stops and removes all iOS device containers
	  11) Backup project files		Backup all or particular project files before working on them
	  12) Restore project files		Restore files from backup
	  13) Setup udev listener	        Creates udev rules and prepares a new script that will listen on udev events and create/destroy containers instead of polling go-ios
	  14) Remove udev listener	        Removes the udev rules and script from the respective folders and reloads udev
	  15) Start single container		Creates a container with default Appium port 4841 for a device selected from a list(connected to the machine)
	  13) Help				Print this section"
}

#=======================MAIN SCRIPT=======================#
#=========================================================#
case "$1" in
control)
  control-function
  ;;
start)
  start_service >>tests.txt
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
