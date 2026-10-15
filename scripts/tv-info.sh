#!/usr/bin/env bash
# Mostra o resumo de GET http://<ip>:8001/api/v2/ (modelo, PowerState, MAC, suporte a token).
# Uso: scripts/tv-info.sh 192.168.0.50 [--raw]
set -euo pipefail
ip="${1:?uso: $0 <ip-da-tv> [--raw]}"
if ! out="$(curl -fsS --max-time 3 "http://${ip}:8001/api/v2/")"; then
  echo "A TV em ${ip} não respondeu na porta 8001 (desligada, standby profundo ou IP errado)." >&2
  exit 1
fi
if [[ "${2:-}" == "--raw" ]] || ! command -v python3 >/dev/null; then
  printf '%s\n' "$out"
  exit 0
fi
python3 - "$out" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
dev = d.get("device", {})
for k in ("name", "modelName", "PowerState", "networkType", "wifiMac", "TokenAuthSupport", "OS"):
    print(f"{k:>17}: {dev.get(k, '-')}")
print(f"{'api version':>17}: {d.get('version', '-')}")
PY
