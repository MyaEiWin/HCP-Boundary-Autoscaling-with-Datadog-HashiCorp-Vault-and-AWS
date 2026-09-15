#!/usr/bin/env bash
# Run this script ON THE TARGET EC2 INSTANCE as a sudo-capable administrator.
# It installs Vault's public SSH CA and makes OpenSSH trust certificates signed
# by that CA. It never receives a Vault token or private CA key.
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run with sudo: sudo ./install-target-ssh-ca.sh /path/to/vault-ssh-ca.pub" >&2
  exit 1
fi

ca_file="${1:-}"
if [[ -z "$ca_file" || ! -f "$ca_file" ]]; then
  echo "Usage: sudo $0 /path/to/vault-ssh-ca.pub" >&2
  exit 1
fi

if ! grep -qE '^(ssh-|ecdsa-|sk-)' "$ca_file"; then
  echo "The supplied file does not appear to contain an SSH CA public key." >&2
  exit 1
fi

install -D -m 0644 "$ca_file" /etc/ssh/trusted-user-ca-keys.pem

config_file=/etc/ssh/sshd_config.d/99-vault-ssh-ca.conf
if [[ -d /etc/ssh/sshd_config.d ]]; then
  printf '%s\n' 'TrustedUserCAKeys /etc/ssh/trusted-user-ca-keys.pem' >"$config_file"
else
  config_file=/etc/ssh/sshd_config
  if ! grep -qxF 'TrustedUserCAKeys /etc/ssh/trusted-user-ca-keys.pem' "$config_file"; then
    printf '\n%s\n' 'TrustedUserCAKeys /etc/ssh/trusted-user-ca-keys.pem' >>"$config_file"
  fi
fi

sshd -t
systemctl restart ssh
echo "Installed Vault SSH CA trust configuration: $config_file"
