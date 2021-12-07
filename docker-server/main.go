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

// Function that returns all current iOS device containers
func getIOSContainers(w http.ResponseWriter, r *http.Request){
  cmd := exec.Command("ls", "-la", "/Users/shabanovn/Desktop")
  var out bytes.Buffer
  cmd.Stdout = &out
  err := cmd.Run()
  if err != nil {
    log.Fatal(err)
  }
  fmt.Fprintf(w, out.String())
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

func handleRequests() {
  // Create a new instance of the mux router
  myRouter := mux.NewRouter().StrictSlash(true)

  // replace http.HandleFunc with myRouter.HandleFunc
  myRouter.HandleFunc("/devicesList", getDevicesList)
  myRouter.HandleFunc("/projectConfig", getProjectConfig)
  myRouter.HandleFunc("/iOSContainers", getIOSContainers)
  myRouter.HandleFunc("/device/{device_udid}", returnDeviceInfo)

  // finally, instead of passing in nil, we want
  // to pass in our newly created router as the second
  // argument
  log.Fatal(http.ListenAndServe(":10000", myRouter))
}

func main() {
  handleRequests()
}
