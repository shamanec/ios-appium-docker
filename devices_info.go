package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
	"os/exec"
	"strconv"

	"github.com/gorilla/mux"
)

// Get the respective device logs based on log type
func GetDeviceLogs(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/plain")

	// Get the parameters
	vars := mux.Vars(r)
	key := vars["log_type"]
	key2 := vars["device_udid"]
	// Execute the command to restart the container by container ID
	commandString := "tail -n 1000 ./logs/*" + key2 + "/" + key + ".txt"
	cmd := exec.Command("bash", "-c", commandString)
	var out bytes.Buffer
	cmd.Stdout = &out
	err := cmd.Run()
	if err != nil {
		fmt.Fprintf(w, "No logs of this type available for this container.")
	}

	fmt.Fprintf(w, out.String())
}

func ReturnDeviceInfo(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	key := vars["device_udid"]

	// Open our jsonFile
	jsonFile, err := os.Open("./configs/config.json")

	// if os.Open returns an error then handle it
	if err != nil {
		fmt.Println(err)
	}

	// defer the closing of our jsonFile so that we can parse it later on
	defer jsonFile.Close()

	byteValue, _ := ioutil.ReadAll(jsonFile)

	// we initialize the devices array
	var devices Devices

	// we unmarshal our byteArray which contains our
	// jsonFile's content into 'users' which we defined above
	json.Unmarshal(byteValue, &devices)

	w.Header().Set("Content-Type", "text/plain")

	// Loop over the devices and return info only on the device which UDID matches the path key
	for i := 0; i < len(devices.Devices); i++ {
		if devices.Devices[i].DeviceUDID == key {
			fmt.Fprintf(w, "Device Name: "+devices.Devices[i].DeviceName+"\n")
			fmt.Fprintf(w, "Appium Port: "+strconv.Itoa(devices.Devices[i].AppiumPort)+"\n")
			fmt.Fprintf(w, "Device OS version: "+devices.Devices[i].DeviceOSVersion+"\n")
			fmt.Fprintf(w, "Device UDID: "+devices.Devices[i].DeviceUDID+"\n")
			fmt.Fprintf(w, "WDA Mjpeg port: "+strconv.Itoa(devices.Devices[i].WdaMjpegPort)+"\n")
			fmt.Fprintf(w, "WDA Port: "+strconv.Itoa(devices.Devices[i].WdaPort)+"\n")
		}
	}
}
