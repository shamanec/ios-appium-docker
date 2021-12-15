package main

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"context"
	"encoding/json"
	"fmt"
	"html/template"
	"io"
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

// Function that returns the full list of devices from config.json and their data
func getDevicesList(w http.ResponseWriter, r *http.Request) {
	// Open our jsonFile
	jsonFile, err := os.Open("./configs/config.json")
	// if we os.Open returns an error then handle it
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
	jsonFile, err := os.Open("./configs/config.json")
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

// Function that returns all current iOS device containers and their info
func getIOSContainers(w http.ResponseWriter, r *http.Request) {
	cli, err := client.NewClientWithOpts(client.FromEnv)
	if err != nil {
		panic(err)
	}

	// Get the current containers list
	containers, err := cli.ContainerList(context.Background(), types.ContainerListOptions{All: true})
	if err != nil {
		panic(err)
	}

	// Define the rows that will be built for the struct used by the template for the table
	var rows []ContainerRow

	// Loop through the containers list
	for _, container := range containers {
		// Parse plain container name
		containerName := strings.Replace(container.Names[0], "/", "", -1)

		// Get all the container ports from the returned array into string
		containerPorts := ""
		for i, s := range container.Ports {
			if i > 0 {
				containerPorts += "\n"
			}
			containerPorts += "{" + s.IP + ", " + strconv.Itoa(int(s.PrivatePort)) + ", " + strconv.Itoa(int(s.PublicPort)) + ", " + s.Type + "}"
		}

		// Extract the device UDID from the container name
		re := regexp.MustCompile("[^-]*$")
		match := re.FindStringSubmatch(containerName)

		// Create a struct object for the respective container using the parameters by the above split
		var containerRow = ContainerRow{ContainerID: container.ID, ImageName: container.Image, ContainerStatus: container.Status, ContainerPorts: containerPorts, ContainerName: containerName, DeviceUDID: match[0]}
		// Append each struct object to the rows that will be displayed in the table
		rows = append(rows, containerRow)
	}
	// Parse the template and return response with the container table rows
	var index = template.Must(template.ParseFiles("static/ios_containers.html"))
	if err := index.Execute(w, rows); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
}

// Function that returns all current iOS device containers and their info
func getContainerLogs(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	key := vars["container_id"]
	w.Header().Set("Content-Type", "text/plain")

	ctx := context.Background()
	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	if err != nil {
		panic(err)
	}

	options := types.ContainerLogsOptions{ShowStdout: true}
	// Replace this ID with a container that really exists
	out, err := cli.ContainerLogs(ctx, key, options)
	if err != nil {
		panic(err)
	}

	buf := new(bytes.Buffer)
	buf.ReadFrom(out)
	newStr := buf.String()

	if newStr != "" {
		fmt.Fprintf(w, newStr)
	} else {
		fmt.Fprintf(w, "There are no actual logs for this container.")
	}
}

// Restart docker container
func restartContainer(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	key := vars["container_id"]

	ctx := context.Background()
	cli, err := client.NewClientWithOpts(client.FromEnv)
	if err != nil {
		panic(err)
	}

	if err := cli.ContainerRestart(ctx, key, nil); err != nil {
		log.Printf("Unable to restart container %s: %s", key, err)
	}
}

// Load the initial page
func getInitialPage(w http.ResponseWriter, r *http.Request) {
	var index = template.Must(template.ParseFiles("static/index.html"))
	if err := index.Execute(w, nil); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
}

// Load the initial page with the project configuration info
func getProjectConfigurationPage(w http.ResponseWriter, r *http.Request) {
	// Open our jsonFile
	jsonFile, err := os.Open("./configs/config.json")
	// if we os.Open returns an error then handle it
	if err != nil {
		fmt.Println(err)
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
	if err := index.Execute(w, configRow); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
}

// Load the initial page with the project configuration info
func getAndroidContainers(w http.ResponseWriter, r *http.Request) {
	var index = template.Must(template.ParseFiles("static/android_containers.html"))
	if err := index.Execute(w, nil); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
}

// Get the respective device logs based on log type
func getDeviceLogs(w http.ResponseWriter, r *http.Request) {
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

func updateProjectConfigHandler(w http.ResponseWriter, r *http.Request) {
	decoder := json.NewDecoder(r.Body)
	var request_config ProjectConfig
	err := decoder.Decode(&request_config)
	if err != nil {
		panic(err)
	}

	// Open our jsonFile
	jsonFile, err := os.Open("./configs/config.json")
	// if we os.Open returns an error then handle it
	if err != nil {
		fmt.Println(err)
	}
	// defer the closing of our jsonFile so that we can parse it later on
	defer jsonFile.Close()

	// Read the json file
	byteValue, err := ioutil.ReadAll(jsonFile)
	if err != nil {
		panic(err)
	}

	// Unmarshal the JSON file
	var result map[string]interface{}
	err = json.Unmarshal(byteValue, &result)
	if err != nil {
		panic(err)
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

func interactDockerFile(w http.ResponseWriter, r *http.Request) {
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

func buildDockerImage(w http.ResponseWriter, r *http.Request) {
	buf := new(bytes.Buffer)
	files := []string{"Dockerfile", "WebDriverAgent.ipa", "configs/nodeconfiggen.sh", "configs/wdaSync.sh"}
	out, err := os.Create("build-context.tar")
	if err != nil {
		panic(err)
	}
	defer out.Close()
	err = createArchive(files, out)
	if err != nil {
		panic(err)
	}
	ctx := context.Background()
	cli, err := client.NewClientWithOpts(client.FromEnv)
	if err != nil {
		panic(err)
	}

	buildContextFileReader, err := os.Open("build-context.tar")
	readBuildContextFile, err := ioutil.ReadAll(buildContextFileReader)
	buildContextTarReader := bytes.NewReader(readBuildContextFile)

	imageBuildResponse, err := cli.ImageBuild(ctx, buildContextTarReader, types.ImageBuildOptions{Tags: []string{"test"}})
	if err != nil {
		buf.ReadFrom(imageBuildResponse.Body)
		panic(err)
	}
	buf.ReadFrom(imageBuildResponse.Body)
	defer imageBuildResponse.Body.Close()
	_, err = io.Copy(os.Stdout, imageBuildResponse.Body)
	if err != nil {
		panic(err)
	}
	fmt.Fprintf(w, buf.String())
}

func createArchive(files []string, buf io.Writer) error {
	// Create new Writers for gzip and tar
	// These writers are chained. Writing to the tar writer will
	// write to the gzip writer which in turn will write to
	// the "buf" writer
	gw := gzip.NewWriter(buf)
	defer gw.Close()
	tw := tar.NewWriter(gw)
	defer tw.Close()

	// Iterate over files and add them to the tar archive
	for _, file := range files {
		err := addToArchive(tw, file)
		if err != nil {
			return err
		}
	}

	return nil
}

func addToArchive(tw *tar.Writer, filename string) error {
	// Open the file which will be written into the archive
	file, err := os.Open(filename)
	if err != nil {
		return err
	}
	defer file.Close()

	// Get FileInfo about our file providing file size, mode, etc.
	info, err := file.Stat()
	if err != nil {
		return err
	}

	// Create a tar Header from the FileInfo data
	header, err := tar.FileInfoHeader(info, info.Name())
	if err != nil {
		return err
	}

	// Use full path as name (FileInfoHeader only takes the basename)
	// If we don't do this the directory strucuture would
	// not be preserved
	// https://golang.org/src/archive/tar/common.go?#L626
	header.Name = filename

	// Write file header to the tar archive
	err = tw.WriteHeader(header)
	if err != nil {
		return err
	}

	// Copy file content to tar archive
	_, err = io.Copy(tw, file)
	if err != nil {
		return err
	}

	return nil
}

func createTar(source, target string) error {
	filename := filepath.Base(source)
	target = filepath.Join(target, fmt.Sprintf("%s.tar", filename))
	tarfile, err := os.Create(target)
	if err != nil {
		return err
	}
	defer tarfile.Close()

	tarball := tar.NewWriter(tarfile)
	defer tarball.Close()

	info, err := os.Stat(source)
	if err != nil {
		return nil
	}

	var baseDir string
	if info.IsDir() {
		baseDir = filepath.Base(source)
	}

	return filepath.Walk(source,
		func(path string, info os.FileInfo, err error) error {
			if err != nil {
				return err
			}
			header, err := tar.FileInfoHeader(info, info.Name())
			if err != nil {
				return err
			}

			if baseDir != "" {
				header.Name = filepath.Join(baseDir, strings.TrimPrefix(path, source))
			}

			if err := tarball.WriteHeader(header); err != nil {
				return err
			}

			if info.IsDir() {
				return nil
			}

			file, err := os.Open(path)
			if err != nil {
				return err
			}
			defer file.Close()
			_, err = io.Copy(tarball, file)
			return err
		})
}

func deleteFile(filePath string) {
	err := os.Remove(string(filePath))
	if err != nil {
		panic("Could not delete file at: " + string(filePath) + ". " + err.Error())
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
	myRouter.HandleFunc("/restartContainer/{container_id}", restartContainer)
	myRouter.HandleFunc("/deviceLogs/{log_type}/{device_udid}", getDeviceLogs)
	myRouter.HandleFunc("/containerLogs/{container_id}", getContainerLogs)
	myRouter.HandleFunc("/configuration", getProjectConfigurationPage)
	myRouter.HandleFunc("/androidContainers", getAndroidContainers)
	myRouter.HandleFunc("/updateConfig", updateProjectConfigHandler)
	myRouter.HandleFunc("/dockerfile", interactDockerFile)
	myRouter.HandleFunc("/build-image", buildDockerImage)

	// assets
	myRouter.PathPrefix("/static/").Handler(http.StripPrefix("/static/", http.FileServer(http.Dir("static/"))))
	myRouter.PathPrefix("/main/").Handler(http.StripPrefix("/main/", http.FileServer(http.Dir("./"))))

	myRouter.HandleFunc("/", getInitialPage)

	// finally, instead of passing in nil, we want
	// to pass in our newly created router as the second
	// argument
	log.Fatal(http.ListenAndServe(":10000", myRouter))
}

func main() {
	handleRequests()
}
