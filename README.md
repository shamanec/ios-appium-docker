---

## Clone the project

## Prepare WebDriverAgent.ipa file

You need an Apple Developer account to build **WebDriverAgent**

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

---

## Prepare wdaSync file
1. Open the **configs/wdaSync.sh** file
2. Change the **'wdaBundleID'** value to the bundle ID you used to build WebDriverAgent.ipa.
3. Save the file.

## Prepare devices file
1. Execute **./gidevice list**
2. Get the UDIDs of all currently connected devices.
3. Open(create) the **configs/devices.txt** file.
4. Add each device using the same format, each on separate line:
**Device name | Device OS version | Device UDID | Appium port | WDA port | WDA Mjpeg port**  
iPhone_7|13.4|00008030001E19DC3CE9802E|4841|20001|20002
5. Use unique ports for Appium, WDA port and Mjpeg port for each device.

## or alternatively add device to the file using the script from list of connected devices
1. Execute **./services.sh add-device**
2. Type device name
3. Select device from list of connected devices.
4. It will be automatically added to the list in *devices.txt*

## Create the docker image
1. Run **'docker build -t ios-appium .'**
2. Wait for the image to be created.

## Prepare the Developer Disk Images

1. Execute **./services.sh setup-disk-images**

This will clone the developer disk images repository and unzip the disk images for each supported version in the respective folders.

## Start the devices listener script
1. Execute **./services.sh start**
2. Observe *logs/deviceSync.txt* - you'll notice information about the devices connections and containers availability.
3. You will find a log file for each separate device container in *logs/* in the format *container_$deviceName_$device_udid*

## Kill the devices listener script
1. Execute **./services.sh stop**
2. Confirm you want to stop the service and optionally destroy device containers

You can destroy all device containers easily later (if you opt not to when stopping service) using **./services.sh destroy-containers**

## Connect the devices to the machine (if not already connected)
1. Run **docker ps -a | grep iPhone**
2. You should see a container for each connected device that is listed in *devices.txt*
3. You should see WebDriverAgent installed on each of the connected devices.

## Add test IPA files
1. Copy and paste your test IPA file in the *ipa/* folder.
2. You can access and provide the IPA files to Appium using the following capability: \n
{"app": "opt/fileName.ipa"}

## Make an Appium connection
1. Open Appium Desktop for example.
2. Open the *Start new session window* screen.
3. Provide *localhost* and the Appium port of the device you want to connect to.
4. Provide **bundleId** capability with *com.apple.Preferences* for example.
5. Start the session - you should successfully connect to the iOS device and will be able to inspect or interact with applications.
