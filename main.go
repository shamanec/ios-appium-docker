package main

import (
	"encoding/json"
	"fmt"
	"html/template"
	"io/ioutil"
	"log"
	"net/http"
	"os"

	"github.com/gorilla/mux"
	"github.com/gorilla/websocket"
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

type ProjectConfigPageData struct {
	GoIOSListenerStatus   string
	UdevIOSListenerStatus string
	ImageStatus           string
	ProjectConfigValues   ProjectConfig
}

type ContainerRow struct {
	ContainerID     string
	ImageName       string
	ContainerStatus string
	ContainerPorts  string
	ContainerName   string
	DeviceUDID      string
}

// Load the initial page
func GetInitialPage(w http.ResponseWriter, r *http.Request) {
	var index = template.Must(template.ParseFiles("static/index.html"))
	if err := index.Execute(w, nil); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
}

// Load the initial page with the project configuration info
func GetProjectConfigurationPage(w http.ResponseWriter, r *http.Request) {
	// Open the config jsonFile
	jsonFile, err := os.Open("./configs/config.json")
	if err != nil {
		fmt.Println(err)
		return
	}
	// defer the closing of our jsonFile so that we can parse it later on
	defer jsonFile.Close()

	// Read the JSON file
	byteValue, _ := ioutil.ReadAll(jsonFile)

	// initialize the devices array
	var projectConfig ProjectConfig

	// unmarshal our byteArray which contains our
	// jsonFile's content into 'projectConfig' which is defined above
	json.Unmarshal(byteValue, &projectConfig)

	// Create the config row that will provide the data to the templated table
	var configRow = ProjectConfig{
		DevicesHost:             projectConfig.DevicesHost,
		SeleniumHubHost:         projectConfig.SeleniumHubHost,
		SeleniumHubPort:         projectConfig.SeleniumHubPort,
		SeleniumHubProtocolType: projectConfig.SeleniumHubProtocolType,
		WdaBundleID:             projectConfig.WdaBundleID}

	// Load the page templating the project config values
	var index = template.Must(template.ParseFiles("static/project_config.html"))
	pageData := ProjectConfigPageData{GoIOSListenerStatus: GoIOSListenerStatus(), UdevIOSListenerStatus: UdevIOSListenerStatus(), ImageStatus: ImageExists(), ProjectConfigValues: configRow}
	if err := index.Execute(w, pageData); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
}

func UpdateProjectConfigHandler(w http.ResponseWriter, r *http.Request) {
	decoder := json.NewDecoder(r.Body)
	var request_config ProjectConfig
	err := decoder.Decode(&request_config)
	if err != nil {
		fmt.Println(err)
		return
	}

	// Open our jsonFile
	jsonFile, err := os.Open("./configs/config.json")
	// if we os.Open returns an error then handle it
	if err != nil {
		fmt.Println(err)
		return
	}
	// defer the closing of our jsonFile so that we can parse it later on
	defer jsonFile.Close()

	// Read the json file
	byteValue, err := ioutil.ReadAll(jsonFile)
	if err != nil {
		fmt.Println(err)
		return
	}

	// Unmarshal the JSON file
	var result map[string]interface{}
	err = json.Unmarshal(byteValue, &result)
	if err != nil {
		fmt.Println(err)
		return
	}

	if request_config.DevicesHost != "" {
		result["devices_host"] = request_config.DevicesHost
	}
	if request_config.SeleniumHubHost != "" {
		result["selenium_hub_host"] = request_config.SeleniumHubHost
	}
	if request_config.SeleniumHubPort != "" {
		result["selenium_hub_port"] = request_config.SeleniumHubPort
	}
	if request_config.SeleniumHubProtocolType != "" {
		result["selenium_hub_protocol_type"] = request_config.SeleniumHubProtocolType
	}
	if request_config.WdaBundleID != "" {
		result["wda_bundle_id"] = request_config.WdaBundleID
	}

	// Marshal  the new json
	byteValue, err = json.Marshal(result)
	if err != nil {
		panic(err)
	}

	// Write the new json to the config.json file
	err = ioutil.WriteFile("./configs/config.json", byteValue, 0644)
	if err != nil {
		panic(err)
	}
}

func InteractDockerFile(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "GET":
		// Open our Dockerfile
		dockerfile, err := os.Open("./Dockerfile")
		// if we os.Open returns an error then handle it
		if err != nil {
			fmt.Println(err)
		}
		// defer the closing of our jsonFile so that we can parse it later on
		defer dockerfile.Close()

		byteValue, _ := ioutil.ReadAll(dockerfile)

		fmt.Fprintf(w, string(byteValue))
	case "POST":
		// Open our Dockerfile
		dockerfile, err := os.Open("./Dockerfile")
		// if we os.Open returns an error then handle it
		if err != nil {
			fmt.Println(err)
		}
		// defer the closing of our jsonFile so that we can parse it later on
		defer dockerfile.Close()

		byteValue, _ := ioutil.ReadAll(dockerfile)

		fmt.Fprintf(w, "THIS IS ON POST"+string(byteValue))
	}
}

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
}

func testWS(w http.ResponseWriter, r *http.Request) {
	conn, _ := upgrader.Upgrade(w, r, nil) // error ignored for sake of simplicity

	for {
		// Read message from browser
		msgType, msg, err := conn.ReadMessage()
		if err != nil {
			return
		}

		// Print the message to the console
		fmt.Printf("%s sent: %s\n", conn.RemoteAddr(), string(msg))

		// Write message back to browser
		if err = conn.WriteMessage(msgType, msg); err != nil {
			return
		}
	}
}

func handleRequests() {
	// Create a new instance of the mux router
	myRouter := mux.NewRouter().StrictSlash(true)

	// replace http.HandleFunc with myRouter.HandleFunc
	myRouter.HandleFunc("/iOSContainers", GetIOSContainers)
	myRouter.HandleFunc("/device/{device_udid}", ReturnDeviceInfo)
	myRouter.HandleFunc("/restartContainer/{container_id}", RestartContainer)
	myRouter.HandleFunc("/deviceLogs/{log_type}/{device_udid}", GetDeviceLogs)
	myRouter.HandleFunc("/containerLogs/{container_id}", GetContainerLogs)
	myRouter.HandleFunc("/configuration", GetProjectConfigurationPage)
	myRouter.HandleFunc("/androidContainers", getAndroidContainers)
	myRouter.HandleFunc("/updateConfig", UpdateProjectConfigHandler)
	myRouter.HandleFunc("/dockerfile", InteractDockerFile)
	myRouter.HandleFunc("/build-image", BuildDockerImage)
	myRouter.HandleFunc("/remove-image", RemoveDockerImage)
	myRouter.HandleFunc("/start-listener-grid", StartListenerGrid)
	myRouter.HandleFunc("/start-listener-no-grid", StartListenerNoGrid)
	myRouter.HandleFunc("/stop-listener", StopListener)
	myRouter.HandleFunc("/ios-devices", GetConnectedIOSDevices)
	myRouter.HandleFunc("/ios-devices/register", RegisterIOSDevice)
	//myRouter.HandleFunc("/test", ImageExists2)

	myRouter.HandleFunc("/ws", testWS)

	// assets
	myRouter.PathPrefix("/static/").Handler(http.StripPrefix("/static/", http.FileServer(http.Dir("static/"))))
	myRouter.PathPrefix("/main/").Handler(http.StripPrefix("/main/", http.FileServer(http.Dir("./"))))

	myRouter.HandleFunc("/", GetInitialPage)

	// finally, instead of passing in nil, we want
	// to pass in our newly created router as the second
	// argument
	log.Fatal(http.ListenAndServe(":10000", myRouter))
}

func main() {
	handleRequests()
}
