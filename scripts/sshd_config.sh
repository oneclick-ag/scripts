#!/usr/bin/env bash
################################################################################
# Use Bash Strict Mode
#set -o errexit
#set -o nounset
#set -o pipefail
#set -o errtrace
set -o xtrace
IFS=$'\n\t'
################################################################################
SSHD_CFG="/etc/ssh/sshd_config"
PATH_TO_OS_R="/etc/os-release"
STARTUP_MARKER="/etc/startup_was_launched"
SSHD_CLD_INIT="/etc/ssh/sshd_config.d/50-cloud-init.conf"
if [ "${EUID}" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi
if [[ -f "${STARTUP_MARKER}" ]]; then
    exit 0
else
    if [[ -e "${PATH_TO_OS_R}" ]]; then
        # shellcheck source=/dev/null
        source "${PATH_TO_OS_R}"
        if [[ "${ID}" == "coreos" ]]; then
            sed -i '' "${SSHD_CFG}"
        fi
    fi
    for string in PasswordAuthentication PermitRootLogin ChallengeResponseAuthentication; do
        if grep -w "${string}" "${SSHD_CFG}"; then
            sed -i "s/.*${string}.*/${string} yes/g" "${SSHD_CFG}"
        else
            echo "${string} yes" >>"${SSHD_CFG}"
        fi
    done
    for string in 'HostKeyAlgorithms +ssh-rsa' 'PubkeyAcceptedKeyTypes +ssh-rsa'; do
        if ! grep -w "${string}" "${SSHD_CFG}"; then
            echo "${string}" >>"${SSHD_CFG}"
        fi
    done
    if [[ -e "${SSHD_CLD_INIT}" ]]; then
        rm "${SSHD_CLD_INIT}"
    fi
    for s in ssh sshd; do
        service "${s}" restart
        sleep 2
        systemctl restart "${s}"
        sleep 2
    done
    touch "${STARTUP_MARKER}"
fi
