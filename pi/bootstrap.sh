#!/usr/bin/env bash
# Préparation d'un Raspberry Pi neuf pour RasNetLab (Raspberry Pi OS Lite 64 bits).
#
# Ce script :
#   - règle le fuseau horaire et le nom d'hôte ;
#   - met le système à jour et active les correctifs de sécurité automatiques ;
#   - crée un compte administrateur avec clé SSH, et désactive la connexion par mot de passe ;
#   - configure le pare-feu pour n'accepter le SSH, le DNS et l'administration que depuis le LAN.
#
# Usage (à lancer sur le Pi, en étant connecté en SSH avec un compte qui a sudo) :
#   sudo ADMIN_USER=admin \
#        SSH_PUBKEY_FILE=/home/admin/.ssh/id_ed25519.pub \
#        LAN_CIDR=10.10.10.0/24 \
#        ./bootstrap.sh
#
# Variables optionnelles :
#   HOSTNAME_NEW  (défaut : rasnetlab-dns)
#
# Attention : le script désactive la connexion par mot de passe.
# Vérifie que ta clé SSH fonctionne dans une AUTRE session avant de fermer celle-ci.

set -euo pipefail

: "${ADMIN_USER:?Définir ADMIN_USER (ex. ADMIN_USER=admin)}"
: "${SSH_PUBKEY_FILE:?Définir SSH_PUBKEY_FILE (chemin vers la clé publique)}"
: "${LAN_CIDR:?Définir LAN_CIDR (ex. LAN_CIDR=10.10.10.0/24)}"
NEW_HOSTNAME="${HOSTNAME_NEW:-rasnetlab-dns}"

if [[ $EUID -ne 0 ]]; then
  echo "Ce script doit être lancé avec sudo." >&2
  exit 1
fi

if [[ ! -r "$SSH_PUBKEY_FILE" ]]; then
  echo "Clé publique introuvable : $SSH_PUBKEY_FILE" >&2
  exit 1
fi

echo "==> Fuseau horaire et nom d'hôte"
timedatectl set-timezone Africa/Dakar
hostnamectl set-hostname "$NEW_HOSTNAME"

echo "==> Mises à jour et paquets de base"
apt-get update
apt-get -y full-upgrade
apt-get -y install sudo ufw unattended-upgrades

echo "==> Correctifs de sécurité automatiques"
dpkg-reconfigure -f noninteractive unattended-upgrades

echo "==> Compte administrateur : $ADMIN_USER"
if ! id "$ADMIN_USER" &>/dev/null; then
  adduser --disabled-password --gecos "" "$ADMIN_USER"
fi
usermod -aG sudo "$ADMIN_USER"

SSH_DIR="/home/$ADMIN_USER/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"
install -d -m 700 -o "$ADMIN_USER" -g "$ADMIN_USER" "$SSH_DIR"
touch "$AUTH_KEYS"
chown "$ADMIN_USER:$ADMIN_USER" "$AUTH_KEYS"
chmod 600 "$AUTH_KEYS"
# Ajoute la clé sans écraser les clés déjà présentes.
PUBKEY="$(cat "$SSH_PUBKEY_FILE")"
grep -qxF "$PUBKEY" "$AUTH_KEYS" || echo "$PUBKEY" >> "$AUTH_KEYS"

echo "==> Durcissement SSH"
cat > /etc/ssh/sshd_config.d/10-rasnetlab.conf <<'EOF'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
EOF
sshd -t
systemctl reload ssh

echo "==> Pare-feu (LAN uniquement)"
ufw default deny incoming
ufw default allow outgoing
ufw allow from "$LAN_CIDR" to any port 22 proto tcp comment 'SSH depuis le LAN'
ufw allow from "$LAN_CIDR" to any port 53 comment 'DNS depuis le LAN'
ufw allow from "$LAN_CIDR" to any port 3000 proto tcp comment 'Interface AdGuard (installation)'
ufw --force enable
ufw status verbose

echo "==> Terminé. Vérifie la connexion SSH par clé depuis un autre poste avant de fermer la session."
