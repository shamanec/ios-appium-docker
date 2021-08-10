FROM ubuntu:latest
#Setup libimobile device, usbmuxd and some tools 
RUN export DEBIAN_FRONTEND=noninteractive && apt-get update && apt-get -y install unzip  wget curl libimobiledevice-utils libimobiledevice6 usbmuxd cmake git build-essential python

#Grab gidevice from github and extract it in a folder
RUN wget https://github.com/electricbubble/gidevice-cli/releases/download/v0.5.1/gidevice-cli_0.5.1_Linux_64bit.tar.gz
RUN mkdir gidevice
RUN tar -xvf gidevice-cli_0.5.1_Linux_64bit.tar.gz -C gidevice

#Setup nvm and install latest appium
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | bash
RUN export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && \
     . "$NVM_DIR/nvm.sh" && nvm install 12.22.3 && \
    nvm alias default 12.22.3 && \
    npm config set user 0 && npm config set unsafe-perm true && npm install -g appium appium-doctor opencv4nodejs

#Copy scripts and WDA ipa to the image
COPY configs/nodeconfiggen.sh /opt/nodeconfiggen.sh
COPY WebDriverAgent.ipa /opt/WebDriverAgent.ipa
COPY configs/wdaSync.sh / 
ENTRYPOINT ["/bin/bash","-c","/wdaSync.sh"]
