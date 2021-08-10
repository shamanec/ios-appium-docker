#!/bin/bash

#Start the WebDriverAgent on specific WDA and MJPEG ports
start-wda-gidevice() {
 echo "[$(date +'%d/%m/%Y %H:%M:%S')] Starting WebDriverAgent application on port $WDA_PORT"
 ./gidevice/gidevice -u $DEVICE_UDID xctest $WDA_BUNDLEID --env=USE_PORT=$WDA_PORT --env=MJPEG_SERVER_PORT=$MJPEG_PORT > "/opt/logs/wdaLogs.txt" 2>&1 &
}

#Kill the WebDriverAgent app if running on the device
kill-wda() {
 echo "[$(date +'%d/%m/%Y %H:%M:%S')] Attempting to kill WDA app on device"
 ./gidevice/gidevice -u $DEVICE_UDID kill $WDA_BUNDLEID
 sleep 2
}

#Uninstall the WebDriverAgent app from the device
uninstall-wda() {
 echo "[$(date +'%d/%m/%Y %H:%M:%S')] Uninstalling WDA application on device if present"
 if ./gidevice/gidevice applist -u $DEVICE_UDID | grep $WDA_BUNDLEID
 then
 ./gidevice/gidevice -u $DEVICE_UDID uninstall $WDA_BUNDLEID
 sleep 2
 fi
}

#Install the WebDriverAgent app on the device
install-wda() {
 echo "[$(date +'%d/%m/%Y %H:%M:%S')] Installing WDA application on device"
 ./gidevice/gidevice -u $DEVICE_UDID install /opt/WebDriverAgent.ipa
 sleep 2
}

#Start the WDA service on the device using the WDA bundleId
start-wda() {
 deviceIP=""
 echo "[$(date +'%d/%m/%Y %H:%M:%S')] WDA service is not running/accessible. Attempting to start/restart WDA service..."
 uninstall-wda
 install-wda
 start-wda-gidevice
 #Parse the device IP address from the WebDriverAgent logs using the ServerURL
 while [ -z "$deviceIP" ]
 do
  deviceIP=`grep "ServerURLHere->" "/opt/logs/wdaLogs.txt" | cut -d ':' -f 5`
 sleep 3
 done
}

#Hit WDA status URL and if service not available start it again
check-wda-status() {
 if curl -Is "http:$deviceIP:$WDA_PORT/status" | head -1 | grep -q '200 OK'
  then
    echo "[$(date +'%d/%m/%Y %H:%M:%S')] WDA is up and running. Nothing to do"
    sleep 10
  else
    kill-wda
    start-wda
 fi
 if curl -Is "http://127.0.0.1:${APPIUM_PORT}/wd/hub/status" | head -1 | grep -q '200 OK'
     then
      echo "[$(date +'%d/%m/%Y %H:%M:%S')] Appium is already running. Nothing to do"
     else
      start-appium
 fi
}

#Start appium server for the device
start-appium() {
 if [ ${ON_GRID} == "true" ]
  then
   appium -p $APPIUM_PORT --udid "$DEVICE_UDID" \
   --log-timestamp \
   --default-capabilities \
   '{"mjpegServerPort": '${MJPEG_PORT}', "clearSystemFiles": "false", "webDriverAgentUrl":"'http:$deviceIP:${WDA_PORT}'", "preventWDAAttachments": "true", "simpleIsVisibleCheck": "true", "wdaLocalPort": "'${WDA_PORT}'", "platformVersion": "'${DEVICE_OS_VERSION}'", "automationName":"XCUITest", "platformName": "iOS", "deviceName": "'${DEVICE_NAME}'", "wdaLaunchTimeout": "120000", "wdaConnectionTimeout": "240000"}' \
   --nodeconfig /opt/nodeconfig.json >> "/opt/logs/appiumLogs.txt" 2>&1 &
  else
   appium -p $APPIUM_PORT --udid "$DEVICE_UDID" \
   --log-timestamp \
   --default-capabilities \
   '{"mjpegServerPort": '${MJPEG_PORT}', "clearSystemFiles": "false", "webDriverAgentUrl":"'http:$deviceIP:${WDA_PORT}'",  "preventWDAAttachments": "true", "simpleIsVisibleCheck": "true", "wdaLocalPort": "'${WDA_PORT}'", "platformVersion": "'${DEVICE_OS_VERSION}'", "automationName":"XCUITest", "platformName": "iOS", "deviceName": "'${DEVICE_NAME}'", "wdaLaunchTimeout": "120000", "wdaConnectionTimeout": "240000"}'  >> "/opt/logs/appiumLogs.txt" 2>&1 &
 fi
}

#Mount the respective Apple Developer Disk Image for the current device OS version
mount-disk-images() {
 major_device_version=$(echo "$DEVICE_OS_VERSION" | cut -f1,2 -d '.')
 ./gidevice/gidevice -u $DEVICE_UDID mount /opt/DeveloperDiskImages/$major_device_version/DeveloperDiskImage.dmg /opt/DeveloperDiskImages/$major_device_version/DeveloperDiskImage.dmg.signature
}


export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
#Only generate nodeconfig.json if the device will be registered on Selenium Grid
if [ ${ON_GRID} == "true" ]
 then
  ./opt/nodeconfiggen.sh > /opt/nodeconfig.json
fi
mount-disk-images >> "/opt/logs/wdaSync.txt"
while true
 do
  check-wda-status >> "/opt/logs/wdaSync.txt"
 done
