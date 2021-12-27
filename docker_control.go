package main

import (
	"bytes"
	"context"
	"fmt"
	"html/template"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"regexp"
	"strconv"
	"strings"

	"github.com/docker/docker/api/types"
	"github.com/docker/docker/client"
	"github.com/gorilla/mux"
)

func BuildDockerImage(w http.ResponseWriter, r *http.Request) {
	// Delete build-context.tar if it exists
	DeleteFile("./build-context.tar")

	// Create a tar to be used as build-context for the image build
	// The tar should include all files needed by the Dockerfile to successfully create the image
	files := []string{"Dockerfile", "WebDriverAgent.ipa", "configs/nodeconfiggen.sh", "configs/wdaSync.sh"}
	out, err := os.Create("build-context.tar")
	if err != nil {
		http.Error(w, "Could not create archive file. Error: "+err.Error(), http.StatusBadRequest)
		return
	}
	defer out.Close()
	err = CreateArchive(files, out)
	if err != nil {
		http.Error(w, "Could not create archive. Error: "+err.Error(), http.StatusBadRequest)
		return
	}

	// Create the context and Docker client
	ctx := context.Background()
	cli, err := client.NewClientWithOpts(client.FromEnv)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	// Read the build-context tar into bytes.Reader
	buildContextFileReader, err := os.Open("build-context.tar")
	readBuildContextFile, err := ioutil.ReadAll(buildContextFileReader)
	buildContextTarReader := bytes.NewReader(readBuildContextFile)

	// Build the Docker image using the tar reader
	buf := new(bytes.Buffer)
	fmt.Fprintf(w, "Building image...")
	imageBuildResponse, err := cli.ImageBuild(ctx, buildContextTarReader, types.ImageBuildOptions{Remove: true, Tags: []string{"ios-appium"}})
	if err != nil {
		// Get the image build logs on failure
		buf.ReadFrom(imageBuildResponse.Body)
		http.Error(w, "Could not build image. Error: "+err.Error()+"\n"+buf.String(), http.StatusBadRequest)
		return
	}

	// Get the image build logs
	buf.ReadFrom(imageBuildResponse.Body)
	defer imageBuildResponse.Body.Close()
	fmt.Fprintf(w, "\n"+buf.String())
}

func RemoveDockerImage(w http.ResponseWriter, r *http.Request) {
	// Create the context and Docker client
	ctx := context.Background()
	cli, err := client.NewClientWithOpts(client.FromEnv)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	imageRemoveResponse, err := cli.ImageRemove(ctx, "ios-appium", types.ImageRemoveOptions{PruneChildren: true})
	if err != nil {
		http.Error(w, "Could not remove image. "+err.Error(), http.StatusBadRequest)
		return
	}
	fmt.Fprintf(w, "Successfully removed image tagged: '"+imageRemoveResponse[0].Untagged+"'")
}

// Function that returns all current iOS device containers and their info
func GetIOSContainers(w http.ResponseWriter, r *http.Request) {
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

// Restart docker container
func RestartContainer(w http.ResponseWriter, r *http.Request) {
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

// Function that returns all current iOS device containers and their info
func GetContainerLogs(w http.ResponseWriter, r *http.Request) {
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

// Load the initial page with the project configuration info
func getAndroidContainers(w http.ResponseWriter, r *http.Request) {
	var index = template.Must(template.ParseFiles("static/android_containers.html"))
	if err := index.Execute(w, nil); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
}