package main

import (
	"archive/tar"
	"compress/gzip"
	"encoding/json"
	"io"
	"io/ioutil"
	"net/http"
	"os"
	"os/user"

	"github.com/tidwall/gjson"
)

// Create a tar archive from an array of files while preserving directory structure
func CreateArchive(files []string, buf io.Writer) error {
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
		err := AddToArchive(tw, file)
		if err != nil {
			return err
		}
	}

	return nil
}

// Add files to the tar writer
func AddToArchive(tw *tar.Writer, filename string) error {
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

// Delete file by path
func DeleteFile(filePath string) {
	err := os.Remove(string(filePath))
	if err != nil {
		panic("Could not delete file at: " + string(filePath) + ". " + err.Error())
	}
}

// Device struct which contains device info
type ErrorJSON struct {
	ErrorCode    string `json:"error_code"`
	ErrorMessage string `json:"error_message"`
}

func JSONError(w http.ResponseWriter, error_code string, error_string string, code int) {
	var errorMessage = ErrorJSON{
		ErrorCode:    error_code,
		ErrorMessage: error_string}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(errorMessage)
}

func createUdevRules(w http.ResponseWriter, r *http.Request) {
	create_container_rules, err := os.Create("./90-usbmuxd.rules")
	if err != nil {
		JSONError(w, "udev_rule_error", "Could not create 90-usbmuxd.rules", 500)
	}
	defer create_container_rules.Close()
	start_usbmuxd_rule, err := os.Create("./39-usbmuxd.rules")
	if err != nil {
		JSONError(w, "udev_rule_error", "Could not create 90-usbmuxd.rules", 500)
	}
	defer start_usbmuxd_rule.Close()
	// Open the configuration json file
	jsonFile, err := os.Open("./configs/config.json")
	if err != nil {
		JSONError(w, "config_file_error", "Could not open the config.json file.", 500)
	}
	defer jsonFile.Close()

	// Read the configuration json file into byte array
	configJson, err := ioutil.ReadAll(jsonFile)
	if err != nil {
		JSONError(w, "config_file_error", "Could not read the config.json file.", 500)
	}

	// Get the UDIDs of all devices registered in the config.json
	jsonDevicesUDIDs := gjson.Get(string(configJson), "devicesList.#.device_udid")

	current_user, err := user.Current()

	// For each udid create a new line inside the 90-usbmuxd.rules file
	for _, udid := range jsonDevicesUDIDs.Array() {
		rule_line := "ACTION==\"add\", SUBSYSTEM==\"usb\", ENV{DEVTYPE}==\"usb_device\", ATTR{manufacturer}==\"Apple Inc.\", ATTR{serial}==\"" + udid.Str + "\", OWNER=\"" + current_user.Username + "\", MODE=\"0666\", RUN+=\"/usr/local/bin/ios_device2docker " + udid.Str + "\""
		if _, err := create_container_rules.WriteString(rule_line + "\n"); err != nil {
			JSONError(w, "udev_rule_error", "Could not write to 90-usbmuxd.rules", 500)
		}
	}

	// Update the container removal rule
	if _, err := start_usbmuxd_rule.WriteString("SUBSYSTEM==\"usb\", ENV{DEVTYPE}==\"usb_device\", ENV{PRODUCT}==\"5ac/12[9a][0-9a-f]/*|5ac/1901/*|5ac/8600/*\", OWNER=\"" + current_user.Username + "\", ACTION==\"add\", RUN+=\"/usr/sbin/usbmuxd -u -v -z\""); err != nil {
		JSONError(w, "udev_rule_error", "Could not write to 90-usbmuxd.rules", 500)
	}
}
