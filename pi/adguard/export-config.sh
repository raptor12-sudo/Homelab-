#!/usr/bin/env bash
# Exporte la configuration d'AdGuard Home dans le dépôt, sans la section `users:`.
# À lancer sur le Pi, depuis le dossier pi/adguard/ du dépôt.
#
# Les mots de passe sont dans la section `users:` : elle est retirée.
# Relire le fichier produit avant de le versionner.

set -euo pipefail

SRC="${ADGUARD_CONF:-$HOME/adguard/conf/AdGuardHome.yaml}"
DST="$(dirname "$0")/AdGuardHome.yaml.sanitized"

if [[ ! -r "$SRC" ]] && ! sudo test -r "$SRC"; then
  echo "Configuration introuvable : $SRC" >&2
  exit 1
fi

# Supprime le bloc `users:` (lignes indentées qui suivent la clé de premier niveau).
sudo cat "$SRC" | awk '
  /^users:/ { skip = 1; next }
  /^[^ \t#]/ { skip = 0 }
  !skip
' > "$DST"

echo "Configuration exportée : $DST"
echo "Relis-la avant de la committer : grep -iE 'password|token|key' \"$DST\""
