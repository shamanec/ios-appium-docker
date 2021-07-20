#!/bin/bash

#Start the WebDriverAgent on specific WDA and MJPEG ports
start-wda-gidevice() {
echo "Attempting to start WDA service on device"
echo "Running ./gidevice/gidevice -u $DEVICE_UDID xctest $WDA_BUNDLEID --env=USE_PORT=$WDA_PORT --env=MJPEG_SERVER_PORT=$MJPEG_PORT" 
./gidevice/gidevice -u $DEVICE_UDID xctest $WDA_BUNDLEID --env=USE_PORT=$WDA_PORT --env=MJPEG_SERVER_PORT=$MJPEG_PORT > "/opt/logs/wdaLogs.txt" 2>&1 &
sleep 5
} >> "/opt/logs/wdaLogs.txt"

#Kill the WebDriverAgent app if running on the device
kill-wda() {
echo "Attempting to kill WDA app on device"
./gidevice/gidevice -u $DEVICE_UDID kill $WDA_BUNDLEID
sleep 2
} >> "/opt/logs/wdaLogs.txt"

#Uninstall the WebDriverAgent app from the device
uninstall-wda() {
echo "Uninstalling WDA application on device if present"
./gidevice/gidevice -u $DEVICE_UDID uninstall $WDA_BUNDLEID
sleep 2
} >> "/opt/logs/wdaLogs.txt"

#Install the WebDriverAgent app on the device
install-wda() {
echo "Installing WDA application on device"
./gidevice/gidevice -u $DEVICE_UDID install /opt/WebDriverAgent.ipa
sleep 2
} >> "/opt/logs/wdaLogs.txt"

start-wda() {
    echo "WDA service is not running/accessible. Attempting to start/restart WDA service..."
    uninstall-wda
    install-wda
    start-wda-gidevice
    #Parse the device IP address from the WebDriverAgent logs using the ServerURL
    deviceIP=`grep "ServerURLHere->" "/opt/logs/wdaLogs.txt" | cut -d ':' -f 5`
} >> "/opt/logs/wdaLogs.txt"

#Hit WDA status URL and if service not available start it again
check-wda-status() {
if curl -Is "http:$deviceIP:$WDA_PORT/status" | head -1 | grep '200 OK'
then
 echo >&2 "WDA is up and running"
 sleep 10
else
 start-wda
 if curl -Is "http://127.0.0.1:${APPIUM_PORT}/wd/hub/status" | head -1 | grep '200 OK'
 then
  echo "Appium is already running. Nothing to do"
 else
  start-appium
 fi
fi
} >> "/opt/logs/wdaLogs.txt"

#Start appium server for the device
start-appium() {
appium -p $APPIUM_PORT --udid "$DEVICE_UDID" \
--log-timestamp \
--default-capabilities \
'{"mjpegServerPort": '${MJPEG_PORT}', "clearSystemFiles": "false", "webDriverAgentUrl":"'http:$deviceIP:${WDA_PORT}'", "preventWDAAttachments": "true", "simpleIsVisibleCheck": "true", "wdaLocalPort": "'${WDA_PORT}'", "platformVersion": "'${DEVICE_OS_VERSION}'", "automationName":"XCUITest", "platformName": "iOS", "deviceName": "${DEVICE_NAME}", "wdaLaunchTimeout": "120000", "wdaConnectionTimeout": "240000"}' \
--nodeconfig /opt/nodeconfig.json >> "/opt/logs/appiumLogs.txt"
}

#Mount the respective Apple Developer Disk Image for the current device OS version
mount-disk-images() {
major_device_version=$(echo "$DEVICE_OS_VERSION" | cut -f1,2 -d '.')
echo "The major device version is $major_device_version"
echo "Mounting from ./gidevice/gidevice -u $DEVICE_UDID mount /opt/DeveloperDiskImages/$major_device_version/DeveloperDiskImage.dmg /opt/DeveloperDiskImages/$major_device_version/DeveloperDiskImage.dmg.signature"
./gidevice/gidevice -u $DEVICE_UDID mount /opt/DeveloperDiskImages/$major_device_version/DeveloperDiskImage.dmg /opt/DeveloperDiskImages/$major_device_version/DeveloperDiskImage.dmg.signature
} >> "/opt/logs/wdaLogs.txt"

./opt/configgen.sh > /opt/nodeconfig.json
mount-disk-images
while true
do
check-wda-status
done
