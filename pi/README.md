# Raspberry Pi : DNS du réseau

Le Raspberry Pi héberge AdGuard Home, qui sert de DNS au réseau local et filtre les publicités et les domaines de suivi.

**Statut** : kit de déploiement prêt, à exécuter sur le Pi. Aucune installation n'a encore été faite.

## Pourquoi un DNS séparé du serveur

Si le serveur Proxmox tombe, le réseau doit continuer de résoudre les noms. Le Pi reste allumé en permanence, et sa panne n'empêche pas les autres machines de naviguer.

## Prérequis

- Raspberry Pi 4 ou 5, 4 Go de RAM minimum.
- SSD USB de bonne qualité, ou carte SD si aucun SSD n'est disponible (plus fragile).
- Raspberry Pi OS Lite 64 bits, installé avec Raspberry Pi Imager.
- Une clé SSH Ed25519 sur ton poste (`ssh-keygen -t ed25519`).
- Une adresse MAC notée pour le Pi, et une adresse IP réservée dans le DHCP de pfSense.

## Étapes

1. **Flasher le système** avec Raspberry Pi Imager : Raspberry Pi OS Lite 64 bits. Dans les options avancées, activer SSH et renseigner ta clé publique, pour éviter le mot de passe.
2. **Démarrer le Pi** et le connecter au switch, sur le VLAN serveurs.
3. **Réserver l'adresse IP** dans pfSense : Services > DHCP Server, réservation statique à partir de l'adresse MAC du Pi.
4. **Se connecter** : `ssh admin@<ip-réservée>`.
5. **Copier le script** `bootstrap.sh` sur le Pi, puis le lancer avec les variables :

```bash
sudo ADMIN_USER=admin \
     SSH_PUBKEY_FILE=/home/admin/.ssh/id_ed25519.pub \
     LAN_CIDR=10.10.10.0/24 \
     ./bootstrap.sh
```

   Remplace `LAN_CIDR` par le sous-réseau réel du VLAN serveurs, une fois défini. Le script désactive la connexion par mot de passe : teste la connexion par clé dans une autre session avant de fermer la première.

6. **Installer AdGuard Home** : voir [`adguard/README.md`](adguard/README.md).
7. **Configurer pfSense** : distribuer l'IP du Pi comme serveur DNS par le DHCP.

## Vérification

- `ss -tlnp` : le port 53 doit être en écoute, et le port 3000 pendant l'installation.
- Depuis un poste du LAN : `nslookup example.com <ip-du-pi>` doit répondre.
- Les requêtes doivent apparaître dans le tableau de bord d'AdGuard.

## Ce qui reste à décider

- Adresse IP et sous-réseau définitifs (voir `network/addressing.md`).
- Serveurs DNS en amont : DNS-over-HTTPS ou DNS-over-TLS.
- Accès à l'interface d'administration après installation : limiter au VLAN de management.
