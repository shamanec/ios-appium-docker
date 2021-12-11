package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"html/template"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"

	"github.com/docker/docker/api/types"
	"github.com/docker/docker/client"
	"github.com/gorilla/mux"
)

// Devices struct which contains
// an array of devices from the config.json
type Devices struct {
	Devices []Device `json:"devicesList"`
}

// Device struct which contains device info
type Device struct {
	AppiumPort      int    `json:"appium_port"`
	DeviceName      string `json:"device_name"`
	DeviceOSVersion string `json:"device_os_version"`
	DeviceUDID      string `json:"device_udid"`
	WdaMjpegPort    int    `json:"wda_mjpeg_port"`
	WdaPort         int    `json:"wda_port"`
}

// ProjectConfig struct which contains the project configuration values
type ProjectConfig struct {
	DevicesHost             string `json:"devices_host"`
	SeleniumHubHost         string `json:"selenium_hub_host"`
	SeleniumHubPort         string `json:"selenium_hub_port"`
	SeleniumHubProtocolType string `json:"selenium_hub_protocol_type"`
	WdaBundleID             string `json:"wda_bundle_id"`
}

type ContainerRow struct {
	ContainerID     string
	ImageName       string
	ContainerStatus string
	ContainerPorts  string
	ContainerName   string
	DeviceUDID      string
}

type ConfigValues struct {
	DevicesList []struct {
		AppiumPort      int    `json:"appium_port"`
		DeviceName      string `json:"device_name"`
		DeviceOsVersion string `json:"device_os_version"`
		DeviceUdid      string `json:"device_udid"`
		WdaMjpegPort    int    `json:"wda_mjpeg_port"`
		WdaPort         int    `json:"wda_port"`
	} `json:"devicesList"`
	DevicesHost             string `json:"devices_host"`
	SeleniumHubHost         string `json:"selenium_hub_host"`
	SeleniumHubPort         string `json:"selenium_hub_port"`
	SeleniumHubProtocolType string `json:"selenium_hub_protocol_type"`
	WdaBundleID             string `json:"wda_bundle_id"`
}

// Function that returns the full list of devices from config.json and their data
func getDevicesList(w http.ResponseWriter, r *http.Request) {
	// Open our jsonFile
	jsonFile, err := os.Open("../configs/config.json")
	// if we os.Open returns an error then handle it
	if err != nil {
		fmt.Println(err)
	}

	fmt.Println("Successfully opened config.json")
	// defer the closing of our jsonFile so that we can parse it later on
	defer jsonFile.Close()

	byteValue, _ := ioutil.ReadAll(jsonFile)

	// we initialize the devices array
	var devices Devices

	// we unmarshal our byteArray which contains our
	// jsonFile's content into 'users' which we defined above
	json.Unmarshal(byteValue, &devices)

	// we iterate through every device within our devices array and
	// print out the data
	for i := 0; i < len(devices.Devices); i++ {
		fmt.Fprintf(w, "========================================= \n")
		fmt.Fprintf(w, "Device Name: "+devices.Devices[i].DeviceName+"\n")
		fmt.Fprintf(w, "========================================= \n")
		fmt.Fprintf(w, "Appium Port: "+strconv.Itoa(devices.Devices[i].AppiumPort)+"\n")
		fmt.Fprintf(w, "Device OS version: "+devices.Devices[i].DeviceOSVersion+"\n")
		fmt.Fprintf(w, "Device UDID: "+devices.Devices[i].DeviceUDID+"\n")
		fmt.Fprintf(w, "WDA Mjpeg port: "+strconv.Itoa(devices.Devices[i].WdaMjpegPort)+"\n")
		fmt.Fprintf(w, "WDA Port: "+strconv.Itoa(devices.Devices[i].WdaPort)+"\n")
	}
}

// Function that returns all the project configuration values from config.json
func getProjectConfig(w http.ResponseWriter, r *http.Request) {
	// Open our jsonFile
	jsonFile, err := os.Open("../configs/config.json")
	// if we os.Open returns an error then handle it
	if err != nil {
		fmt.Println(err)
	}

	fmt.Println("Successfully opened config.json")
	// defer the closing of our jsonFile so that we can parse it later on
	defer jsonFile.Close()

	byteValue, _ := ioutil.ReadAll(jsonFile)

	// we initialize the devices array
	var projectConfig ProjectConfig

	// we unmarshal our byteArray which contains our
	// jsonFile's content into 'users' which we defined above
	json.Unmarshal(byteValue, &projectConfig)

	fmt.Fprintf(w, "Devices Host: "+projectConfig.DevicesHost+"\n")
	fmt.Fprintf(w, "Selenium Hub Host: "+projectConfig.SeleniumHubHost+"\n")
	fmt.Fprintf(w, "Selenium Hub Port: "+projectConfig.SeleniumHubPort+"\n")
	fmt.Fprintf(w, "Selenium Hub Protocol Type: "+projectConfig.SeleniumHubProtocolType+"\n")
	fmt.Fprintf(w, "WDA Bundle ID: "+projectConfig.WdaBundleID+"\n")
}

func returnDeviceInfo(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	key := vars["device_udid"]

	// Open our jsonFile
	jsonFile, err := os.Open("../configs/config.json")

	// if os.Open returns an error then handle it
	if err != nil {
		fmt.Println(err)
	}

	fmt.Println("Successfully opened config.json")

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

// Function that returns all current iOS device containers and their info
func getIOSContainers(w http.ResponseWriter, r *http.Request) {
	cli, err := client.NewClientWithOpts(client.FromEnv)
	if err != nil {
		panic(err)
	}

	containers, err := cli.ContainerList(context.Background(), types.ContainerListOptions{})
	if err != nil {
		panic(err)
	}

	for _, container := range containers {
		containerName := strings.Replace(container.Names[0], "/", "", -1)
		containerPorts := ""
		for i, s := range container.Ports {
			if i > 0 {
				containerPorts += "\n"
			}
			containerPorts += "{" + s.IP + ", " + strconv.Itoa(int(s.PrivatePort)) + ", " + strconv.Itoa(int(s.PublicPort)) + ", " + s.Type + "}"
		}
		// Define the rows that will be built for the struct used by the template for the table
		var rows []ContainerRow
		re := regexp.MustCompile("[^-]*$")
		match := re.FindStringSubmatch(containerName)
		// Create a struct object for the respective container using the parameters by the above split
		var containerRow = ContainerRow{ContainerID: container.ID, ImageName: container.Image, ContainerStatus: container.Status, ContainerPorts: containerPorts, ContainerName: containerName, DeviceUDID: match[0]}
		// Append each struct object to the rows that will be displayed in the table
		rows = append(rows, containerRow)
		var index = template.Must(template.ParseFiles("static/ios_containers.html"))
		if err := index.Execute(w, rows); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
		}
	}
}

// Function that returns all current iOS device containers and their info
func getContainerLogs(w http.ResponseWriter, r *http.Request) {
	// vars := mux.Vars(r)
	// key := vars["container_id"]

	cli, err := client.NewClientWithOpts(client.FromEnv)
	if err != nil {
		panic(err)
	}

	containers, err := cli.ContainerList(context.Background(), types.ContainerListOptions{})
	if err != nil {
		panic(err)
	}

	for _, container := range containers {
		containerName := strings.Replace(container.Names[0], "/", "", -1)
		containerPorts := ""
		for i, s := range container.Ports {
			if i > 0 {
				containerPorts += "\n"
			}
			containerPorts += "{" + s.IP + ", " + strconv.Itoa(int(s.PrivatePort)) + ", " + strconv.Itoa(int(s.PublicPort)) + ", " + s.Type + "}"
		}
		// Define the rows that will be built for the struct used by the template for the table
		var rows []ContainerRow
		re := regexp.MustCompile("[^-]*$")
		match := re.FindStringSubmatch(containerName)
		// Create a struct object for the respective container using the parameters by the above split
		var containerRow = ContainerRow{ContainerID: container.ID, ImageName: container.Image, ContainerStatus: container.Status, ContainerPorts: containerPorts, ContainerName: containerName, DeviceUDID: match[0]}
		// Append each struct object to the rows that will be displayed in the table
		rows = append(rows, containerRow)
		var index = template.Must(template.ParseFiles("static/ios_containers.html"))
		if err := index.Execute(w, rows); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
		}
	}
}

// Restart docker container
func restartContainer(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	key := vars["container_id"]
	// Execute the command to restart the container by container ID
	commandString := "docker restart " + key
	cmd := exec.Command("bash", "-c", commandString)
	fmt.Println(key)
	var out bytes.Buffer
	cmd.Stdout = &out
	err := cmd.Run()
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println("The command output is: " + out.String())
}

// Load the initial page with the project configuration info
func getInitialPage(w http.ResponseWriter, r *http.Request) {
	// Open our jsonFile
	jsonFile, err := os.Open("../configs/config.json")
	// if we os.Open returns an error then handle it
	if err != nil {
		fmt.Println(err)
	}
	// defer the closing of our jsonFile so that we can parse it later on
	defer jsonFile.Close()

	byteValue, _ := ioutil.ReadAll(jsonFile)

	// we initialize the devices array
	var projectConfig ProjectConfig

	// we unmarshal our byteArray which contains our
	// jsonFile's content into 'users' which we defined above
	json.Unmarshal(byteValue, &projectConfig)

	var configRow = ProjectConfig{
		DevicesHost:             projectConfig.DevicesHost,
		SeleniumHubHost:         projectConfig.SeleniumHubHost,
		SeleniumHubPort:         projectConfig.SeleniumHubPort,
		SeleniumHubProtocolType: projectConfig.SeleniumHubProtocolType,
		WdaBundleID:             projectConfig.WdaBundleID}
	var index = template.Must(template.ParseFiles("static/index.html"))
	if err := index.Execute(w, configRow); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
}

func getDeviceLogs(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	key := vars["log_type"]
	key2 := vars["device_udid"]
	pattern := "../logs/*" + key2 + "/" + key + ".txt"
	matches, err := filepath.Glob(pattern)
	if err != nil {
		fmt.Println("Couldnt find file at path: " + pattern)
	}
	content, err := ioutil.ReadFile(matches[0])
	if err != nil {
		log.Fatal(err)
	}

	w.Header().Set("Content-Type", "text/plain")
	fmt.Fprintf(w, string(content))
}

func handleRequests() {
	// Create a new instance of the mux router
	myRouter := mux.NewRouter().StrictSlash(true)

	// replace http.HandleFunc with myRouter.HandleFunc
	myRouter.HandleFunc("/devicesList", getDevicesList)
	myRouter.HandleFunc("/projectConfig", getProjectConfig)
	myRouter.HandleFunc("/iOSContainers", getIOSContainers)
	myRouter.HandleFunc("/device/{device_udid}", returnDeviceInfo)
	myRouter.HandleFunc("/restartContainer/{container_id}", restartContainer)
	myRouter.HandleFunc("/", getInitialPage)
	myRouter.HandleFunc("/logs/{log_type}/{device_udid}", getDeviceLogs)

	// assets
	fs := http.FileServer(http.Dir("assets"))
	myRouter.Handle("/assets/", http.StripPrefix("/assets/", fs))
	// finally, instead of passing in nil, we want
	// to pass in our newly created router as the second
	// argument
	log.Fatal(http.ListenAndServe(":10000", myRouter))
}

func main() {
	handleRequests()
}
