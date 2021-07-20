#!/bin/bash
# set up nodeJS with nvm
export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

./opt/wdaSync.sh
