#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================

# Palworld Windows Dedicated Server via Wine + Docker

# Ubuntu 24.04 기준

#

# 설치:

# bash <(curl -fsSL https://raw.githubusercontent.com/shinyeonghun/palworld_wine_docker/refs/heads/main/palworld_wine_docker_install.sh)

#

# 환경변수 예:

# SERVER_PASSWORD=1123 ADMIN_PASSWORD=abcdef123456 bash palworld_wine_docker_install.sh

# BASE=/opt/palworld-wine-docker bash palworld_wine_docker_install.sh

# ============================================================

BASE="${BASE:-$HOME/palworld-wine-docker}"

PUID="${PUID:-$(id -u)}"
PGID="${PGID:-$(id -g)}"
TZ="${TZ:-Asia/Seoul}"

SERVER_NAME="${SERVER_NAME:-PengWorld}"
SERVER_DESCRIPTION="${SERVER_DESCRIPTION:-peng}"
SERVER_PASSWORD="${SERVER_PASSWORD:-1123}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-$(tr -d '-' < /proc/sys/kernel/random/uuid | cut -c1-16)}"

PUBLIC_IP="${PUBLIC_IP:-$(curl -4 -fsS --max-time 8 https://api.ipify.org 2>/dev/null || curl -4 -fsS --max-time 8 https://ifconfig.me 2>/dev/null || true)}"
PUBLIC_PORT="${PUBLIC_PORT:-8211}"

RCON_ENABLED="${RCON_ENABLED:-True}"
RCON_PORT="${RCON_PORT:-25575}"
RESTAPI_ENABLED="${RESTAPI_ENABLED:-True}"
RESTAPI_PORT="${RESTAPI_PORT:-8212}"
MAX_PLAYERS="${MAX_PLAYERS:-32}"

UPDATE_ON_START="${UPDATE_ON_START:-false}"
STEAMCMD_VALIDATE_FILES="${STEAMCMD_VALIDATE_FILES:-false}"
UPDATE_MODS_ON_START="${UPDATE_MODS_ON_START:-false}"

INSTALL_PALDEFENDER="${INSTALL_PALDEFENDER:-true}"
INSTALL_UE4SS="${INSTALL_UE4SS:-true}"

# 콤마 구분. 예: ADMIN_IPS=123.45.67.89,123.45.67.*

ADMIN_IPS="${ADMIN_IPS:-}"

log() {
echo
echo "===== $* ====="
}

die() {
echo "ERROR: $*" >&2
exit 1
}

ensure_ubuntu() {
source /etc/os-release || true

if [[ "${ID:-}" != "ubuntu" ]]; then
echo "주의: Ubuntu 기준 스크립트 현재: ${PRETTY_NAME:-unknown}"
fi

if [[ "${VERSION_ID:-}" != "24.04" ]]; then
echo "주의: Ubuntu 24.04 기준으로 제작됨. 현재: ${PRETTY_NAME:-unknown}"
fi
}

ensure_docker() {
log "Docker 설치/확인"

sudo timedatectl set-timezone "$TZ" 2>/dev/null || true

if ! command -v curl >/dev/null 2>&1; then
sudo apt update
sudo apt install -y curl ca-certificates
fi

if ! command -v docker >/dev/null 2>&1 || ! (docker compose version >/dev/null 2>&1 || sudo docker compose version >/dev/null 2>&1); then
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release

```
sudo install -m 0755 -d /etc/apt/keyrings

if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
fi

source /etc/os-release
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

fi

sudo systemctl enable --now docker >/dev/null 2>&1 || true

if docker ps >/dev/null 2>&1; then
DOCKER="docker"
else
DOCKER="sudo docker"
fi

export DOCKER
$DOCKER version >/dev/null
$DOCKER compose version >/dev/null
}

write_project_files() {
log "프로젝트 파일 생성"

mkdir -p "$BASE"/{data,mods,backups}
cd "$BASE"

if [[ ! -f default.env ]]; then
cat > default.env <<EOF

# Container

PUID=$PUID
PGID=$PGID
TZ=$TZ

# Server

SERVER_NAME=$SERVER_NAME
SERVER_DESCRIPTION=$SERVER_DESCRIPTION
ADMIN_PASSWORD=$ADMIN_PASSWORD
SERVER_PASSWORD=$SERVER_PASSWORD
PUBLIC_IP=$PUBLIC_IP
PUBLIC_PORT=$PUBLIC_PORT
RCON_ENABLED=$RCON_ENABLED
RCON_PORT=$RCON_PORT
RESTAPI_ENABLED=$RESTAPI_ENABLED
RESTAPI_PORT=$RESTAPI_PORT
MAX_PLAYERS=$MAX_PLAYERS

# Update

UPDATE_ON_START=$UPDATE_ON_START
STEAMCMD_VALIDATE_FILES=$STEAMCMD_VALIDATE_FILES
UPDATE_MODS_ON_START=$UPDATE_MODS_ON_START

# Mods

INSTALL_PALDEFENDER=$INSTALL_PALDEFENDER
INSTALL_UE4SS=$INSTALL_UE4SS

# PalDefender admin whitelist

# 콤마 구분 가능: 123.45.67.89,123.45.67.*

# 첫 실행 후 ./pal.sh adminip IP로 추가

ADMIN_IPS=$ADMIN_IPS

# Gameplay

EXP_RATE=3.000000
PAL_CAPTURE_RATE=1.500000
PAL_SPAWN_NUM_RATE=2.000000
PLAYER_DAMAGE_RATE_ATTACK=1.500000
PLAYER_STOMACH_DECREACE_RATE=0.300000
PAL_STOMACH_DECREACE_RATE=0.200000
PAL_STAMINA_DECREACE_RATE=0.200000
PAL_AUTO_HP_REGENE_RATE=4.000000
PAL_AUTO_HP_REGENE_RATE_IN_SLEEP=4.000000
COLLECTION_DROP_RATE=3.000000
COLLECTION_OBJECT_HP_RATE=0.500000
COLLECTION_OBJECT_RESPAWN_SPEED_RATE=3.000000
ENEMY_DROP_ITEM_RATE=2.000000
DEATH_PENALTY=None
ENABLE_INVADER_ENEMY=False
DROP_ITEM_MAX_NUM=3000
BASE_CAMP_MAX_NUM=128
BASE_CAMP_WORKER_MAXNUM=50
BASE_CAMP_MAX_NUM_IN_GUILD=15
GUILD_PLAYER_MAX_NUM=20
PAL_EGG_DEFAULT_HATCHING_TIME=0.000000
WORK_SPEED_RATE=4.000000
AUTO_SAVE_SPAN=30.000000
ITEM_WEIGHT_RATE=0.100000
EOF
else
echo "default.env 이미 있으면 → 덮어쓰지 않음"
fi

cat > compose.yaml <<'EOF'
services:
palworld-wine:
build: .
image: local/palworld-wine-ubuntu24:latest
container_name: palworld-wine
restart: unless-stopped
env_file:
- default.env
ports:
- "8211:8211/udp"
- "25575:25575/tcp"
- "8212:8212/tcp"
- "27015:27015/tcp"
- "27015:27015/udp"
volumes:
- ./data:/data
EOF

cat > Dockerfile <<'EOF'
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

RUN dpkg --add-architecture i386 
&& apt-get update 
&& apt-get install -y --no-install-recommends 
ca-certificates curl wget gnupg unzip tar xz-utils 
xvfb cabextract p7zip-full python3 procps gosu 
lib32gcc-s1 locales 
&& locale-gen en_US.UTF-8 
&& mkdir -pm755 /etc/apt/keyrings 
&& wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key 
&& wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/noble/winehq-noble.sources 
&& apt-get update 
&& apt-get install -y --install-recommends winehq-stable 
&& wget -O /usr/local/bin/winetricks https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks 
&& chmod +x /usr/local/bin/winetricks 
&& apt-get clean 
&& rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
COPY run-palworld.sh /opt/run-palworld.sh

RUN chmod +x /entrypoint.sh /opt/run-palworld.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["server"]
EOF

cat > entrypoint.sh <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

if getent group "$PGID" >/dev/null 2>&1; then
GROUP_NAME="$(getent group "$PGID" | cut -d: -f1)"
else
GROUP_NAME="steam"
groupadd -g "$PGID" "$GROUP_NAME"
fi

if ! id steam >/dev/null 2>&1; then
useradd -m -u "$PUID" -g "$PGID" -s /bin/bash steam
else
usermod -o -u "$PUID" -g "$PGID" steam 2>/dev/null || true
fi

mkdir -p /data
chown -R steam:"$GROUP_NAME" /data 2>/dev/null || chown -R steam:steam /data 2>/dev/null || true

exec gosu steam /opt/run-palworld.sh "$@"
EOF

cat > run-palworld.sh <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

CMD="${1:-server}"

export HOME="/home/steam"
export WINEPREFIX="/data/wineprefix"
export WINEARCH=win64
export WINEDEBUG=-all
export WINEDLLOVERRIDES="mscoree,mshtml=;d3d9=n,b;dwmapi=n,b"

DATA="/data"
SERVER="$DATA/server"
STEAMCMD="$DATA/steamcmd/steamcmd.sh"
LOGS="$DATA/logs"
WIN64="$SERVER/Pal/Binaries/Win64"
SETTINGS="$SERVER/Pal/Saved/Config/WindowsServer/PalWorldSettings.ini"

mkdir -p "$DATA" "$SERVER" "$LOGS" "$DATA/steamcmd"

log() {
echo "[$(date '+%F %T')] $*"
}

github_latest_zip() {
local repo="$1"
local mode="${2:-normal}"

python3 - "$repo" "$mode" <<'PY'
import json
import sys
import urllib.request

repo = sys.argv[1]
mode = sys.argv[2]

apis = []
if mode == "ue4ss":
apis.append(f"https://api.github.com/repos/{repo}/releases/tags/experimental-latest")
apis.append(f"https://api.github.com/repos/{repo}/releases/latest")

for api in apis:
try:
req = urllib.request.Request(api, headers={"User-Agent": "palworld-wine-docker"})
with urllib.request.urlopen(req, timeout=20) as r:
data = json.load(r)

```
    assets = data.get("assets", [])
    candidates = []

    for a in assets:
        name = a.get("name", "")
        url = a.get("browser_download_url", "")
        low = name.lower()

        if not low.endswith(".zip"):
            continue
        if any(x in low for x in ["source", "symbols", "pdb"]):
            continue
        if mode == "ue4ss" and "dev" in low:
            continue

        candidates.append((name, url))

    if candidates:
        print(candidates[0][1])
        raise SystemExit(0)

except Exception:
    pass
```

raise SystemExit(f"zip asset not found: {repo}")
PY
}

install_steamcmd() {
if [[ ! -x "$STEAMCMD" ]]; then
log "Installing SteamCMD..."
cd "$DATA/steamcmd"
curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -
fi

"$STEAMCMD" +quit >/dev/null || true
}

init_wine() {
if [[ ! -f "$WINEPREFIX/drive_c/windows/system32/kernel32.dll" ]]; then
log "Initializing Wine prefix..."
rm -rf "$WINEPREFIX"
mkdir -p "$WINEPREFIX"
timeout 180s xvfb-run -a wineboot -u || true
wineserver -k 2>/dev/null || true
fi

if ! find "$WINEPREFIX/drive_c/windows/system32" ( -iname 'vcruntime140*.dll' -o -iname 'msvcp140*.dll' ) 2>/dev/null | grep -q .; then
log "Installing vcrun2022..."
xvfb-run -a winetricks -q vcrun2022
wineserver -k 2>/dev/null || true
fi
}

update_server() {
local validate_arg=""
if [[ "${STEAMCMD_VALIDATE_FILES:-false}" == "true" ]]; then
validate_arg="validate"
fi

log "Installing/updating Palworld Windows Dedicated Server..."

"$STEAMCMD" 
+@sSteamCmdForcePlatformType windows 
+force_install_dir "$SERVER" 
+login anonymous 
+app_update 2394010 $validate_arg 
+quit
}

apply_settings() {
if [[ ! -f "$SETTINGS" ]]; then
log "Creating PalWorldSettings.ini..."
mkdir -p "$(dirname "$SETTINGS")"

```
if [[ ! -f "$SERVER/DefaultPalWorldSettings.ini" ]]; then
  echo "DefaultPalWorldSettings.ini not found. Server install may have failed." >&2
  exit 1
fi

cp "$SERVER/DefaultPalWorldSettings.ini" "$SETTINGS"
```

fi

log "Applying Palworld settings..."

SETTINGS_FILE="$SETTINGS" python3 - <<'PY'
from pathlib import Path
import os
import re

file = Path(os.environ["SETTINGS_FILE"])
text = file.read_text(encoding="utf-8")

def q(v):
return '"' + str(v).replace('"', '') + '"'

repls = {
"ServerName": q(os.getenv("SERVER_NAME", "PengWorld")),
"ServerDescription": q(os.getenv("SERVER_DESCRIPTION", "peng")),
"AdminPassword": q(os.getenv("ADMIN_PASSWORD", "changeme")),
"ServerPassword": q(os.getenv("SERVER_PASSWORD", "1123")),
"PublicIP": q(os.getenv("PUBLIC_IP", "")),
"PublicPort": os.getenv("PUBLIC_PORT", "8211"),
"RCONEnabled": os.getenv("RCON_ENABLED", "True"),
"RCONPort": os.getenv("RCON_PORT", "25575"),
"RESTAPIEnabled": os.getenv("RESTAPI_ENABLED", "True"),
"RESTAPIPort": os.getenv("RESTAPI_PORT", "8212"),
"ServerPlayerMaxNum": os.getenv("MAX_PLAYERS", "32"),

```
"ExpRate": os.getenv("EXP_RATE", "3.000000"),
"PalCaptureRate": os.getenv("PAL_CAPTURE_RATE", "1.500000"),
"PalSpawnNumRate": os.getenv("PAL_SPAWN_NUM_RATE", "2.000000"),
"PlayerDamageRateAttack": os.getenv("PLAYER_DAMAGE_RATE_ATTACK", "1.500000"),
"PlayerStomachDecreaceRate": os.getenv("PLAYER_STOMACH_DECREACE_RATE", "0.300000"),
"PalStomachDecreaceRate": os.getenv("PAL_STOMACH_DECREACE_RATE", "0.200000"),
"PalStaminaDecreaceRate": os.getenv("PAL_STAMINA_DECREACE_RATE", "0.200000"),
"PalAutoHPRegeneRate": os.getenv("PAL_AUTO_HP_REGENE_RATE", "4.000000"),
"PalAutoHpRegeneRateInSleep": os.getenv("PAL_AUTO_HP_REGENE_RATE_IN_SLEEP", "4.000000"),
"CollectionDropRate": os.getenv("COLLECTION_DROP_RATE", "3.000000"),
"CollectionObjectHpRate": os.getenv("COLLECTION_OBJECT_HP_RATE", "0.500000"),
"CollectionObjectRespawnSpeedRate": os.getenv("COLLECTION_OBJECT_RESPAWN_SPEED_RATE", "3.000000"),
"EnemyDropItemRate": os.getenv("ENEMY_DROP_ITEM_RATE", "2.000000"),
"DeathPenalty": os.getenv("DEATH_PENALTY", "None"),
"bEnableInvaderEnemy": os.getenv("ENABLE_INVADER_ENEMY", "False"),
"DropItemMaxNum": os.getenv("DROP_ITEM_MAX_NUM", "3000"),
"BaseCampMaxNum": os.getenv("BASE_CAMP_MAX_NUM", "128"),
"BaseCampWorkerMaxNum": os.getenv("BASE_CAMP_WORKER_MAXNUM", "50"),
"BaseCampMaxNumInGuild": os.getenv("BASE_CAMP_MAX_NUM_IN_GUILD", "15"),
"GuildPlayerMaxNum": os.getenv("GUILD_PLAYER_MAX_NUM", "20"),
"PalEggDefaultHatchingTime": os.getenv("PAL_EGG_DEFAULT_HATCHING_TIME", "0.000000"),
"WorkSpeedRate": os.getenv("WORK_SPEED_RATE", "4.000000"),
"AutoSaveSpan": os.getenv("AUTO_SAVE_SPAN", "30.000000"),
"ItemWeightRate": os.getenv("ITEM_WEIGHT_RATE", "0.100000"),
```

}

for key, value in repls.items():
text, count = re.subn(rf'{key}=("[^"]*"|([^)]*)|[^,)]*)', f'{key}={value}', text)

```
if count == 0 and "OptionSettings=(" in text:
    text = text.replace("OptionSettings=(", f"OptionSettings=({key}={value},", 1)
```

file.write_text(text, encoding="utf-8")
PY
}

install_paldefender() {
[[ "${INSTALL_PALDEFENDER:-true}" == "true" ]] || return 0

mkdir -p "$WIN64"

if [[ -f "$WIN64/PalDefender.dll" && -f "$WIN64/d3d9.dll" && "${UPDATE_MODS_ON_START:-false}" != "true" ]]; then
log "PalDefender already installed."
else
log "Installing PalDefender..."

```
local tmp="/tmp/paldefender"
rm -rf "$tmp"
mkdir -p "$tmp"

local url=""
url="$(github_latest_zip "Ultimeit/PalDefender" "normal" 2>/dev/null || true)"

if [[ -z "$url" ]]; then
  url="$(github_latest_zip "Ultimeit/palguard" "normal" 2>/dev/null || true)"
fi

if [[ -z "$url" ]]; then
  echo "PalDefender release zip not found." >&2
  exit 1
fi

log "PalDefender URL: $url"

curl -L "$url" -o "$tmp/paldefender.zip"
unzip -o "$tmp/paldefender.zip" -d "$tmp/extract" >/dev/null

local pd_dll
pd_dll="$(find "$tmp/extract" -iname 'PalDefender.dll' | head -1 || true)"

if [[ -z "$pd_dll" ]]; then
  echo "PalDefender.dll not found in zip." >&2
  exit 1
fi

local pd_root
pd_root="$(dirname "$pd_dll")"

cp -af "$pd_root"/. "$WIN64"/

cat > "$WIN64/d3d9_config.json" <<'JSON'
```

{
"load_dlls": [
"PalDefender.dll"
]
}
JSON
fi

if [[ -n "${ADMIN_IPS:-}" && -f "$WIN64/PalDefender/Config.json" ]]; then
log "Patching PalDefender admin IP whitelist..."

```
CFG="$WIN64/PalDefender/Config.json" ADMIN_IPS="$ADMIN_IPS" python3 - <<'PY'
```

import json
import os
from pathlib import Path

cfg = Path(os.environ["CFG"])
ips = [x.strip() for x in os.environ.get("ADMIN_IPS", "").split(",") if x.strip()]

data = json.loads(cfg.read_text(encoding="utf-8-sig"))
data["useAdminWhitelist"] = True

old = data.get("adminIPs")
if not isinstance(old, list):
old = []

for ip in ips:
if ip not in old:
old.append(ip)

data["adminIPs"] = old
cfg.write_text(json.dumps(data, indent=4, ensure_ascii=False), encoding="utf-8")
PY
fi
}

install_ue4ss() {
[[ "${INSTALL_UE4SS:-true}" == "true" ]] || return 0

mkdir -p "$WIN64"

if [[ -f "$WIN64/dwmapi.dll" && -d "$WIN64/ue4ss" && "${UPDATE_MODS_ON_START:-false}" != "true" ]]; then
log "UE4SS already installed."
return 0
fi

log "Installing UE4SS..."

rm -f "$WIN64/xinput1_3.dll"

local tmp="/tmp/ue4ss"
rm -rf "$tmp"
mkdir -p "$tmp"

local url
url="$(github_latest_zip "UE4SS-RE/RE-UE4SS" "ue4ss")"

log "UE4SS URL: $url"

curl -L "$url" -o "$tmp/ue4ss.zip"
unzip -o "$tmp/ue4ss.zip" -d "$tmp/extract" >/dev/null

local dwm ue4ss_dll ue4ss_dir
dwm="$(find "$tmp/extract" -iname 'dwmapi.dll' | head -1 || true)"
ue4ss_dll="$(find "$tmp/extract" -iname 'UE4SS.dll' | head -1 || true)"
ue4ss_dir="$(find "$tmp/extract" -type d -iname 'ue4ss' | head -1 || true)"

if [[ -z "$dwm" || -z "$ue4ss_dll" ]]; then
echo "UE4SS files not found in zip." >&2
exit 1
fi

cp -f "$dwm" "$WIN64/dwmapi.dll"

if [[ -n "$ue4ss_dir" ]]; then
rm -rf "$WIN64/ue4ss"
cp -a "$ue4ss_dir" "$WIN64/ue4ss"
else
local ue4ss_root
ue4ss_root="$(dirname "$ue4ss_dll")"
cp -af "$ue4ss_root"/. "$WIN64"/
fi

local ue4ss_ini
ue4ss_ini="$(find "$WIN64" -maxdepth 4 -iname 'UE4SS-settings.ini' | head -1 || true)"

if [[ -n "$ue4ss_ini" ]]; then
if grep -q '^bUseUObjectArrayCache=' "$ue4ss_ini"; then
sed -i 's/^bUseUObjectArrayCache=.*/bUseUObjectArrayCache=false/' "$ue4ss_ini"
else
echo 'bUseUObjectArrayCache=false' >> "$ue4ss_ini"
fi
fi
}

run_server() {
cd "$SERVER"

log "Starting Palworld server..."

exec xvfb-run -a wine PalServer.exe 
-port="${PUBLIC_PORT:-8211}" 
-useperfthreads 
-NoAsyncLoadingThread 
-UseMultithreadForDS
}

install_steamcmd
init_wine

case "$CMD" in
update)
update_server
apply_settings
install_paldefender
install_ue4ss
log "Update complete."
exit 0
;;
server)
if [[ ! -f "$SERVER/PalServer.exe" || "${UPDATE_ON_START:-false}" == "true" ]]; then
update_server
fi

```
apply_settings
install_paldefender
install_ue4ss
run_server
;;
```

bash)
exec bash
;;
*)
exec "$@"
;;
esac
EOF

cat > pal.sh <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

BASE="$(cd "$(dirname "$0")" && pwd)"
cd "$BASE"

if docker ps >/dev/null 2>&1; then
DOCKER="docker"
else
DOCKER="sudo docker"
fi

case "${1:-}" in
start)
$DOCKER compose up -d
;;
stop)
$DOCKER compose down
;;
restart)
$DOCKER compose down
$DOCKER compose up -d
;;
logs)
$DOCKER logs -f --tail=150 palworld-wine
;;
status)
$DOCKER compose ps
$DOCKER ps --filter name=palworld-wine
;;
shell)
$DOCKER exec -it palworld-wine bash
;;
update)
mkdir -p backups

```
echo "서버 중지..."
$DOCKER compose down || true

echo "백업 생성..."
tar -czvf "backups/palworld-before-update-$(date +%Y%m%d_%H%M%S).tar.gz" \
  data/server/Pal/Saved \
  data/server/Pal/Binaries/Win64 \
  2>/dev/null || true

echo "SteamCMD 업데이트 + 모드 재설치..."
$DOCKER compose run --rm \
  -e UPDATE_ON_START=true \
  -e UPDATE_MODS_ON_START=true \
  palworld-wine update

echo "서버 시작..."
$DOCKER compose up -d
;;
```

adminip)
IP="${2:-}"

```
if [[ -z "$IP" ]]; then
  echo "사용법: ./pal.sh adminip IP"
  echo "예: ./pal.sh adminip 123.45.67.89"
  exit 1
fi

CFG="$BASE/data/server/Pal/Binaries/Win64/PalDefender/Config.json"

if [[ ! -f "$CFG" ]]; then
  echo "서버를 켠 뒤 PalDefender 폴더 생성 확인 후 다시 실행."
  exit 1
fi

$DOCKER compose down || true

cp "$CFG" "$CFG.bak.$(date +%Y%m%d_%H%M%S)"

python3 - "$CFG" "$IP" <<'PY'
```

import json
import sys
from pathlib import Path

cfg = Path(sys.argv[1])
ip = sys.argv[2].strip()

data = json.loads(cfg.read_text(encoding="utf-8-sig"))
data["useAdminWhitelist"] = True

ips = data.get("adminIPs")
if not isinstance(ips, list):
ips = []

if ip not in ips:
ips.append(ip)

data["adminIPs"] = ips

cfg.write_text(json.dumps(data, indent=4, ensure_ascii=False), encoding="utf-8")
print(json.dumps({"useAdminWhitelist": data["useAdminWhitelist"], "adminIPs": data["adminIPs"]}, indent=4))
PY

```
$DOCKER compose up -d
;;
```

check)
echo "===== docker ====="
$DOCKER ps --filter name=palworld-wine || true

```
echo
echo "===== compose ====="
$DOCKER compose ps || true

echo
echo "===== ports ====="
sudo ss -lunpt | grep 8211 || true

echo
echo "===== mod files ====="
find data/server/Pal/Binaries/Win64 -maxdepth 5 \
  \( \
    -iname 'PalDefender.dll' \
    -o -iname 'd3d9.dll' \
    -o -iname 'd3d9_config.json' \
    -o -iname 'dwmapi.dll' \
    -o -iname 'UE4SS.dll' \
    -o -iname 'UE4SS-settings.ini' \
    -o -iname '*UE4SS*.log' \
  \) -print 2>/dev/null || true

echo
echo "===== env summary ====="
grep -E '^(SERVER_NAME|SERVER_PASSWORD|ADMIN_PASSWORD|PUBLIC_IP|PUBLIC_PORT|RCON_PORT|RESTAPI_PORT)=' default.env 2>/dev/null || true
;;
```

disablemods)
echo "서버 중지..."
$DOCKER compose down || true

```
WIN64="$BASE/data/server/Pal/Binaries/Win64"
DISABLED="$WIN64/_disabled_mods_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$DISABLED"

for f in d3d9.dll d3d9_config.json dwmapi.dll xinput1_3.dll; do
  if [[ -e "$WIN64/$f" ]]; then
    mv "$WIN64/$f" "$DISABLED/"
  fi
done

echo "모드 로더 DLL 비활성화 완료: $DISABLED"
echo "서버 시작..."
$DOCKER compose up -d
;;
```

*)
echo "사용법:"
echo "  ./pal.sh start          서버 시작"
echo "  ./pal.sh stop           서버 종료"
echo "  ./pal.sh restart        서버 재시작"
echo "  ./pal.sh logs           로그 보기"
echo "  ./pal.sh status         상태 보기"
echo "  ./pal.sh update         서버/모드 업데이트"
echo "  ./pal.sh adminip IP     PalDefender admin IP 추가"
echo "  ./pal.sh check          포트/모드/설정 확인"
echo "  ./pal.sh shell          컨테이너 쉘"
echo "  ./pal.sh disablemods    d3d9/dwmapi 로더 DLL 비활성화"
exit 1
;;
esac
EOF

chmod +x entrypoint.sh run-palworld.sh pal.sh
}

start_stack() {
log "기존 수동 systemd 서버 중지"
sudo systemctl stop palworld-wine 2>/dev/null || true

log "기존 같은 이름 Docker 컨테이너 제거"
$DOCKER rm -f palworld-wine 2>/dev/null || true

cd "$BASE"

log "Docker 이미지 빌드"
$DOCKER compose build

log "서버 시작"
$DOCKER compose up -d
}

print_done() {
echo
echo "============================================================"
echo "설치 완료"
echo "============================================================"
echo
echo "경로:"
echo "  $BASE"
echo
echo "처음 실행은 Wine/SteamCMD/서버 다운로드 때문에 10~30분 걸릴 수 있음."
echo
echo "로그:"
echo "  cd $BASE && ./pal.sh logs"
echo
echo "상태 확인:"
echo "  cd $BASE && ./pal.sh check"
echo
echo "접속:"
echo "  ${PUBLIC_IP:-서버외부IP}:$PUBLIC_PORT"
echo "  서버 비번: $SERVER_PASSWORD"
echo
echo "Admin Password:"
echo "  $ADMIN_PASSWORD"
echo
echo "PalDefender admin whitelist:"
echo "  cd $BASE && ./pal.sh adminip 네_PC_공인IP"
echo
echo "관리 명령어:"
echo "  ./pal.sh start"
echo "  ./pal.sh stop"
echo "  ./pal.sh restart"
echo "  ./pal.sh logs"
echo "  ./pal.sh update"
echo
}

main() {
ensure_ubuntu
ensure_docker
write_project_files
start_stack
print_done
}

main "$@"
