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
)

// Users struct which contains
// an array of users
type Devices struct {
    Devices []Device `json:"devicesList"`
}

// User struct which contains a name
// a type and a list of social links
type Device struct {
    AppiumPort   int `json:"appium_port"`
    DeviceName   string `json:"device_name"`
    DeviceOSVersion    string    `json:"device_os_version"`
    DeviceUDID string `json:"device_udid"`
    WdaMjpegPort int `json:"wda_mjpeg_port"`
    WdaPort int `json:"wda_port"`
}

type ProjectConfig struct {
  DevicesHost string `json:"devices_host"`
  SeleniumHubHost string `json:"selenium_hub_host"`
  SeleniumHubPort string `json:"selenium_hub_port"`
  SeleniumHubProtocolType string `json:"selenium_hub_protocol_type"`
  WdaBundleID string `json:"wda_bundle_id"`
}

func devicesList(w http.ResponseWriter, r *http.Request){
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

func projectConfig(w http.ResponseWriter, r *http.Request){
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

func getDockerContainers(w http.ResponseWriter, r *http.Request){
  cmd := exec.Command("ls", "-la", "/Users/shabanovn/Desktop")
  var out bytes.Buffer
  cmd.Stdout = &out
  err := cmd.Run()
  if err != nil {
    log.Fatal(err)
  }
  fmt.Fprintf(w, out.String())
}

func handleRequests() {
  http.HandleFunc("/devicesList", devicesList)
  http.HandleFunc("/projectConfig", projectConfig)
  http.HandleFunc("/dockerContainers", getDockerContainers)
  log.Fatal(http.ListenAndServe(":10000", nil))
}

func main() {
  handleRequests()
}
