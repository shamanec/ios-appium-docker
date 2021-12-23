package main

import (
	"bytes"
	"fmt"
	"net/http"
	"os/exec"
)

func StartListenerGrid(w http.ResponseWriter, r *http.Request) {
	// Execute the command to restart the container by container ID
	commandString := "./listener_script.sh"
	cmd := exec.Command("bash", "-c", commandString)

	var out bytes.Buffer
	cmd.Stdout = &out
	err := cmd.Run()
	if err != nil {
		fmt.Fprintf(w, "Could not start listener script with Selenium Grid.")
		return
	}

	fmt.Fprintf(w, "Started listener script with Selenium Grid.")
}

func StartListenerNoGrid(w http.ResponseWriter, r *http.Request) {
	// Execute the command to restart the container by container ID
	commandString := "./listener_script.sh no_grid"
	cmd := exec.Command("bash", "-c", commandString)

	var out bytes.Buffer
	cmd.Stdout = &out
	err := cmd.Run()
	if err != nil {
		fmt.Fprintf(w, "Could not start listener script without Selenium Grid.")
		return
	}

	fmt.Fprintf(w, "Started listener script without Selenium Grid.")
}

func StopListener(w http.ResponseWriter, r *http.Request) {
	// Execute the command to restart the container by container ID
	getPIDcommand := "ps aux | grep './listener_script.sh' | grep -v grep | awk '{print $2}'"
	cmd := exec.Command("bash", "-c", getPIDcommand)

	var out bytes.Buffer
	cmd.Stdout = &out
	err := cmd.Run()
	if err != nil || out.String() == "" {
		fmt.Fprintf(w, "The listener is not running.")
		return
	}

	killListenerCommand := "kill -9 " + out.String()
	cmd = exec.Command("bash", "-c", killListenerCommand)
	out.Reset()

	err = cmd.Run()
	if err != nil {
		fmt.Fprintf(w, "Could not kill the listener.")
	} else {
		fmt.Fprintf(w, "Successfully stopped the listener.")
	}
}
