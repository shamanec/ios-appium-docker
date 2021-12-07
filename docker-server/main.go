package main

import (
    "fmt"
    "log"
    "net/http"
    "encoding/json"
    "os"
    "io/ioutil"
    "strconv"
    "os/exec"
    "bytes"
    "github.com/gorilla/mux"
    "html/template"
    "strings"
)

// Devices struct which contains
// an array of devices from the config.json
type Devices struct {
    Devices []Device `json:"devicesList"`
}

// Device struct which contains device info
type Device struct {
    AppiumPort   int `json:"appium_port"`
    DeviceName   string `json:"device_name"`
    DeviceOSVersion    string    `json:"device_os_version"`
    DeviceUDID string `json:"device_udid"`
    WdaMjpegPort int `json:"wda_mjpeg_port"`
    WdaPort int `json:"wda_port"`
}

// ProjectConfig struct which contains the project configuration values
type ProjectConfig struct {
  DevicesHost string `json:"devices_host"`
  SeleniumHubHost string `json:"selenium_hub_host"`
  SeleniumHubPort string `json:"selenium_hub_port"`
  SeleniumHubProtocolType string `json:"selenium_hub_protocol_type"`
  WdaBundleID string `json:"wda_bundle_id"`
}

// Function that returns the full list of devices from config.json and their data
func getDevicesList(w http.ResponseWriter, r *http.Request){
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
    fmt.Fprintf(w, "Device Name: " + devices.Devices[i].DeviceName + "\n")
    fmt.Fprintf(w, "========================================= \n")
    fmt.Fprintf(w, "Appium Port: " + strconv.Itoa(devices.Devices[i].AppiumPort) + "\n")
    fmt.Fprintf(w, "Device OS version: " + devices.Devices[i].DeviceOSVersion + "\n")
    fmt.Fprintf(w, "Device UDID: " + devices.Devices[i].DeviceUDID + "\n")
    fmt.Fprintf(w, "WDA Mjpeg port: " + strconv.Itoa(devices.Devices[i].WdaMjpegPort) + "\n")
    fmt.Fprintf(w, "WDA Port: " + strconv.Itoa(devices.Devices[i].WdaPort) + "\n")
  }
}

// Function that returns all the project configuration values from config.json
func getProjectConfig(w http.ResponseWriter, r *http.Request){
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

  fmt.Fprintf(w, "Devices Host: " + projectConfig.DevicesHost + "\n")
  fmt.Fprintf(w, "Selenium Hub Host: " + projectConfig.SeleniumHubHost + "\n")
  fmt.Fprintf(w, "Selenium Hub Port: " + projectConfig.SeleniumHubPort + "\n")
  fmt.Fprintf(w, "Selenium Hub Protocol Type: " + projectConfig.SeleniumHubProtocolType + "\n")
  fmt.Fprintf(w, "WDA Bundle ID: " + projectConfig.WdaBundleID + "\n")
}

func returnDeviceInfo(w http.ResponseWriter, r *http.Request){
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

  // Loop over the devices and return info only on the device which UDID matches the path key
  for i := 0; i < len(devices.Devices); i++ {
    if devices.Devices[i].DeviceUDID == key {
      fmt.Fprintf(w, "Device Name: " + devices.Devices[i].DeviceName + "\n")
      fmt.Fprintf(w, "Appium Port: " + strconv.Itoa(devices.Devices[i].AppiumPort) + "\n")
      fmt.Fprintf(w, "Device OS version: " + devices.Devices[i].DeviceOSVersion + "\n")
      fmt.Fprintf(w, "Device UDID: " + devices.Devices[i].DeviceUDID + "\n")
      fmt.Fprintf(w, "WDA Mjpeg port: " + strconv.Itoa(devices.Devices[i].WdaMjpegPort) + "\n")
      fmt.Fprintf(w, "WDA Port: " + strconv.Itoa(devices.Devices[i].WdaPort) + "\n")
    }
  }
}

// Function that returns all the project configuration values from config.json
func getDevicesListJSON(w http.ResponseWriter, r *http.Request){
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

  w.Header().Set("Content-Type", "application/json")
  w.WriteHeader(http.StatusCreated)
  json.NewEncoder(w).Encode(devices)
}

func tableTest(w http.ResponseWriter, r *http.Request) {
  rows := []ContainerRow{
		{ContainerID: "test1", ImageName: "1", ContainerStatus: "Up", ContainerPorts: "1080", ContainerName: "ios_device_something"},
		{ContainerID: "test2", ImageName: "2", ContainerStatus: "Down", ContainerPorts: "1081", ContainerName: "ios_device_something2"},
	}
  var index = template.Must(template.ParseFiles("static/index.html"))
  if err := index.Execute(w, rows); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
}

type ContainerRow struct {
  ContainerID string
  ImageName string
  ContainerStatus string
  ContainerPorts string
  ContainerName string
}

// Function that returns all current iOS device containers
func getIOSContainers(w http.ResponseWriter, r *http.Request){
  // Execute the command to get the current containers and get the output
  cmd := exec.Command("cat", "/Users/shabanovn/Desktop/test_containers.txt")
  var out bytes.Buffer
  cmd.Stdout = &out
  err := cmd.Run()
  if err != nil {
    log.Fatal(err)
  }

  // Define the rows that will be built for the struct used by the template for the table
  rows := []ContainerRow{}

  // Split the output of the shell command by line
  for _, line := range strings.Split(strings.TrimSuffix(out.String(), "\n"), "\n") {
    // Split each line into parameters by space
    s := strings.Split(line, " ")
    // Create a struct object for the respective container using the parameters by the above split
    var container_row = ContainerRow{ContainerID: s[0], ImageName: s[1], ContainerStatus: s[2], ContainerPorts: s[3], ContainerName: s[4]}
    // Append each struct object to the rows that will be displayed in the table
    rows = append(rows, container_row)
  }
  var index = template.Must(template.ParseFiles("static/index.html"))
  if err := index.Execute(w, rows); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
}

func handleRequests() {
  // Create a new instance of the mux router
  myRouter := mux.NewRouter().StrictSlash(true)

  // replace http.HandleFunc with myRouter.HandleFunc
  myRouter.HandleFunc("/devicesList", getDevicesList)
  myRouter.HandleFunc("/projectConfig", getProjectConfig)
  myRouter.HandleFunc("/iOSContainers", getIOSContainers)
  myRouter.HandleFunc("/device/{device_udid}", returnDeviceInfo)
  myRouter.HandleFunc("/devicesListJSON", getDevicesListJSON)
  myRouter.HandleFunc("/test", tableTest)

  // finally, instead of passing in nil, we want
  // to pass in our newly created router as the second
  // argument
  log.Fatal(http.ListenAndServe(":10000", myRouter))
}

func main() {
  http.Handle("/assets/", http.StripPrefix("/assets/", http.FileServer(http.Dir("assets"))))
  handleRequests()
}
