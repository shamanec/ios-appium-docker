#!/bin/bash
# set up nodeJS with nvm
export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

echo "Attempting to run WDA script on UDID: $DEVICE_UDID, STF PORT: $WDA_PORT, MJPEG PORT: $MJPEG_PORT"
./opt/wdaSync.sh >> "/opt/wdaSync.txt"
