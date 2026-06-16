# Palworld Wine Docker

Palworld Windows Dedicated Server를 Ubuntu + Docker + Wine 환경에서 실행하기 위한 개인 테스트용 설치 스크립트입니다.

> Testing for personal use.
> This project is mainly for personal testing and server setup automation.

## Overview

This project generates and runs a Docker-based Palworld dedicated server environment using:

* Ubuntu 24.04 Docker image
* WineHQ Stable
* Windows Palworld Dedicated Server
* SteamCMD
* PalDefender
* UE4SS
* Docker Compose
* Simple management helper script: `pal.sh`

The installer is designed to automate the setup process that would normally require manually installing Wine, SteamCMD, Palworld server files, PalDefender, and UE4SS.

## Features

* One-line installation
* Docker Compose based server management
* Windows Palworld server through Wine
* Automatic SteamCMD setup
* Automatic Palworld Windows server download
* Automatic PalDefender installation
* Automatic UE4SS installation
* Palworld settings auto-generation
* Basic gameplay rate customization
* Backup before update
* Helper commands for start, stop, restart, logs, update, and mod checks

## Environment

Recommended environment:

| Item         | Recommended       |
| ------------ | ----------------- |
| OS           | Ubuntu 24.04 LTS  |
| Architecture | x86_64 / amd64    |
| CPU          | 4 cores or higher |
| RAM          | 8 GB or higher    |
| Storage      | 30 GB or higher   |
| Network      | UDP 8211 open     |

Tested mainly on a Google Cloud Ubuntu VM.

## Ports

The installer exposes the following ports:

| Port  | Protocol | Purpose         |
| ----- | -------: | --------------- |
| 8211  |      UDP | Palworld server |
| 25575 |      TCP | RCON            |
| 8212  |      TCP | REST API        |
| 27015 |  TCP/UDP | Query / extra   |

Make sure your cloud firewall or router allows at least:

```bash
8211/udp
```

## Install


The first run may take a while because it needs to:

1. Install Docker
2. Build the Docker image
3. Install Wine inside the image
4. Initialize the Wine prefix
5. Download the Windows Palworld Dedicated Server
6. Install PalDefender
7. Install UE4SS
8. Start the server

Initial setup can take 10–30 minutes depending on server performance and network speed.

## Manual Download and Run

You can also download the installer first:

```bash
cd ~

curl -fsSL \
  "https://raw.githubusercontent.com/shinyeonghun/palworld_wine_docker/refs/heads/main/palworld_wine_docker_install.sh" \
  -o palworld_wine_docker_install.sh

chmod +x palworld_wine_docker_install.sh

./palworld_wine_docker_install.sh

```

## Installation Path

By default, the project is installed to:

```bash
~/palworld-wine-docker
```

Main generated files:

```text
~/palworld-wine-docker/
├── compose.yaml
├── Dockerfile
├── entrypoint.sh
├── run-palworld.sh
├── pal.sh
├── default.env
├── data/
│   ├── server/
│   ├── steamcmd/
│   └── wineprefix/
└── backups/
```

## Configuration

The main configuration file is:

```bash
~/palworld-wine-docker/default.env
```

Important values:

```env
SERVER_NAME=PalWorld
SERVER_DESCRIPTION=pal
SERVER_PASSWORD=1111
ADMIN_PASSWORD=generated_random_password
PUBLIC_PORT=8211

INSTALL_PALDEFENDER=true
INSTALL_UE4SS=true
```

The installer generates a random admin password by default.

After installation, check it with:

```bash
cd ~/palworld-wine-docker
grep ADMIN_PASSWORD default.env
```

## Server Management

Go to the project directory:

```bash
cd ~/palworld-wine-docker
```

Start server:

```bash
./pal.sh start
```

Stop server:

```bash
./pal.sh stop
```

Restart server:

```bash
./pal.sh restart
```

View logs:

```bash
./pal.sh logs
```

Check status:

```bash
./pal.sh status
```

Check ports, mod files, and environment summary:

```bash
./pal.sh check
```

Open container shell:

```bash
./pal.sh shell
```

## Update Server

To update the Palworld server and reinstall mods:

```bash
cd ~/palworld-wine-docker
./pal.sh update
```

The update command will:

1. Stop the server
2. Create a backup
3. Run SteamCMD update
4. Reinstall PalDefender and UE4SS
5. Start the server again

Backups are stored in:

```bash
~/palworld-wine-docker/backups
```

## PalDefender Admin IP Whitelist

PalDefender may require your public IP to use admin commands.

Check your PC public IP:

```bash
curl ifconfig.me
```

Then add it:

```bash
cd ~/palworld-wine-docker
./pal.sh adminip YOUR_PUBLIC_IP
```

Example:

```bash
./pal.sh adminip 123.45.67.89
```

Wildcard style may also be used if needed:

```bash
./pal.sh adminip 123.45.67.*
```

After that, restart or reconnect and test PalDefender commands in game.

Example:

```text
/adminlogin YOUR_ADMIN_PASSWORD
/getpos
```

## Disable Mod Loaders

If Palworld updates and PalDefender or UE4SS breaks the server, disable mod loader DLLs first:

```bash
cd ~/palworld-wine-docker
./pal.sh disablemods
```

This moves loader DLLs such as:

```text
d3d9.dll
d3d9_config.json
dwmapi.dll
xinput1_3.dll
```

into a disabled backup folder and starts the server without loading the mod loaders.

## Default Gameplay Settings

The installer applies several custom Palworld settings by default:

| Setting              | Value |
| -------------------- | ----: |
| EXP rate             |  3.0x |
| Capture rate         |  1.5x |
| Pal spawn rate       |  2.0x |
| Collection drop rate |  3.0x |
| Work speed rate      |  4.0x |
| Egg hatching time    |     0 |
| Death penalty        |  None |
| Base worker max      |    50 |
| Guild base max       |    15 |
| Item weight rate     |   0.1 |

These can be changed in:

```bash
~/palworld-wine-docker/default.env
```

Then restart:

```bash
cd ~/palworld-wine-docker
./pal.sh restart
```

## Save Data

Server save data is stored under:

```bash
~/palworld-wine-docker/data/server/Pal/Saved
```

Palworld settings file:

```bash
~/palworld-wine-docker/data/server/Pal/Saved/Config/WindowsServer/PalWorldSettings.ini
```

## Notes

* This project runs the Windows Palworld dedicated server through Wine.
* This is not the official Linux dedicated server.
* PalDefender and UE4SS compatibility may break after Palworld updates.
* Automatic update on every start is disabled by default.
* Manual update is recommended for modded servers.
* This project is intended for personal testing and private server use.

## Uninstall

Stop and remove the container:

```bash
cd ~/palworld-wine-docker
./pal.sh stop
```

Remove project files:

```bash
rm -rf ~/palworld-wine-docker
```

Remove Docker image if desired:

```bash
sudo docker image rm local/palworld-wine-ubuntu24:latest
```

## Disclaimer

This is an unofficial personal-use setup script.

Use at your own risk.
Palworld updates, Wine changes, PalDefender updates, or UE4SS updates may require script modifications.
