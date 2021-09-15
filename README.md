## Introduction

<img src="https://iili.io/R8cGNj.png" width="50%" height="50%">

 * This is a solution for running Appium tests on real iOS devices on Linux with as easier setup and manual maintenance as possible. The project uses [go-ios](https://github.com/danielpaulus/go-ios) to install and run WebDriverAgent from a prepared *.ipa file.   
 * You can register devices to the project, then start one of the two listeners which check if the devices in the config are connected to the machine and creates/destroys containers automagically.  
 * As you know WebDriverAgent is famous in being unstable, especially in longer test runs so the scripts also check the WebDriverAgent service and restart it if needed allowing for the tests to proceed in case it crashes.  
 * The project was built and tested on Ubuntu 18.04.5 LTS but I suppose all should work as expected on different releases or Linux distros except for the **5) Setup dependencies** control option from the script. Unfortunately I have only one iOS device and can't thoroughly test the container creation/destruction but in theory it should be fine.    
 * You still cannot avoid having at least one(any) Mac machine to build the WebDriverAgent.ipa file.  
 * If you follow this guide step by step you should have no issues running Appium tests on Linux without Xcode in no time.

### Known limitations
1. It is not possible to execute **driver.executeScript("mobile: startPerfRecord")** to record application performance since Xcode tools are not available.  

This is by no means an exhaustive list and there might be more limitations present.

## Clone the project

## Help

1. Execute **./services.sh -h** or **./services.sh** without arguments to see the help section of the main script.
2. The main starting point of the script is the **control** argument which presents a selection of all available options.

## Prepare WebDriverAgent.ipa file

You need an Apple Developer account to sign and build **WebDriverAgent**

1. Open **WebDriverAgent.xcodeproj** in Xcode.
2. Ensure a team is selected before building the application. To do this go to: *Targets* and select each target one at a time. There should be a field for assigning teams certificates to the target.
3. Remove your **WebDriverAgent** folder from *DerivedData* and run *Clean build folder* (just in case)
4. Next build the application by selecting the *WebDriverAgentRunner* target and build for *Generic iOS Device*. Run *Product => Build for testing*. This will create a *Products/Debug-iphoneos* in the specified project directory.  
 *Example*: **/Users/<username>/Library/Developer/Xcode/DerivedData/WebDriverAgent-dzxbpamuepiwamhdbyvyfkbecyer/Build/Products/Debug-iphoneos**
5. Go to the "Products/Debug-iphoneos" directory and run:
 **mkdir Payload**
6. Copy the WebDriverAgentRunner-Runner.app to the Payload directory:
 **cp -r WebDriverAgentRunner-Runner.app Payload**
7. Finally zip up the project as an ipa file:
 **zip -r WebDriverAgent.ipa Payload**
8. Get the WebDriverAgent.ipa file and put it in the current projects main directory.

## Install project usage dependencies - currently Docker, unzip, jq and usbmuxd

1. Execute **./services.sh control** and select option **5) Setup dependencies**
2. This setup will:
 * Install **Docker** and allow for Docker commands without *sudo*
 * Install **unzip** util for setup of the DeveloperDiskImages
 * Install **jq** util for parsing and updating data in the **configs/config.json** file
 * Install **usbmuxd** for communication with iOS devices.
 * Create **logs/** and **ipa/** folders in the main project folder.

 **IMPORTANT** If you don't use this to setup dependencies you need to install all of them yourself and you need to create **logs/** and **ipa/** folders in the main project folder.

## Set up the project environment vars in the configuration file
### Set up the project environment vars using the script (Recommended)
1. Execute **./service.sh control** and select option **4) Setup environment vars**
2. Provide the requested data:
 * Selenium Hub Host(if connecting to Selenium Grid)
 * Selenium Hub port(if connecting to Selenium Grid)
 * devices host IP address(if connecting to Selenium Grid)
 * hub protocol(if connecting to Selenium Grid)
 * WebDriverAgent bundleId (empty bundleId value will use the provided IPA as default).

#### or alternatively

1. Open the **configs/config.json** file.
2. Change the values for each of the 5 keys in the json:  
*selenium_hub_host*  
*selenium_hub_port*  
*devices_host*  
*selenium_hub_protocol_type*  
*wda_bundle_id*  

 **Note** For more information on the fields in the json you can refer to [configs](https://github.com/shamanec/ios-appium-docker/tree/master/configs#configjson)

## Add devices to the configuration file
**Note** You don't need to do this if you are not going to use either of the listeners and will just spin up a single container for testing.  
### Add devices to the configuration file from list of connected devices using the script  (Recommended)

1. Execute **./services.sh control** and select option **9) Add a device**
2. Type device name
3. Select device from list of connected devices.
4. It will be automatically added to the 'devicesList' array in the **config.json** file.

 **Note** Via the script you can only add devices that are connected to the machine.  
 **Note** For more information on the fields in the json you can refer to [configs](https://github.com/shamanec/ios-appium-docker/tree/master/configs#configjson)

#### or alternatively add devices manually to the configuration file
1. Execute **./ios list**
2. Get the UDIDs of all currently connected devices.
3. Open the **configs/config.json** file.
4. Add each device to the 'devicesList' array as a new object keeping the convention of the key-value pairs, order is irrelevant:
{
 "appium_port" : 4842,
 "device_name" : "iPhone_11",
 "device_os_version" : "13.5.1",
 "device_udid" : "00008030000418C136FB8022",
 "wda_mjpeg_port" : 20102,
 "wda_port" : 20002
}
5. Use unique ports for *appium_port*, *wda_port* and *wda_mjpeg_port* for each device.

## Create the docker image

 **Note** If you don't want to use the opencv4nodejs functionalities you can remove it from the installation in the Dockerfile which will reduce the image size with around 2GB and will improve building speed a lot.  

1. Run **'docker build -t ios-appium .'** or execute **./services.sh control** and select option **7) Build Docker image**
2. Wait for the image to be created - it will be named 'ios-appium' by default.

#### Additional docker image notes

1. You can remove the default docker image 'ios-appium' using the script by executing **./services.sh control** and selecting option **8) Remove Docker image**.

## Prepare the Developer Disk images
### Prepare the Developer Disk Images using the script (Recommended)

1. Execute **./services.sh control** and select option **6) Setup developer disk images**  

This will clone the developer disk images repository and unzip the disk images for each supported version in the respective folders.

#### or alternatively if you don't want the disk images in the same folder as the project

1. **git clone https://github.com/shamanec/iOS-DeviceSupport.git** in a folder of your choice.
2. Unzip all the files as is.
3. Open the **services.sh** file and find the **start-container** function.
4. Change the following line '*-v "$(pwd)"/DeveloperDiskImages/DeviceSupport:/opt/DeveloperDiskImages*' to  
'*-v "{folder with the unzipped disk images}":/opt/DeveloperDiskImages*'

## Start a single container to try it out
1. Connect a device to the machine.
2. Execute **./services.sh control** and select option **15) Start single container**
3. You will be presented with a list of the connected devices - select the device for which you want the container created.

* The container will be created with default Appium port 4841 and will not attempt to connect to Selenium Grid.
* The Appium and WDA logs can be found in **container_logs** folder.
* To destroy the container you can execute **./services.sh control** and select option **10) Destroy containers**.

## Polling devices listener script (Recommended)
### Start the polling devices listener script
1. Execute **./services.sh control** and select option **1) Start listener - Grid**
2. Observe *logs/deviceSync.txt* - you'll notice information about the devices connections and containers availability.

#### or alternatively if you won't connect to Selenium Grid
1. Execute **./services.sh control** and select option **2) Start listener - No Grid**
2. This will start the service with Appium servers without attempting Selenium Grid registration for local testing or different setup.

 **Note** You can find the listener logs in *logs/deviceSync.txt*  
 **Note** You will find a log file for each separate device container in *logs/* in the format *container_$deviceName_$device_udid*  
 **Note** For more information on the what happens in the container underneath refer to [configs](https://github.com/shamanec/ios-appium-docker/tree/master/configs#wdasyncsh)

### Connect the devices to the machine
1. Run **docker ps -a | grep ios_device**
2. You should see a container for each connected device that is registered in *config.json*
3. You should see WebDriverAgent installed on each of the connected devices.

### Kill the polling devices listener script
1. Execute **./services.sh control** and select option **3) Stop listener**
2. Confirm you want to stop the service and optionally destroy device containers  
  
You can destroy all device containers easily later (if you opt not to when stopping service) using **./services.sh control** and selecting option **10) Destroy containers**

## Udev listener script (working but not fully finalized, not recommended)
### Start a udev listener script

It is possible to create udev rules listener that will start/stop containers based on udev events instead of polling the connected devices with **go-ios** every few seconds (like the listener from the main script does).

 * **NB** I am more than welcome on suggestions to improve the udev listener.

1. Execute **./services.sh control** and select option **13) Start udev listener**  
This will create the needed udev rules and the script that will be used by them to start/stop the containers, copy them to the respective folders and reload udev.  

 * The main benefit of this approach is that it is not a constantly running script but is something that runs based on system events.
 * The **ios_device2docker** script that starts/stops containers can be found in **/usr/local/bin**
 * The **39-usbmuxd.rules** and **90-usbmuxd.rules** that trigger on events can be found in **/etc/udev/rules.d**

### Connect the devices to the machine
1. Disconnect all devices from the machine and wait for up to a minute - all containers if any should be destroyed - do this step just in case.
2. Connect each device.
3. Run **docker ps -a | grep ios_device**
4. You should see a container for each connected device that is registered in *config.json*
5. You should see WebDriverAgent installed on each of the connected devices.

* To view the udev logs while connecting devices execute **sudo udevadm control --log-priority=debug** and then **tail -f /var/log/syslog**.

### Kill the udev listener script
2. Execute **./services.sh control** and select option **14) Stop udev listener**.  
This will remove the udev rules and script from the respective folders and reload udev.

## Add test IPA files
1. Copy and paste your test IPA file in the **ipa/** folder.
2. You can access and provide the IPA files to Appium using the following capability:  
{"app": "opt/fileName.ipa"}

## Make an Appium connection with Appium Desktop
1. Open Appium Desktop for example.
2. Open the *Start new session window* screen.
3. Provide *localhost* and the Appium port of the device you want to connect to.
4. Provide **bundleId** capability with *com.apple.Preferences* for example.
5. Start the session - you should successfully connect to the iOS device and will be able to inspect or interact with applications.  
[![Appium session](https://iili.io/umx5gV.md.png)](https://freeimage.host/i/umx5gV)

## Demo Java project

This is a small project which targets to demonstrate the ability to use different Appium functionalities with **ios-appium-docker**

1. Clone the [demo-project](https://github.com/shamanec/Java-Appium-iOS-Demo).
2. Execute any/all of the 3 tests in the **Tests.java** class.  
 * **nativeTest()** - executes a simple test against the Preferences app using **Mobile.by.iOSClassChain("")** to identify and interact with an element.
 * **nativeTestWithVideo()** - executes the same test as above but records the test execution and saves it to a video file in */src/main/resources*
 * **nativeImageTest()** - executes a simple test against the Preferences app using **Mobile.by.image("")** and the *opencv4nodejs* library to identify and interact with an element using provided image.
 * **safariTest()** - executes a simple test in the Safari browser

## Backup and restore project files
1. Execute **./services.sh control** and select option **11) Backup project files** - you will be asked if you want to backup all or a particular file. The files will be copied in the main project folder in **backup** folder.
2. Execute **./services.sh control** and select option **12) Restore project files** - you will be asked if you want to restore all or a particular file.

## Notes
1. **NB** This project was created with only one iOS device available so there might be unforeseen issues with installing WDA or mounting images on different iOS releases/devices.

## Thanks

| |About|
|---|---|
|[go-ios](https://github.com/danielpaulus/go-ios)|Many thanks for creating this tool to communicate with iOS devices on Linux, perfect for installing/reinstalling and running WebDriverAgentRunner without Xcode|
