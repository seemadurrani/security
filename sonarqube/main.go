package main

import (
	"fmt"
	"os"
	"os/exec"
	"log"
)

func runCommand(command string, args ...string) {
	cmd := exec.Command(command, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		log.Fatalf("Failed to execute %s %v: %v", command, args, err)
	}
}

func main() {
	fmt.Println("Updating system packages...")
	runCommand("sudo", "apt", "update")
	runCommand("sudo", "apt", "upgrade", "-y")

	fmt.Println("Installing required dependencies...")
	runCommand("sudo", "apt", "install", "openjdk-17-jdk", "wget", "unzip", "-y")

	fmt.Println("Creating sonar user...")
	runCommand("sudo", "useradd", "-m", "-d", "/opt/sonarqube", "-r", "sonar")

	fmt.Println("Downloading and setting up SonarQube...")
	runCommand("wget", "https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-10.2.1.78527.zip")
	runCommand("sudo", "unzip", "sonarqube-10.2.1.78527.zip", "-d", "/opt/")
	runCommand("sudo", "mv", "/opt/sonarqube-10.2.1.78527", "/opt/sonarqube")
	runCommand("sudo", "chown", "-R", "sonar:sonar", "/opt/sonarqube")

	fmt.Println("Configuring SonarQube as a systemd service...")
	systemdConfig := `[Unit]
Description=SonarQube service
After=network.target

[Service]
Type=simple
User=sonar
Group=sonar
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
Restart=always
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target`

	file, err := os.Create("/etc/systemd/system/sonarqube.service")
	if err != nil {
		log.Fatalf("Failed to create systemd service file: %v", err)
	}
	defer file.Close()
	file.WriteString(systemdConfig)

	runCommand("sudo", "systemctl", "daemon-reload")
	runCommand("sudo", "systemctl", "enable", "sonarqube")
	runCommand("sudo", "systemctl", "start", "sonarqube")

	fmt.Println("SonarQube setup is complete. Access it at http://localhost:9000")
}

