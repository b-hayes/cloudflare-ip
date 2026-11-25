#!/usr/bin/env bash
set -euo pipefail

RED=$'\e[31m'; YELLOW=$'\e[33m'; GREEN=$'\e[32m'; BLUE=$'\e[34m'; CYAN=$'\e[36m'; RESET=$'\e[0m'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTAINER=cloudflare-ip-updater
TEST_DIR="$ROOT/dist/restoretest"
MODE=test
ASSUME_YES=false

usage() {
    cat <<EOF
${BLUE}Cloudflare IP updater restore${RESET}

Restores a backup made by bin/backup.sh. Two modes:

  ${GREEN}test${RESET} (default) - SAFE. Copies the backup into a throwaway dir and, from a
       throwaway container of the same image, checks every site file has its settings
       and its credentials can read its DNS record (read-only - nothing is updated).
       The live instance is NEVER touched.

  ${YELLOW}--into-live${RESET} - DISASTER RECOVERY ONLY. Stops the container, moves the
       current env files aside (not deleted), copies the backup in, runs the same
       check and starts the container.
       If anything fails it ROLLS BACK to the moved-aside state automatically.

The env files are owned by the host user, so no root is needed.

Usage: bin/restore.sh [options] <backup-dir>

  <backup-dir>   A cloudflare-ip-<datetime> folder from backup.sh (must contain secrets/ env files).

Options:
  --into-live    Restore over the live instance instead of the isolated test.
  --yes          Skip the confirmation prompt (for automation)
  -h, --help     Show this help
EOF
}

fail() { echo "${RED}ERROR: $*${RESET}" >&2; exit 1; }

BACKUP_DIR=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --into-live) MODE=live; shift ;;
        --yes) ASSUME_YES=true; shift ;;
        -h|--help) usage; exit 0 ;;
        -*) echo "${RED}Unknown option: $1${RESET}"; usage; exit 1 ;;
        *) BACKUP_DIR=${1%/}; shift ;;
    esac
done

# --- Pre-flight validation (do all checks BEFORE touching anything) ---
[[ -n "$BACKUP_DIR" ]] || { echo "${RED}No backup dir given.${RESET}"; usage; exit 1; }
command -v docker >/dev/null || fail "docker not found on PATH."
docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER" || fail "Container '$CONTAINER' not found - deploy it (docker compose up -d) before restoring."

[[ -d "$BACKUP_DIR" ]] || fail "Backup dir '$BACKUP_DIR' does not exist."
# Structural integrity: these must exist in a real backup, or the restore is junk.
mapfile -t SECRET_FILES < <(cd "$BACKUP_DIR/secrets" 2>/dev/null && ls -1A -- .env *.env 2>/dev/null)
[[ ${#SECRET_FILES[@]} -gt 0 ]] || fail "'$BACKUP_DIR/secrets' has no env files - not a valid backup."
# Each <site>.env is one DNS record; a lone .env is the only record.
mapfile -t SITES < <(printf '%s\n' "${SECRET_FILES[@]}" | grep -vx '\.env')
[[ ${#SITES[@]} -gt 0 ]] || SITES=(.env)
echo "${GREEN}Backup validated:${RESET} $BACKUP_DIR (${SITES[*]})"

# Loads each site's settings inside a throwaway container, so no value reaches this shell, and
# reports only whether they are complete and can read the site's DNS record. Read-only.
verify_sites() {
    local dir=$1 site result problems=0
    for site in "${SITES[@]}"; do
        result="$(docker run --rm -v "$dir:/cfg:ro" "$IMAGE" bash -c '
            cd /cfg
            [ -f ./.env ] && source ./.env
            [ "$1" != .env ] && source "./$1"
            for v in CLOUDFLARE_EMAIL CLOUDFLARE_API_KEY CLOUDFLARE_ZONE_ID CLOUDFLARE_RECORD_NAME; do
                [ -n "${!v:-}" ] || { echo "missing $v"; exit 0; }
            done
            curl -s "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records?name=$CLOUDFLARE_RECORD_NAME&type=${CLOUDFLARE_RECORD_TYPE:-A}" \
                -H "X-Auth-Email: $CLOUDFLARE_EMAIL" -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
                | jq -r "if .success and (.result | length > 0) then \"ok\" elif .success then \"no record yet\" else \"auth failed\" end"
        ' _ "$site")" || fail "Could not check $site."
        case $result in
            ok) echo "${GREEN}Verified:${RESET} $site reads its DNS record" ;;
            missing*) echo "${RED}  $site: $result${RESET}" >&2; problems=$((problems + 1)) ;;
            *) echo "${YELLOW}  $site: $result - Cloudflare rejected these credentials; the backup holds what live had.${RESET}" ;;
        esac
    done
    [[ $problems -eq 0 ]] || fail "$problems site file(s) are missing settings."
}

IMAGE="$(docker inspect --format '{{.Image}}' "$CONTAINER")" || fail "Cannot read image from live container '$CONTAINER'."

if [[ "$MODE" == test ]]; then
    echo "${BLUE}Isolated restore test${RESET} (image: $(docker inspect --format '{{.Config.Image}}' "$CONTAINER"))"
    echo "${CYAN}The live instance will NOT be touched.${RESET}"

    teardown() {
        rm -rf "$TEST_DIR"
    }
    trap teardown EXIT
    teardown  # clear any leftovers from a previous run

    echo "${CYAN}Copying the backup into $TEST_DIR...${RESET}"
    mkdir -p "$TEST_DIR"
    cp -a "$BACKUP_DIR/secrets/." "$TEST_DIR/"

    verify_sites "$TEST_DIR"

    echo "${GREEN}Restore test PASSED.${RESET} The backup restores every site's settings."
    echo "${CYAN}Tearing down throwaway dir...${RESET}"
    exit 0
fi

# --- MODE=live : disaster recovery over the running instance ---
PARTS=()
for f in "${SECRET_FILES[@]}"; do
    PARTS+=("$ROOT/$f")
done

echo "${YELLOW}This will REPLACE these env files in $ROOT: ${SECRET_FILES[*]}${RESET}"
if [[ "$ASSUME_YES" != true ]]; then
    read -r -p "Type 'restore' to proceed: " ANS
    [[ "$ANS" == "restore" ]] || { echo "${CYAN}Aborted - nothing changed.${RESET}"; exit 0; }
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
RESTORE_OK=false
MOVED=false

rollback() {
    echo "${YELLOW}Rolling back to pre-restore state...${RESET}" >&2
    docker stop "$CONTAINER" >/dev/null 2>&1 || true
    for p in "${PARTS[@]}"; do
        [[ -e "$p.pre-restore-$STAMP" ]] || continue
        rm -rf "$p"
        mv "$p.pre-restore-$STAMP" "$p"
    done
    docker start "$CONTAINER" >/dev/null 2>&1 || true
    echo "${YELLOW}Rolled back. Original data is live again.${RESET}" >&2
}

cleanup() {
    if [[ "$RESTORE_OK" != true && "$MOVED" == true ]]; then
        rollback
        echo "${RED}Restore FAILED and was rolled back. Nothing lost.${RESET}" >&2
    fi
}
trap cleanup EXIT

if docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
    echo "${CYAN}Stopping container...${RESET}"
    docker stop "$CONTAINER" >/dev/null
fi

echo "${CYAN}Moving current env files aside (kept for rollback)...${RESET}"
MOVED=true
for p in "${PARTS[@]}"; do
    [[ -e "$p" ]] && mv "$p" "$p.pre-restore-$STAMP"
done

echo "${CYAN}Copying backup into place...${RESET}"
cp -a "$BACKUP_DIR/secrets/." "$ROOT/"

verify_sites "$ROOT"

echo "${CYAN}Starting container...${RESET}"
docker start "$CONTAINER" >/dev/null
[[ "$(docker inspect --format '{{.State.Status}}' "$CONTAINER")" == "running" ]] || fail "Container '$CONTAINER' did not start - see 'docker logs $CONTAINER'."

RESTORE_OK=true
echo "${GREEN}Restore complete and the updater is running.${RESET}"
echo "${CYAN}Pre-restore copies kept at:${RESET}"
for p in "${PARTS[@]}"; do
    [[ -e "$p.pre-restore-$STAMP" ]] && echo "  $p.pre-restore-$STAMP"
done
echo "${YELLOW}VERIFY before trusting this restore:${RESET}"
echo "${CYAN}  - Force an update and confirm every site reports success:  docker exec $CONTAINER /app/update-all-if-ip-changed.sh --force${RESET}"
if [[ ! -f /etc/cron.d/cloudflare-ip-backup ]]; then
    echo "${YELLOW}  - Backup cron is NOT installed - the schedule is stopped. Reinstall: sed s/__USER__/\$USER/ $ROOT/deploy/cloudflare-ip-backup | sudo tee /etc/cron.d/cloudflare-ip-backup${RESET}"
fi
echo "${CYAN}Only once verified, delete the pre-restore copies above.${RESET}"
