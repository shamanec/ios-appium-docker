## env.txt

 * This file contains the SELENIUM_HUB_HOST, SELENIUM_HUB_PORT, DEVICES_HOST_IP, HUB_PROTOCOL and WDA_BUNDLE_ID variables.
 * SELENIUM_HUB_HOST, SELENIUM_HUB_PORT and DEVICES_HOST_IP can be left as is or empty if you are not going to connect to Selenium Grid.
 * SELENIUM_HUB_HOST should be the IP address of the Selenium Grid if you are connecting to one.
 * SELENIUM_HUB_PORT should be the port of the Selenium Grid if you are connecting to one.
 * HUB_PROTOCOL should be 'http' or 'https' if you are connecting to Selenium Grid depending on your setup.
 * DEVICES_HOST_IP should be the IP address of the current machine that will provide the devices if you are connecting to Selenium Grid.
 * **Important** The Selenium Grid setup was tested on a local network so you might need adjustments in **env.txt**, **nodeconfiggen.sh** script and the *start-container* function in the **services.sh** script depending on your current setup.
 * WDA_BUNDLE_ID can be left as is (cannot guarantee on 100% you will be able to use mine) or provide the bundle ID of the WDA you built yourself.  
 **NOTE** You can update those values through the main script by executing **./services.sh control** and selecting option **4) Setup environment vars**.

## devices.txt

 * In this file you need to provide a list of the devices that you want the listener to check for and create/destroy containers.
 * Each device needs to be added on its own separate line in the file.
 * Each device needs to be added in the following format:  
   **Device name | Device OS version | Device UDID | Appium port | WDA port | WDA Mjpeg port**  
   You can follow the convention of the provided file for the port numbers.
 * Additionally you can add a new device to the file by connecting it to the machine and executing **./services.sh control** from the main script and selecting option **9) Add a device**.

## wdaSync.sh

 * This is the cornerstone of keeping the WebDriverAgent up and running on the device as long as possible or in an ideal scenario - indefinitely as long as the device is working and connected to the machine.
 * Please refer to the diagram below:  
<img src="https://iili.io/RMFEf2.png" width="100%" height="100%">  

 * The script uses [go-ios](https://github.com/danielpaulus/go-ios) to install and run the WebDriverAgent
 * The script also uses the *go-ios* to mount the Developer Disk Images to the device - you should already have them prepared as described in the main project Readme.md
 * The script checks if WDA is up and running by calling **curl -Is "http:$deviceIP:$WDA_PORT/status"**
 * The script checks if Appium is up and running by calling **curl -Is "http://127.0.0.1:${APPIUM_PORT}/wd/hub/status"**
 * Appium is launched using the *webDriverAgentUrl* capability to connect to the already installed and started WDA agent instead of attempting to install it which obviously will not work without Xcode :D
 * Appium is launched with extended *wdaLaunchTimeout* and *wdaConnectionTimeout* capabilities to give the script time to 'restart' WDA in case it crashes and it's no longer available - this in theory should allow for continious test execution without failing tests if the WDA crashes.
