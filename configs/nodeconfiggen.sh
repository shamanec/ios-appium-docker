#!/bin/bash

cat << EndOfMessage
{
  "capabilities":
      [
        {
          "browserName": "${DEVICE_NAME}",
          "version":"${DEVICE_OS_VERSION}",
          "maxInstances": 1,
          "platform":"iOS",
	  "deviceName": "${DEVICE_NAME}",
          "deviceType": "phone",
          "platformName":"iOS",
          "platformVersion":"${DEVICE_OS_VERSION}",
	  "udid": "${DEVICE_UDID}"
        }
      ],
  "configuration":
  {
    "url":"http://10.8.0.3:${APPIUM_PORT}/wd/hub",
    "port": ${APPIUM_PORT},
    "host": "10.8.0.3",
    "hubPort": ${SELENIUM_HUB_PORT},
    "hubHost": "${SELENIUM_HUB_HOST}",
    "timeout": 180,
    "maxSession": 1,
    "register": true,
    "registerCycle": 5000,
    "automationName": "XCUITest",
    "downPollingLimit": 10,
    "hubProtocol": "http"
  }
}
EndOfMessage
