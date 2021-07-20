FROM ubuntu:latest
#Setup libimobile device, usbmuxd and some tools 
RUN apt-get update && apt-get -y install unzip  wget curl libimobiledevice-utils libimobiledevice6 usbmuxd

#Grab gidevice from github and extract it in a folder
RUN wget https://github.com/electricbubble/gidevice-cli/releases/download/v0.5.1/gidevice-cli_0.5.1_Linux_64bit.tar.gz
RUN mkdir gidevice
RUN tar -xvf gidevice-cli_0.5.1_Linux_64bit.tar.gz -C gidevice

#Setup nvm and install latest appium
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | bash
RUN export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && \
     . "$NVM_DIR/nvm.sh" && nvm install 12.22.3 && \
    nvm alias default 12.22.3 && \
    npm config set user 0 && npm config set unsafe-perm true && npm install -g appium

#Copy scripts and WDA ipa to the image
COPY configs/wdaSync.sh /opt/wdaSync.sh
COPY configs/configgen.sh /opt/configgen.sh
COPY WebDriverAgent.ipa /opt/WebDriverAgent.ipa
COPY configs/device_sync.sh / 
ENTRYPOINT ["/bin/bash","-c","/device_sync.sh"]
