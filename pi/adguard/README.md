# AdGuard Home

Installation d'AdGuard Home sur le Raspberry Pi, après `bootstrap.sh`.

## Installation

Le script officiel est à télécharger, relire, puis exécuter. Ne pas l'exécuter directement depuis Internet sans l'avoir lu.

```bash
curl -fsSL -o /tmp/agh-install.sh https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh
less /tmp/agh-install.sh          # relecture
sudo sh /tmp/agh-install.sh -v    # installation
```

Le script installe AdGuard Home dans `/opt/AdGuardHome` et le déclare comme service systemd.

## Premier démarrage

1. Ouvrir `http://<ip-du-pi>:3000` depuis le LAN.
2. Créer le compte administrateur avec un mot de passe fort, stocké dans un gestionnaire de mots de passe.
3. Choisir l'interface d'écoute DNS (port 53) et l'interface web (port 80 ou 3000).
4. Choisir les serveurs DNS en amont, en DNS-over-HTTPS ou DNS-over-TLS.
5. Activer les listes de blocage recommandées.

Une fois la configuration terminée, fermer le port 3000 dans le pare-feu et passer l'interface web sur le port 80 ou 443 limité au VLAN de management :

```bash
sudo ufw delete allow from <LAN_CIDR> to any port 3000 proto tcp
```

## Sauvegarde de la configuration

Le script `export-config.sh` copie la configuration dans le dépôt, sans la section des utilisateurs (mots de passe hachés).

```bash
./export-config.sh
```

Relire le fichier produit avant tout commit : il ne doit contenir aucun secret.

## Restauration

Arrêter AdGuard, remplacer `/opt/AdGuardHome/AdGuardHome.yaml` par la sauvegarde, puis recréer manuellement le compte administrateur.

```bash
sudo systemctl stop AdGuardHome
sudo cp AdGuardHome.yaml.sanitized /opt/AdGuardHome/AdGuardHome.yaml
sudo systemctl start AdGuardHome
```
