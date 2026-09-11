#!/usr/bin/env bash
# =============================================================================
# update-helm-charts.sh
# Downloads / updates all observability Helm charts into addons/helm-charts/
#
# Usage:
#   ./update-helm-charts.sh              # download all charts at pinned versions
#   ./update-helm-charts.sh --upgrade    # pull latest available versions
#   CHART=prometheus ./update-helm-charts.sh  # update a single chart
#
# Requirements: helm >= 3.8
# =============================================================================
set -euo pipefail

# ── Colour helpers ────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── Config ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHARTS_DIR="${SCRIPT_DIR}/addons/helm-charts"

UPGRADE_MODE=false
if [[ "${1:-}" == "--upgrade" ]]; then
  UPGRADE_MODE=true
  warn "--upgrade mode: pinned versions will be ignored, latest charts pulled"
fi

# ── Chart registry ────────────────────────────────────────────────────────────
# Format: "CHART_NAME|REPO_NAME|REPO_URL|VERSION"
# To pin a new version, update the VERSION field and re-run the script.
declare -a CHARTS=(
  "prometheus|prometheus-community|https://prometheus-community.github.io/helm-charts|25.21.0"
  "grafana|grafana|https://grafana.github.io/helm-charts|8.0.0"
  "loki|grafana|https://grafana.github.io/helm-charts|6.6.5"
  "promtail|grafana|https://grafana.github.io/helm-charts|6.16.6"
  "tempo|grafana|https://grafana.github.io/helm-charts|1.10.3"
  "opentelemetry-collector|open-telemetry|https://open-telemetry.github.io/opentelemetry-helm-charts|0.173.0"
  "prometheus-redis-exporter|prometheus-community|https://prometheus-community.github.io/helm-charts|6.3.0"
)

# ── Helpers ───────────────────────────────────────────────────────────────────
add_repo() {
  local name="$1" url="$2"
  if helm repo list 2>/dev/null | awk '{print $1}' | grep -q "^${name}$"; then
    info "Repo '${name}' already added — updating"
    helm repo update "${name}" --fail-on-repo-update-fail 2>/dev/null || warn "Could not update repo ${name}"
  else
    info "Adding Helm repo '${name}' → ${url}"
    helm repo add "${name}" "${url}"
  fi
}

pull_chart() {
  local chart="$1" repo="$2" version="$3" dest="$4"
  local full_name="${repo}/${chart}"

  info "Pulling chart ${full_name} version=${version} → ${dest}/"

  # Remove old copy of this chart before downloading
  rm -rf "${dest}/${chart}"

  if [[ "${UPGRADE_MODE}" == true ]]; then
    helm pull "${full_name}" --untar --untardir "${dest}"
  else
    helm pull "${full_name}" --version "${version}" --untar --untardir "${dest}"
  fi

  # Print actual downloaded version from Chart.yaml
  local actual_version
  actual_version=$(grep '^version:' "${dest}/${chart}/Chart.yaml" 2>/dev/null | awk '{print $2}' || echo "unknown")
  info "  ✓ ${chart} downloaded — version: ${actual_version}"
}

# ── Preflight ─────────────────────────────────────────────────────────────────
command -v helm >/dev/null 2>&1 || error "'helm' not found. Install Helm >= 3.8 first."

helm_version=$(helm version --short 2>/dev/null | sed 's/v//' | cut -d'.' -f1-2)
info "Helm version: ${helm_version}"

mkdir -p "${CHARTS_DIR}"
info "Charts directory: ${CHARTS_DIR}"

# ── Collect unique repos and add them ─────────────────────────────────────────
ADDED_REPOS=""  # Space-separated list of already-added repo names (Bash 3.2 compatible)
for entry in "${CHARTS[@]}"; do
  IFS='|' read -r chart repo url version <<< "${entry}"
  # Check if repo name already exists in the tracked list
  if echo " ${ADDED_REPOS} " | grep -q " ${repo} "; then
    : # already added
  else
    add_repo "${repo}" "${url}"
    ADDED_REPOS="${ADDED_REPOS} ${repo}"
  fi
done

info "Updating all repos..."
helm repo update

# ── Download charts ───────────────────────────────────────────────────────────
for entry in "${CHARTS[@]}"; do
  IFS='|' read -r chart repo url version <<< "${entry}"

  # If CHART env var is set, only download that chart
  if [[ -n "${CHART:-}" && "${CHART}" != "${chart}" ]]; then
    continue
  fi

  pull_chart "${chart}" "${repo}" "${version}" "${CHARTS_DIR}"
done

# ── Summary ───────────────────────────────────────────────────────────────────
echo
info "All charts downloaded to: ${CHARTS_DIR}/"
echo
info "Installed charts:"
for d in "${CHARTS_DIR}"/*/; do
  chart_name=$(basename "${d}")
  chart_ver=$(grep '^version:' "${d}Chart.yaml" 2>/dev/null | awk '{print $2}' || echo '?')
  echo -e "  ${GREEN}✓${NC} ${chart_name} (${chart_ver})"
done
echo
info "To render a chart with its values, run:"
echo "  kubectl kustomize --enable-helm addons/envs/prd/observability/"
