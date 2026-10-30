# Handbook du homelab

Mode d'emploi du homelab : ce qui tourne, où, comment s'y connecter, et quoi faire en cas de panne. Ce document décrit l'état **cible** du réseau. Les points marqués **(à faire)** ne sont pas encore appliqués. Le journal de la migration est dans `docs/migration-opnsense-2026-10.md`.

## 1. Vue d'ensemble

```
Internet
   │
Wi-Fi « misen » (wlan0, client)
   │
Raspberry Pi 5 ──── eth0 : 10.255.0.1/24 ────┐
   │  Caddy, AdGuard, Portainer (Docker)     │
   │  Tailscale (accès distant)              │
   │                                         │
   │  wlan1 « homelab-ap » : 10.0.11.1/24    │
   │                                         │
   └──────── même câble ──── vmbr0 (px1) ────┤
                                             │
                            OPNsense (VM 100)│
                            WAN em0 : 10.255.0.2 (DHCP réservé)
                            LAN mgmt em1 : 10.0.10.1/24
                            srv em3, iot em4, guest em2
                                             │
                            px1 (Proxmox VE 9)
                            mgmt : 10.0.10.2/24
```

## 2. Adresses

| Machine | Interface | Adresse | Rôle |
|---|---|---|---|
| Pi | eth0 | 10.255.0.1/24 | Lien vers OPNsense |
| Pi | wlan1 | 10.0.11.1/24 | Point d'accès `homelab-ap` |
| OPNsense | em0 (WAN) | 10.255.0.2 (DHCP réservé) | Sortie vers le Pi |
| OPNsense | em1 (mgmt) | 10.0.10.1/24 | Passerelle d'administration |
| OPNsense | em2 (guest) | (à faire) | VNet `guest` |
| OPNsense | em3 (srv) | (à faire) | VNet `srv` |
| OPNsense | em4 (iot) | (à faire) | VNet `iot` |
| px1 | mgmt | 10.0.10.2/24 | Administration Proxmox |
| px1 | vmbr0 | sans IP | Transit du WAN |

Plages prévues : `10.0.10.0/24` (mgmt), `10.0.30.0/24` (srv), `10.0.40.0/24` (iot), `10.0.50.0/24` (guest) — voir la note sur `guest` ci-dessous.

> **Note** : le plan initial mentionnait `10.0.20.0/24` pour un VNet, mais cette plage est occupée par l'ancien WireGuard (`wg0`, supprimé). À vérifier avant de créer le VNet correspondant.

## 3. Accès

| Quoi | Comment |
|---|---|
| Interface Proxmox | `https://10.0.10.2:8006` (une fois `mgmt` joignable) |
| Shell px1 | `ssh root@10.0.10.2` |
| Interface OPNsense | `https://10.0.10.1` (depuis le réseau `mgmt`) |
| Console OPNsense | Proxmox → VM 100 → Console, ou option `8` (Shell) |
| Pi | `ssh` via son adresse Tailscale (la plus fiable en cas de panne) |
| Accès distant | Tailscale uniquement, WireGuard supprimé |

## 4. Services

### Sur le Pi (Docker Compose)

- **Caddy** (2.8.4) : reverse proxy HTTPS avec CA interne (`tls internal`), noms `*.homelab`. Reste sur le Pi.
- **AdGuard Home** (v0.107.79) : DNS de filtrage. Décision en attente pour son emplacement.
- **Portainer CE** (2.21.4) : gestion Docker, en `127.0.0.1:9443`.

### Sur px1

- **Proxmox VE 9** (noyau `7.0.14-26-pve`, hôte `px1.home.lab`).
- **OPNsense 26.7** (VM 100) : routage, pare-feu, DHCP et DNS (Unbound) à configurer.

### Tailscale

- Déjà actif sur le Pi.
- **(à faire)** : routes `10.0.10.0/24` et `10.0.20.0/24` à approuver dans la console Tailscale, puis ACL par groupes.

## 5. Procédures

### Vérifier que le réseau est sain

Sur px1 :
```bash
ip -br link          # enp1s0 et vmbr0 doivent être UP
bridge link          # enp1s0 doit être attaché à vmbr0
ip -br a             # mgmt doit avoir 10.0.10.2/24
qm status 100        # OPNsense doit être running
ping -c2 10.0.10.1   # OPNsense LAN
ping -c2 1.1.1.1     # Internet via OPNsense
```

Sur OPNsense (console, option `8`) :
```bash
ifconfig em0 | grep "inet "   # 10.255.0.2
ifconfig em1 | grep "inet "   # 10.0.10.1
```

### Démarrer ou arrêter OPNsense

Sur px1 :
```bash
qm start 100
qm shutdown 100    # arrêt propre, préférer à qm stop
```

Un arrêt de la VM 100 coupe l'accès aux VNet et au WAN du lab. Le Pi reste joignable via Tailscale et son Wi-Fi `misen`.

### Modifier le réseau du Pi

- Fichiers : `/etc/NetworkManager/dnsmasq-shared.d/` (DHCP) et connexions `nmcli`.
- Connexion de `eth0` : `homelab-lan`.
- Ne pas modifier `eth0` depuis une session SSH qui passe par ce même lien sans console ou accès Tailscale de secours.

### Modifier le réseau de px1

- Fichier : `/etc/network/interfaces` (sauvegardé avant chaque changement).
- Appliquer avec `ifreload -a`, jamais avec un redémarrage à chaud.
- Attention : la carte physique s'appelle `enp1s0` depuis le noyau `7.0.14`. Il n'y a plus de `nic0` (le nom était `nic0` avant, à ne pas remettre).

## 6. Dépannage

| Symptôme | Cause probable | Action |
|---|---|---|
| Plus d'accès à `10.0.10.2` | Changement de l'adresse du nœud ou de `eth0` du Pi | Passer par Tailscale vers le Pi, puis `ip addr add` temporaire sur `eth0` si nécessaire |
| `ping 10.0.10.1` échoue depuis px1 | OPNsense arrêtée, ou `em1` sans IP | `qm status 100`, puis configurer `em1` dans l'interface web (Interfaces → opt1) |
| `enp1s0` DOWN | Câble débranché, ou nom de carte modifié | `ip -br link`, vérifier le câble, adapter `bridge-ports` |
| `ifconfig em0` sans `10.255.0.2` | Réservation DHCP absente côté Pi | Vérifier `homelab-dhcp.conf` sur le Pi et relancer le WAN en DHCP |
| `ping 10.0.10.148` échoue depuis le Pi | Route `10.0.10.0/24` via `10.255.0.2` qui masque le lien direct | `ip route get 10.0.10.148`, puis `ip route replace … dev eth0` |
| Interface web OPNsense inaccessible | Interface LAN sur `mgmt` non joignable | Utiliser la console de la VM 100 depuis Proxmox |

## 7. Sauvegardes

- Nœud : `/root/backup-bascule-2026-10-29-1245/` (`interfaces`, `interfaces.d`, `sdn`, `100.conf`).
- Pi : `/root/backup-bascule-2026-10-29-1247/` (`system-connections`, `dnsmasq-shared.d`, états `ip` et `nmcli`).
- **(à faire)** : sauvegarde régulière de la VM 100 (`vzdump`) et de la configuration du Pi.

Restaurer `/etc/network/interfaces` sur px1 :
```bash
cp /root/backup-bascule-2026-10-29-1245/interfaces /etc/network/interfaces
ifreload -a
```

## 8. Points ouverts

- Configurer `em1` (LAN) en `10.0.10.1/24` et valider les pings.
- Créer les VNet `srv`, `iot` et `guest` avec leurs plages dans le SDN.
- Règles de pare-feu OPNsense par VNet.
- DHCP par VNet et Unbound vers `10.255.0.1`.
- Décision sur l'emplacement d'AdGuard et de Portainer.
- Tailscale : routes et ACL.
- Test du mode 4 adresses du RTL8188EUS (`iw list`) pour savoir si le Pi peut redevenir pont de couche 2.
- Disque 256 Go : reporté.
- Confirmer `apt dist-upgrade` sur px1 et le Pi.
