#!/bin/bash
# =============================================================================
# setup_iptables_ama.sh  (merged + fixed)
#
# What this does:
#   1. Installs iptables + iptables-persistent
#   2. Adds LOG rules (NEW + INVALID packets) to INPUT chain
#   3. Creates /var/log/iptables.log with correct permissions
#   4. Configures rsyslog to:
#        a) Write iptables messages to /var/log/iptables.log  (custom file)
#        b) Also forward kern.warning to AMA via TCP (Syslog table in LA)
#   5. Patches AMA FluentBit to tail /var/log/iptables.log (custom log table)
#   6. Ensures syslog user can read all relevant log files
#   7. Restarts all services and smoke-tests the pipeline
#
# Two parallel paths to Log Analytics:
#   PATH A — Syslog table:   iptables → kern.log → rsyslog → AMA TCP:28330
#   PATH B — Custom table:   iptables → iptables.log → FluentBit → Iptables_CL
#
# Run as: sudo bash setup_iptables_ama.sh
# Tested on: Debian 12 (vm-web) with AMA 1.41.0
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
step()  { echo -e "\n${CYAN}━━━ $* ${NC}"; }

[[ $EUID -ne 0 ]] && error "Run as root: sudo bash $0"

LOGFILE="/var/log/iptables.log"
RSYSLOG_IPTABLES_CONF="/etc/rsyslog.d/10-iptables.conf"
RSYSLOG_KERN_CONF="/etc/rsyslog.d/20-kern-ama.conf"
FLUENTBIT_CONF="/etc/opt/microsoft/azuremonitoragent/config-cache/fluentbit/td-agent.conf"
LOG_PREFIX="IPTABLES-SCAN: "
TAG="c_iptables_scan"

# =============================================================================
# STEP 1 — Install iptables + iptables-persistent
# =============================================================================
step "Step 1/7 — Installing iptables and iptables-persistent"

apt-get update -qq
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean false | debconf-set-selections
apt-get install -y -qq iptables iptables-persistent

info "iptables version: $(iptables --version)"

# =============================================================================
# STEP 2 — Add LOG rules to iptables INPUT chain
# =============================================================================
step "Step 2/7 — Adding iptables LOG rules"

# Remove existing IPTABLES-SCAN rules to avoid duplicates on re-run
iptables -S INPUT | grep -E "IPTABLES-SCAN|IPTABLES-INVALID|IPTABLES-IN:" | while read -r rule; do
    iptables -D INPUT ${rule#-A INPUT } 2>/dev/null || true
done

# NEW packets — catches port scans, first connection attempts, brute force
iptables -I INPUT 1 -m state --state NEW -j LOG \
    --log-prefix "${LOG_PREFIX}" \
    --log-level 4

# INVALID packets — malformed / out-of-state, common in aggressive scans
iptables -I INPUT 2 -m state --state INVALID -j LOG \
    --log-prefix "IPTABLES-INVALID: " \
    --log-level 4

info "Current INPUT chain:"
iptables -L INPUT -n --line-numbers | head -10

netfilter-persistent save
info "iptables rules persisted."

# =============================================================================
# STEP 3 — Create log file with correct permissions
# =============================================================================
step "Step 3/7 — Creating ${LOGFILE} with correct permissions"

touch "${LOGFILE}"
chown root:adm "${LOGFILE}"
chmod 640 "${LOGFILE}"
info "${LOGFILE} created (root:adm, 640)"

# Ensure syslog user (AMA/FluentBit) can read both log files
if id -u syslog &>/dev/null; then
    usermod -aG adm syslog
    info "syslog user added to adm group (can now read iptables.log + apache logs)"
else
    warn "syslog user not found — skipping group assignment"
fi

# =============================================================================
# STEP 4 — Configure rsyslog
#
# Two rules:
#   a) Write iptables messages to /var/log/iptables.log (FluentBit picks up)
#   b) Forward kern.warning to AMA via TCP (lands in Syslog table)
#
# KEY FIX: AMA's mdsd listens on TCP 127.0.0.1:28330 only.
#          Using @host (UDP shorthand) causes ICMP "port unreachable" storms.
#          Must use omfwd with Protocol="tcp".
# =============================================================================
step "Step 4/7 — Writing rsyslog configs"

# --- 4a: Route iptables messages to dedicated log file ---
info "Writing ${RSYSLOG_IPTABLES_CONF}..."
cat > "${RSYSLOG_IPTABLES_CONF}" << 'EOF'
# Route iptables kernel log messages to a dedicated file.
# "& stop" prevents double-logging in /var/log/kern.log and /var/log/syslog.
:msg, contains, "IPTABLES-SCAN"    /var/log/iptables.log
& stop
:msg, contains, "IPTABLES-INVALID" /var/log/iptables.log
& stop
EOF

# --- 4b: Forward kern facility to AMA via TCP (Syslog table path) ---
# Remove any stale UDP kern rules that may have been added previously
for conf in /etc/rsyslog.d/10-azuremonitoragent.conf /etc/rsyslog.d/10-azuremonitoragent-omfwd.conf; do
    if [[ -f "$conf" ]]; then
        sed -i '/kern\.warning @127\.0\.0\.1:28330/d' "$conf"
    fi
done

info "Writing ${RSYSLOG_KERN_CONF}..."
cat > "${RSYSLOG_KERN_CONF}" << 'EOF'
# Forward kernel messages (iptables firewall logs) to Azure Monitor Agent.
#
# WHY THIS FILE EXISTS:
#   AMA's wildcard *.* rule (in 10-azuremonitoragent-omfwd.conf) does not
#   reliably capture kern facility on Debian because imklog messages are
#   processed before the wildcard action sees them.
#   This explicit rule ensures kern.warning reaches AMA.
#
# WHY TCP:
#   AMA's mdsd process listens on TCP 127.0.0.1:28330.
#   Using @ (UDP) causes ICMP port-unreachable errors which iptables logs,
#   creating a feedback loop that floods kern.log.
#
# The AMA_RSYSLOG_TraditionalForwardFormat template is defined by AMA in
#   /etc/rsyslog.d/10-azuremonitoragent-omfwd.conf
kern.warning action(type="omfwd"
    target="127.0.0.1"
    Port="28330"
    Protocol="tcp"
    Template="AMA_RSYSLOG_TraditionalForwardFormat"
    queue.type="LinkedList"
    queue.filename="omfwd-kern-ama"
    queue.maxFileSize="32m"
    action.resumeRetryCount="-1"
    action.resumeInterval="5")
EOF

# Validate rsyslog config
rsyslogd -N1 2>&1 | grep -iv "^rsyslogd" || true
systemctl restart rsyslog
info "rsyslog restarted."

# =============================================================================
# STEP 5 — Patch AMA FluentBit to tail /var/log/iptables.log
#           This feeds the custom Iptables_CL table in Log Analytics
# =============================================================================
step "Step 5/7 — Patching AMA FluentBit config"

if [[ ! -f "${FLUENTBIT_CONF}" ]]; then
    error "FluentBit config not found at ${FLUENTBIT_CONF}. Is AMA installed?"
fi

cp "${FLUENTBIT_CONF}" "${FLUENTBIT_CONF}.bak.$(date +%Y%m%d%H%M%S)"
info "FluentBit config backed up."

if grep -q "iptables.log" "${FLUENTBIT_CONF}"; then
    warn "iptables.log already in FluentBit config — skipping patch."
else
    IPTABLES_BLOCK="
[INPUT]
    Name                 tail
    Path                 ${LOGFILE}
    db                   /etc/opt/microsoft/azuremonitoragent/config-cache/fluentbit/db/${TAG}.db
    tag                  ${TAG}
    Path_Key             FilePath
    key                  RawData
    Mem_Buf_Limit        64MB
    Buffer_Chunk_Size    512KB
    Buffer_Max_Size      64MB
    Skip_Long_Lines      On
    Skip_Empty_Lines     On
    Refresh_Interval     1
    Inotify_Watcher      false

[FILTER]
    Name                 modify
    Match                ${TAG}
    Rename               log RawData
"
    awk -v block="${IPTABLES_BLOCK}" '
        /^\[OUTPUT\]/ && !done { print block; done=1 }
        { print }
    ' "${FLUENTBIT_CONF}" > "${FLUENTBIT_CONF}.tmp"

    mv "${FLUENTBIT_CONF}.tmp" "${FLUENTBIT_CONF}"
    chown syslog:syslog "${FLUENTBIT_CONF}"
    info "FluentBit config patched with iptables.log input."
fi

# =============================================================================
# STEP 6 — Restart AMA services
# =============================================================================
step "Step 6/7 — Restarting AMA services"

systemctl restart azuremonitoragent azuremonitor-agentlauncher
sleep 8

for svc in azuremonitoragent azuremonitor-agentlauncher; do
    if systemctl is-active --quiet "${svc}"; then
        info "${svc}: running ✓"
    else
        warn "${svc}: NOT running — check: journalctl -u ${svc} -n 30"
    fi
done

# =============================================================================
# STEP 7 — Smoke test
# =============================================================================
step "Step 7/7 — Smoke test"

info "Generating a test packet to trigger LOG rule..."
(timeout 1 bash -c 'echo > /dev/tcp/127.0.0.1/19999' 2>/dev/null) || true
sleep 3

info "kern.log (last IPTABLES entry):"
grep "IPTABLES" /var/log/kern.log | grep -v "IN=lo" | tail -2 \
    || warn "No external entries yet in kern.log"

info "${LOGFILE} (last entry):"
if [[ -s "${LOGFILE}" ]]; then
    tail -2 "${LOGFILE}"
else
    warn "${LOGFILE} is empty — traffic needed to populate it (see below)"
fi

info "AMA listening on TCP 28330:"
ss -tlnp | grep 28330 && echo "" || warn "mdsd not listening on 28330!"

# =============================================================================
# Summary
# =============================================================================
echo ""
echo -e "${GREEN}══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Setup complete — two paths to Log Analytics active  ${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════${NC}"
echo ""
echo "  PATH A (Syslog table)  → kern → rsyslog TCP → AMA → Log Analytics"
echo "  PATH B (Custom table)  → iptables.log → FluentBit → Iptables_CL"
echo ""
echo "  Watch live:  sudo tail -f ${LOGFILE}"
echo "               sudo tail -f /var/opt/microsoft/azuremonitoragent/log/fluentbit.log"
echo ""
echo "  Trigger test traffic from an external host:"
echo "    nmap -p 1-1000 <this-vm-public-ip>"
echo ""
echo "  ── PATH A: KQL (Syslog table, available immediately) ────────────"
cat << 'KQL'
  Syslog
  | where TimeGenerated > ago(15m)
  | where Facility == "kern"
  | where SyslogMessage contains "IPTABLES"
  | where SyslogMessage !contains "IN=lo"
  | extend SrcIP   = extract(@"SRC=([\d\.]+)", 1, SyslogMessage)
  | extend DstPort = extract(@"DPT=(\d+)",     1, SyslogMessage)
  | extend Proto   = extract(@"PROTO=(\w+)",   1, SyslogMessage)
  | summarize PortsScanned = dcount(DstPort), Attempts = count(), Ports = make_set(DstPort)
      by SrcIP, Proto, bin(TimeGenerated, 5m)
  | where PortsScanned > 3
  | order by Attempts desc
KQL
echo ""
echo "  ── PATH B: KQL (Iptables_CL — needs DCR custom log configured) ──"
echo "  NOTE: In Azure Portal → DCR → Data Sources → Add custom log:"
echo "        Stream name : Custom-Iptables_CL  |  Table : Iptables_CL"
cat << 'KQL'
  Iptables_CL
  | where RawData contains "IPTABLES-SCAN"
  | extend SrcIP   = extract(@"SRC=([\d\.]+)", 1, RawData)
  | extend DstPort = extract(@"DPT=(\d+)",     1, RawData)
  | summarize Ports = dcount(DstPort), Hits = count() by SrcIP, bin(TimeGenerated, 5m)
  | where Ports > 5
  | order by Hits desc
KQL
echo ""
