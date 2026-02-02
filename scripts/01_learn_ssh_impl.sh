#!/bin/bash

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Set up variables for directories
SCRIPTS_DIR=$(dirname "$(readlink -f "$0")")
ARTIFACTS_DIR=$(readlink -f "$SCRIPTS_DIR/..")
cd $ARTIFACTS_DIR
LOG_FILE="$ARTIFACTS_DIR/logs/learn_ssh_impl_$(date +'%Y%m%d_%H%M%S').log"
rm -rf $LOG_FILE && mkdir -p "$ARTIFACTS_DIR/logs" && touch $LOG_FILE

function log() {
    echo -e "$1" | tee -a $LOG_FILE
}

# Check that the script is invoked without sudo
if [[ $SUDO_USER ]]; then
   log "${RED}[!] This script should not be run with sudo.${NC}"
   exit 1
fi

function choose_sul_impl() {
    log "${CYAN}[?] Choose a target implementation as system-under-learning (SUL) for the state learner:${NC}"
    select SSH_IMPL_NAME in "AsyncSSH" "Bitvise" "Dropbear" "Erlang SSH" "Golang" "Lancom LCOS" "libssh" "OpenSSH" "Tectia SSH" "TinySSH" ; do
        case $SSH_IMPL_NAME in
            "AsyncSSH"|"Bitvise"|"Dropbear"|"Erlang SSH"|"Golang"|"Lancom LCOS"|"libssh"|"OpenSSH"|"Tectia SSH"|"TinySSH")
                log "${GREEN}[+] Chosen SUL: $SSH_IMPL_NAME${NC}"
                break
                ;;
            *)
                log "${RED}[!] Invalid choice. Please select an SSH implementation from the list.${NC}"
                ;;
        esac
    done
    SSH_IMPL=$(echo $SSH_IMPL_NAME | tr '[:upper:] ' '[:lower:]-')
}

function choose_kex_flow_type() {
    case $SSH_IMPL_NAME in
        "AsyncSSH")
            SUPPORTED_FLOWS=("DH" "DHGEX" "RSA" "ECDH" "PQ-Hybrid")
            ;;
        "Bitvise")
            SUPPORTED_FLOWS=("DH" "DHGEX" "ECDH")
            ;;
        "Dropbear")
            SUPPORTED_FLOWS=("DH" "ECDH" "PQ-Hybrid")
            ;;
        "Erlang SSH")
            SUPPORTED_FLOWS=("DH" "DHGEX" "ECDH")
            ;;
        "Golang")
            SUPPORTED_FLOWS=("DH" "ECDH")
            ;;
        "Lancom LCOS")
            SUPPORTED_FLOWS=("DH" "DHGEX" "ECDH" "PQ-Hybrid")
            ;;
        "libssh")
            SUPPORTED_FLOWS=("DH" "DHGEX" "ECDH")
            ;;
        "OpenSSH")
            SUPPORTED_FLOWS=("DH" "DHGEX" "ECDH" "PQ-Hybrid")
            ;;
        "Tectia SSH")
            SUPPORTED_FLOWS=("DH" "DHGEX" "ECDH" "PQ-Hybrid")
            ;;
        "TinySSH")
            SUPPORTED_FLOWS=("ECDH" "PQ-Hybrid")
            ;;
    esac
    log "${CYAN}[?] Choose a key exchange flow type for learning:${NC}"
    select KEX_FLOW in "${SUPPORTED_FLOWS[@]}"; do
        case $KEX_FLOW in
            "DH"|"DHGEX"|"RSA"|"ECDH"|"PQ-Hybrid")
                log "${GREEN}[+] Chosen KEX flow type: $KEX_FLOW${NC}"
                break
                ;;
            *)
                log "${RED}[!] Invalid choice. Please select a key exchange flow type from the list.${NC}"
                ;;
        esac
    done
    case $KEX_FLOW in
        "DH")
            KEX_ALG="DIFFIE_HELLMAN_GROUP14_SHA256"
            ;;
        "DHGEX")
            KEX_ALG="DIFFIE_HELLMAN_GROUP_EXCHANGE_SHA256"
            ;;
        "RSA")
            KEX_ALG="RSA2048_SHA256"
            ;;
        "ECDH")
            if [[ $SSH_IMPL_NAME == "TinySSH" ]]; then
                KEX_ALG="CURVE25519_SHA256"
            else
                KEX_ALG="ECDH_SHA2_NISTP256"
            fi
            ;;
        "PQ-Hybrid")
            KEX_ALG="SNTRUP761X25519_SHA512_OPENSSH_COM"
            ;;
    esac
    log "    - Corresponding algorithm identifier: $KEX_ALG"
}

function create_results_dir() {
    log "${GREEN}[+] Creating results directory...${NC}"
    RESULTS_DIR="$ARTIFACTS_DIR/results/$SSH_IMPL/$(echo $KEX_FLOW | tr '[:upper:]' '[:lower:]')"
    mkdir -p "$RESULTS_DIR"
}

function start_servers() {
    log "${GREEN}[+] Starting $SSH_IMPL_NAME servers...${NC}"
    case $SSH_IMPL in
        "asyncssh"|"dropbear"|"erlang-ssh"|"golang"|"libssh"|"openssh"|"tinyssh")
            IS_DOCKERIZED_SERVER=true
            cd "$ARTIFACTS_DIR/code/impl/$SSH_IMPL"
            docker compose up -d --scale server=16 |& tee -a $LOG_FILE
            SERVER_HOST="127.0.0.1"
            SERVER_PORT="30020-30035"
            cd "$ARTIFACTS_DIR"
            ;;
        "bitvise")
            log "    - Note: Bitvise is a commercial Windows-based SSH server. As such, it requires manual installation and configuration on a host system."
            log "    - Please refer to the Bitvise documentation for detailed setup instructions."
            log "    - Installer: https://dl.bitvise.com/BvSshClient-943.exe"
            read -p "    - Enter the hostname where the Bitvise server is running: " SERVER_HOST
            read -p "    - Enter the port where the Bitvise server is running: " SERVER_PORT
            ;;
        "lancom-lcos")
            log "    - Note: Lancom LCOS is a network device operating system. As such, it requires manual installation and configuration on a suitable network device or as an appliance."
            log "    - We recommend using the Lancom LCOS vRouter which can be deployed as a virtual machine (no license required). The following appliance can be deployed on VMware Workstation Pro or other virtualization platforms supporting OVA applicances."
            log "    - Appliance: https://ftp.lancom.de/LANCOM-Archive/LC-vRouter/LC-vRouter-10.90.0126-Rel.ova"
            log "    - Manual: https://www.lancom-systems.com/fileadmin/download/documentation/Installation_Guide/IG_vRouter_EN.pdf"
            read -p "    - Enter the hostname where the Lancom LCOS server is running: " SERVER_HOST
            read -p "    - Enter the port where the Lancom LCOS server is running: " SERVER_PORT
            ;;
        "tectia-ssh")
            log "    - Note: Tectia SSH is a commercial Windows-based SSH server. As such, it requires manual installation and configuration on a host system."
            log "    - Historical versions of Tectia SSH are not available for download. Therefore, results may deviate from those obtained during evaluation."
            log "    - Tectia SSH does not offer a free version but provides a trial version that can be used for analysis."
            log "    - Trial form: https://info.ssh.com/tectia-ssh-client-server-trial-download"
            read -p "    - Enter the hostname where the Tectia SSH server is running: " SERVER_HOST
            read -p "    - Enter the port where the Tectia SSH server is running: " SERVER_PORT
            ;;
    esac
}

function stop_containers() {
    docker ps -q --filter "name=ssh-state-learner" | xargs -r docker stop |& tee -a $LOG_FILE
    if [[ $IS_DOCKERIZED_SERVER != true ]]; then
        return
    fi
    log "${GREEN}[+] Stopping $SSH_IMPL servers...${NC}"
    cd "$ARTIFACTS_DIR/code/impl/$SSH_IMPL"
    docker compose down |& tee -a $LOG_FILE
    cd "$ARTIFACTS_DIR"
}

function ask_retrieve_delay() {
    log "${GREEN}[+] Configuring retrieve delay...${NC}"
    log "    - The retrieve delay determines how long the state learner waits for a response from the server after sending a symbol."
    log "    - The retrieve delay depends on various parameters like the network latency, the server load, and the specific SSH implementation being used."
    log "    - Shorter retrieve delays reduce learning times but may lead to incomplete responses. Similarly, longer retrieve delays may result in slower learning but more complete responses."
    log "    - We recommended a default retrieve delay of 100 ms for local servers, and 500 ms for network servers. If you observe frequent cache conflicts during learning, try increasing the retrieve delays in increments of 100 ms."
    read -p "    - Enter the retrieve delay (ms) for $SSH_IMPL_NAME: " RETRIEVE_DELAY
}

function run_symbol_tests() {
    read -p "Do you want to run symbol unit tests before learning? (y/N) " RUN_UNIT
    if [[ "$RUN_UNIT" =~ ^[Yy]$ ]]; then
        if command -v mvn >/dev/null 2>&1; then
            log "${CYAN}[+] Running unit tests for code/ssh_state_learner...${NC}"
            mvn -f code/ssh_state_learner test -Dtest=*SshSymbolConstructorTest |& tee -a $LOG_FILE
            if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
                log "${RED}[!] Unit tests failed. Aborting learning.${NC}"
                exit 1
            fi
        else
            # Try to run the Windows PowerShell bootstrap helper so tests can run without an installed mvn
            PS_CMD=""
            if command -v pwsh >/dev/null 2>&1; then
                PS_CMD="pwsh"
            elif command -v powershell >/dev/null 2>&1; then
                PS_CMD="powershell"
            fi
            if [[ -z "$PS_CMD" ]]; then
                log "${RED}[!] Maven not found and PowerShell not available. To run tests manually, run: ./scripts/run-integration-sshstatelearner.ps1${NC}"
            else
                log "${CYAN}[+] Maven not found. Using $PS_CMD to run the Windows bootstrap helper for unit tests...${NC}"
                $PS_CMD -NoProfile -ExecutionPolicy Bypass -File .\\run-maven-local.ps1 -Module code/ssh_state_learner -AdditionalArgs 'test -Dtest=*SshSymbolConstructorTest'
                if [[ $? -ne 0 ]]; then
                    log "${RED}[!] Unit tests (helper) failed. Aborting.${NC}"
                    exit 1
                fi
            fi
        fi
    fi

    read -p "Do you want to run integration tests (requires Docker compose up)? (y/N) " RUN_INT
    if [[ "$RUN_INT" =~ ^[Yy]$ ]]; then
        if command -v mvn >/dev/null 2>&1; then
            log "${CYAN}[+] Running integration tests for code/ssh_state_learner (Failsafe profile)...${NC}"
            mvn -f code/ssh_state_learner -Pintegration-tests verify |& tee -a $LOG_FILE
            if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
                log "${RED}[!] Integration tests failed. Aborting learning.${NC}"
                exit 1
            fi
        else
            PS_CMD=""
            if command -v pwsh >/dev/null 2>&1; then
                PS_CMD="pwsh"
            elif command -v powershell >/dev/null 2>&1; then
                PS_CMD="powershell"
            fi
            if [[ -z "$PS_CMD" ]]; then
                log "${RED}[!] Maven not found and PowerShell not available. To run integration tests manually, run: ./scripts/run-integration-sshstatelearner.ps1${NC}"
            else
                log "${CYAN}[+] Maven not found. Using $PS_CMD to run the Windows bootstrap helper for integration tests...${NC}"
                $PS_CMD -NoProfile -ExecutionPolicy Bypass -File .\\run-maven-local.ps1 -Module code/ssh_state_learner -AdditionalArgs '-Pintegration-tests verify'
                if [[ $? -ne 0 ]]; then
                    log "${RED}[!] Integration tests (helper) failed. Aborting.${NC}"
                    exit 1
                fi
            fi
        fi
    fi
}

function learn_ssh_impl() {
    log "${GREEN}[+] Learning SSH implementation state machine...${NC}"
    log "    - Current SSH implementation: $SSH_IMPL_NAME"
    log "    - Server address: $SERVER_HOST:$SERVER_PORT"
    log "    - Selected KEX algorithm: $KEX_ALG"

    # Not all options are required as they are the default value but we include them for clarity
    COMMON_OPTIONS=(
        -h "$SERVER_HOST"
        -p "$SERVER_PORT"
        --retrieve-delay $RETRIEVE_DELAY
        --sul-type SERVER
        --name "$SSH_IMPL_NAME"
        --kex "$KEX_ALG"
        --stage TRANSPORT
        --strict-kex
        --conflict-votes 13
        --equiv-oracle-chain CACHE_CONSISTENCY,HAPPY_FLOW,RANDOM_WORDS
        --equiv-happy-flow-max-insertions 2
        --equiv-random-words-max-tests 10000
        --equiv-random-words-min-length 5
        --equiv-random-words-max-length 15
        --output /results
    )
    case $SSH_IMPL in
        "asyncssh"|"dropbear"|"erlang-ssh"|"golang"|"libssh"|"openssh"|"tinyssh"|"lancom-lcos"|"tectia-ssh")
            timeout 1h docker run --rm \
                -v "$RESULTS_DIR:/results" \
                --network host \
                --name ssh-state-learner \
                ssh-state-learner:latest \
                "${COMMON_OPTIONS[@]}" |& tee -a $LOG_FILE
            ;;
        "bitvise")
            # Disable rekex to avoid combinatorial explosion of states due to message buffering during rekex
            timeout 1h docker run --rm \
                -v "$RESULTS_DIR:/results" \
                --network host \
                --name ssh-state-learner \
                ssh-state-learner:latest \
                "${COMMON_OPTIONS[@]}" \
                --disable-rekex |& tee -a $LOG_FILE
            ;;
    esac
}

choose_sul_impl
choose_kex_flow_type
trap 'stop_containers' EXIT
start_servers
ask_retrieve_delay
create_results_dir
run_symbol_tests
learn_ssh_impl
