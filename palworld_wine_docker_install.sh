cd ~

cat > install-palworld-wine-docker.sh <<'INSTALLER'
#!/usr/bin/env bash
set -euo pipefail

BASE="${BASE:-$HOME/palworld-wine-docker}"
PUBLIC_IP="${PUBLIC_IP:-$(curl -4 -s ifconfig.me || true)}"
PUID="${PUID:-$(id -u)}"
PGID="${PGID:-$(id -g)}"

echo "===== Palworld Wine Docker Installer ====="
echo "BASE=$BASE"
echo "PUBLIC_IP=$PUBLIC_IP"
echo "PUID=$PUID PGID=$PGID"

source /etc/os-release || true
if [[ "${ID:-}" != "ubuntu" || "${VERSION_ID:-}" != "24.04" ]]; then
  echo "주의: 이 스크립트는 Ubuntu 24.04 기준임. 현재: ${PRETTY_NAME:-unknown}"
fi

sudo timedatectl set-timezone Asia/Seoul || true

echo "===== Docker 설치 확인 ====="
if ! command -v docker >/dev/null 2>&1; then
  sudo apt update
  sudo apt install -y ca-certificates curl gnupg lsb-release

  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

  sudo apt update
  sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

if docker ps >/dev/null 2>&1; then
  DOCKER="docker"
else
  DOCKER="sudo docker"
fi

echo "===== 기존 같은 이름 컨테이너 중지 ====="
$DOCKER rm -f palworld-wine 2>/dev/null || true

echo "===== 폴더 생성 ====="
mkdir -p "$BASE"/{data,mods,backups}
cd "$BASE"

cat > default.env <<EOF
# Container
PUID=$PUID
PGID=$PGID
TZ=Asia/Seoul

# Server
SERVER_NAME=PengWorld
SERVER_DESCRIPTION=peng
ADMIN_PASSWORD=peng1123
SERVER_PASSWORD=1123
PUBLIC_IP=$PUBLIC_IP
PUBLIC_PORT=8211
RCON_ENABLED=True
RCON_PORT=25575
RESTAPI_ENABLED=True
RESTAPI_PORT=8212
MAX_PLAYERS=32

# Update
UPDATE_ON_START=false
STEAMCMD_VALIDATE_FILES=false
UPDATE_MODS_ON_START=false

# Mods
INSTALL_PALDEFENDER=true
INSTALL_UE4SS=true

# PalDefender admin whitelist는 첫 실행 후 ./pal.sh adminip IP
ADMIN_IPS=

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

RUN dpkg --add-architecture i386 \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
    ca-certificates curl wget gnupg unzip tar xz-utils \
    xvfb xauth cabextract p7zip-full python3 procps iproute2 gosu \
    lib32gcc-s1 locales \
 && locale-gen en_US.UTF-8 \
 && mkdir -pm755 /etc/apt/keyrings \
 && wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key \
 && wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/noble/winehq-noble.sources \
 && apt-get update \
 && apt-get install -y --install-recommends winehq-stable \
 && wget -O /usr/local/bin/winetricks https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks \
 && chmod +x /usr/local/bin/winetricks \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
COPY run-palworld.sh /opt/run-palworld.sh

RUN chmod +x /entrypoint.sh /opt/run-palworld.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["server"]
EOF

cat > entrypoint.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

if ! getent group steam >/dev/null; then
  groupadd -g "$PGID" steam
else
  groupmod -o -g "$PGID" steam 2>/dev/null || true
fi

if ! id steam >/dev/null 2>&1; then
  useradd -m -u "$PUID" -g "$PGID" -s /bin/bash steam
else
  usermod -o -u "$PUID" -g "$PGID" steam 2>/dev/null || true
fi

mkdir -p /data
chown -R steam:"$GROUP_NAME" /data 2>/dev/null || chown -R steam:steam /data 2>/dev/null || true

# Xvfb needs this directory, but the server runs as non-root.
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix
chown root:root /tmp/.X11-unix 2>/dev/null || true

exec gosu steam /opt/run-palworld.sh "$@"
EOF

cat > run-palworld.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

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

  if ! find "$WINEPREFIX/drive_c/windows/system32" -iname 'vcruntime140*.dll' -o -iname 'msvcp140*.dll' | grep -q .; then
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
  "$STEAMCMD" \
    +@sSteamCmdForcePlatformType windows \
    +force_install_dir "$SERVER" \
    +login anonymous \
    +app_update 2394010 $validate_arg \
    +quit
}

apply_settings() {
  if [[ ! -f "$SETTINGS" ]]; then
    log "Creating PalWorldSettings.ini..."
    mkdir -p "$(dirname "$SETTINGS")"
    cp "$SERVER/DefaultPalWorldSettings.ini" "$SETTINGS"
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
    "AdminPassword": q(os.getenv("ADMIN_PASSWORD", "peng1123")),
    "ServerPassword": q(os.getenv("SERVER_PASSWORD", "1123")),
    "PublicIP": q(os.getenv("PUBLIC_IP", "")),
    "PublicPort": os.getenv("PUBLIC_PORT", "8211"),
    "RCONEnabled": os.getenv("RCON_ENABLED", "True"),
    "RCONPort": os.getenv("RCON_PORT", "25575"),
    "RESTAPIEnabled": os.getenv("RESTAPI_ENABLED", "True"),
    "RESTAPIPort": os.getenv("RESTAPI_PORT", "8212"),
    "ServerPlayerMaxNum": os.getenv("MAX_PLAYERS", "32"),

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
}

for key, value in repls.items():
    text, count = re.subn(rf'{key}=("[^"]*"|\([^)]*\)|[^,\)]*)', f'{key}={value}', text)
    if count == 0 and "OptionSettings=(" in text:
        text = text.replace("OptionSettings=(", f"OptionSettings=({key}={value},", 1)

file.write_text(text, encoding="utf-8")
PY
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
        with urllib.request.urlopen(api) as r:
            data = json.load(r)
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
            raise SystemExit
    except Exception:
        pass

raise SystemExit(f"zip asset not found: {repo}")
PY
}

install_paldefender() {
  [[ "${INSTALL_PALDEFENDER:-true}" == "true" ]] || return 0
  mkdir -p "$WIN64"

  if [[ -f "$WIN64/PalDefender.dll" && -f "$WIN64/d3d9.dll" && "${UPDATE_MODS_ON_START:-false}" != "true" ]]; then
    log "PalDefender already installed."
  else
    log "Installing PalDefender..."
    local tmp="/tmp/paldefender"
    rm -rf "$tmp"
    mkdir -p "$tmp"

    local url
    url="$(github_latest_zip "Ultimeit/PalDefender" "normal")"
    log "PalDefender URL: $url"

    curl -L "$url" -o "$tmp/paldefender.zip"
    unzip -o "$tmp/paldefender.zip" -d "$tmp/extract" >/dev/null

    PD_DLL="$(find "$tmp/extract" -iname 'PalDefender.dll' | head -1)"
    if [[ -z "$PD_DLL" ]]; then
      echo "PalDefender.dll not found" >&2
      exit 1
    fi

    PD_ROOT="$(dirname "$PD_DLL")"
    cp -af "$PD_ROOT"/. "$WIN64"/

    cat > "$WIN64/d3d9_config.json" <<'JSON'
{
  "load_dlls": [
    "PalDefender.dll"
  ]
}
JSON
  fi

  if [[ -n "${ADMIN_IPS:-}" && -f "$WIN64/PalDefender/Config.json" ]]; then
    log "Patching PalDefender admin IP whitelist..."
    CFG="$WIN64/PalDefender/Config.json" ADMIN_IPS="$ADMIN_IPS" python3 - <<'PY'
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

  DWM="$(find "$tmp/extract" -iname 'dwmapi.dll' | head -1)"
  UE4SS_DLL="$(find "$tmp/extract" -iname 'UE4SS.dll' | head -1)"
  UE4SS_DIR="$(find "$tmp/extract" -type d -iname 'ue4ss' | head -1)"

  if [[ -z "$DWM" || -z "$UE4SS_DLL" ]]; then
    echo "UE4SS files not found" >&2
    exit 1
  fi

  cp -f "$DWM" "$WIN64/dwmapi.dll"

  if [[ -n "$UE4SS_DIR" ]]; then
    rm -rf "$WIN64/ue4ss"
    cp -a "$UE4SS_DIR" "$WIN64/ue4ss"
  else
    UE4SS_ROOT="$(dirname "$UE4SS_DLL")"
    cp -af "$UE4SS_ROOT"/. "$WIN64"/
  fi

  UE4SS_INI="$(find "$WIN64" -maxdepth 4 -iname 'UE4SS-settings.ini' | head -1 || true)"
  if [[ -n "$UE4SS_INI" ]]; then
    if grep -q '^bUseUObjectArrayCache=' "$UE4SS_INI"; then
      sed -i 's/^bUseUObjectArrayCache=.*/bUseUObjectArrayCache=false/' "$UE4SS_INI"
    else
      echo 'bUseUObjectArrayCache=false' >> "$UE4SS_INI"
    fi
  fi
}

run_server() {
  cd "$SERVER"

  log "Starting Xvfb..."
  pkill -f "Xvfb :99" 2>/dev/null || true
  Xvfb :99 -screen 0 1280x1024x24 -nolisten tcp &
  XVFB_PID="$!"

  sleep 3

  export DISPLAY=:99

  log "Starting Palworld server with Wine..."
  log "WorkingDirectory=$(pwd)"
  log "WineVersion=$(wine --version || true)"
  log "PalServer=$(ls -al PalServer.exe || true)"

  exec wine PalServer.exe \
    -port="${PUBLIC_PORT:-8211}" \
    -useperfthreads \
    -NoAsyncLoadingThread \
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
    apply_settings
    install_paldefender
    install_ue4ss
    run_server
    ;;
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
set -euo pipefail

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
    echo "서버 중지..."
    $DOCKER compose down || true

    echo "백업 생성..."
    tar -czvf "backups/palworld-before-update-$(date +%Y%m%d_%H%M%S).tar.gz" data/server/Pal/Saved data/server/Pal/Binaries/Win64 2>/dev/null || true

    echo "SteamCMD 업데이트..."
    $DOCKER compose run --rm \
      -e UPDATE_ON_START=true \
      -e UPDATE_MODS_ON_START=true \
      palworld-wine update

    echo "서버 시작..."
    $DOCKER compose up -d
    ;;
  adminip)
    IP="${2:-}"
    if [[ -z "$IP" ]]; then
      echo "사용법: ./pal.sh adminip IP"
      echo "예: ./pal.sh adminip 123.45.67.89"
      exit 1
    fi

    CFG="$BASE/data/server/Pal/Binaries/Win64/PalDefender/Config.json"
    if [[ ! -f "$CFG" ]]; then
      exit 1
    fi

    $DOCKER compose down || true

    cp "$CFG" "$CFG.bak.$(date +%Y%m%d_%H%M%S)"
    python3 - "$CFG" "$IP" <<'PY'
import json, sys
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

    $DOCKER compose up -d
    ;;
  check)
    echo "===== docker ====="
    $DOCKER ps --filter name=palworld-wine
    echo
    echo "===== ports ====="
    sudo ss -lunpt | grep 8211 || true
    echo
    echo "===== mod files ====="
    find data/server/Pal/Binaries/Win64 -maxdepth 4 \( -iname 'PalDefender.dll' -o -iname 'd3d9.dll' -o -iname 'dwmapi.dll' -o -iname 'UE4SS.dll' -o -iname 'UE4SS-settings.ini' -o -iname '*UE4SS*.log' \) -print 2>/dev/null || true
    ;;
  *)
    echo "사용법:"
    echo "  ./pal.sh start      서버 시작"
    echo "  ./pal.sh stop       서버 종료"
    echo "  ./pal.sh restart    서버 재시작"
    echo "  ./pal.sh logs       로그 보기"
    echo "  ./pal.sh status     상태 보기"
    echo "  ./pal.sh update     서버/모드 업데이트"
    echo "  ./pal.sh adminip IP PalDefender admin IP 추가"
    echo "  ./pal.sh check      포트/모드 확인"
    echo "  ./pal.sh shell      컨테이너 쉘"
    exit 1
    ;;
esac
EOF

chmod +x pal.sh

echo "===== Docker 이미지 빌드 ====="
$DOCKER compose build

echo "===== 서버 시작 ====="
$DOCKER compose up -d

echo
echo "설치 완료."
echo "첫 실행은 SteamCMD/Wine/서버 설치 때문에 10~30분 걸릴 수 있음."
echo
echo "로그 확인:"
echo "  cd $BASE && ./pal.sh logs"
echo
echo "상태 확인:"
echo "  cd $BASE && ./pal.sh check"
echo
echo "PalDefender admin whitelist 설정 예:"
echo "  cd $BASE && ./pal.sh adminip IP"
INSTALLER

chmod +x install-palworld-wine-docker.sh
