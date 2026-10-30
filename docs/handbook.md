# Handbook du homelab

Mode d'emploi du homelab : ce qui tourne, où, comment s'y connecter, et quoi faire en cas de panne. Ce document décrit l'état **actuel** du réseau. Les points marqués **(à faire)** ne sont pas encore appliqués. Le journal de la migration est dans `docs/migration-opnsense-2026-10.md`.

## 1. Vue d'ensemble

```
Internet
   │
Wi-Fi (wlan0 du Pi, client)
   │
Raspberry Pi 5 : eth0 10.0.10.1/24 (passerelle du réseau principal)
   │  Caddy, AdGuard, Portainer (Docker)
   │  Tailscale (accès distant)
   │  wlan1 : 10.0.11.1/24 (point d'accès homelab-ap)
   │
   └── même câble ── px1 (vmbr0, sans IP de transit) : 10.0.10.148
                       │
                       └── OPNsense (VM 100)
                             WAN em0 : 10.0.10.204 (DHCP)
                             srv   em1 : 10.0.30.1/24
                             iot   em2 : 10.0.40.1/24
                             guest em3 : 10.0.50.1/24
```

## 2. Adresses

| Machine | Interface | Adresse | Rôle |
|---|---|---|---|
| Pi | eth0 | 10.0.10.1/24 | Passerelle du réseau principal |
| Pi | wlan1 | 10.0.11.1/24 | Point d'accès `homelab-ap` |
| px1 | nic0 / vmbr0 | sans IP de transit | Pont vers OPNsense (WAN) |
| px1 | hôte | 10.0.10.148/24 | Administration Proxmox |
| OPNsense | em0 (WAN) | 10.0.10.204 (DHCP) | Sortie vers le Pi |
| OPNsense | em1 (srv) | 10.0.30.1/24 | Passerelle du segment `srv` |
| OPNsense | em2 (iot) | 10.0.40.1/24 | Passerelle du segment `iot` |
| OPNsense | em3 (guest) | 10.0.50.1/24 | Passerelle du segment `guest` |

Plages DHCP (Kea) : `10.0.30.100`–`10.0.30.200`, `10.0.40.100`–`10.0.40.200`, `10.0.50.100`–`10.0.50.200`.

> **Note** : `10.0.20.0/24` n'est pas utilisée. Elle était réservée à l'ancien WireGuard, supprimé.

## 3. Accès

| Quoi | Comment |
|---|---|
| Interface Proxmox | `https://10.0.10.148:8006`, ou via le tunnel Tailscale (`localhost:8006` sur le poste) |
| Shell px1 | `ssh root@10.0.10.148` |
| Interface OPNsense | `https://10.0.30.1` depuis `srv`, ou via le WAN (règle Pi autorisée) |
| Console OPNsense | Proxmox → VM 100 → Console, ou option `8` (Shell) |
| Pi | SSH via son adresse Tailscale (accès de secours) |

## 4. Services

### Sur le Pi (Docker Compose)
- **Caddy** (2.8.4) : reverse proxy HTTPS avec CA interne, noms `*.homelab`. Reste sur le Pi.
- **AdGuard Home** (v0.107.79) : DNS de filtrage. Emplacement à décider.
- **Portainer CE** (2.21.4) : gestion Docker, en `127.0.0.1:9443`.

### Sur px1
- **Proxmox VE 9.2.2** (noyau 7.0.2). Mise à jour 9.2.24 à faire.
- **OPNsense 26.7** (VM 100) : routage, pare-feu, DHCP Kea. DNS Unbound à configurer.
- **VM 200** (`test-srv`, Alpine 3.24.3) : machine de test sur `srv`. **À supprimer** après les tests.

### Tailscale
- Actif sur le Pi.
- **(à faire)** : routes `10.0.10.0/24` et `10.0.30.0/24` à approuver, puis ACL par groupes.

## 5. Procédures

### Vérifier le réseau

Sur px1 :
```bash
ip -br link          # nic0 et vmbr0 doivent être UP
ip -br a             # vmbr0 doit avoir 10.0.10.148/24
qm status 100        # OPNsense doit être running
ping -c2 10.0.10.1   # Pi
ping -c2 1.1.1.1     # Internet via OPNsense
```

Sur OPNsense (console, option `8`) :
```bash
ifconfig em0 | grep "inet "   # 10.0.10.204
ifconfig em1 | grep "inet "   # 10.0.30.1
ifconfig em2 | grep "inet "   # 10.0.40.1
ifconfig em3 | grep "inet "   # 10.0.50.1
```

Sur le Pi :
```bash
ip route | grep "10.0."
# attendu :
# 10.0.30.0/24 via 10.0.10.204
# 10.0.40.0/24 via 10.0.10.204
# 10.0.50.0/24 via 10.0.10.204
```

### Démarrer ou arrêter OPNsense

Sur px1 :
```bash
qm start 100
qm shutdown 100    # arrêt propre, préférer à qm stop
```

Un arrêt de la VM 100 coupe Internet pour les segments `srv`, `iot` et `guest`. Le nœud et le Pi restent joignables.

### Ajouter un appareil de test sur `srv`

Une VM ou un appareil branché sur le bridge `srv` reçoit une adresse `10.0.30.1xx` par DHCP, avec la passerelle `10.0.30.1`. Vérifier avec `ip a` et `ip route` dans la machine.

## 6. Dépannage

| Symptôme | Cause probable | Action |
|---|---|---|
| Plus d'accès à `10.0.10.148` | Le nœud a perdu son lien physique ou sa route | Console de px1, puis `ip -br link` pour vérifier `nic0` et `vmbr0` |
| Ping vers `10.0.30.1` échoue depuis `srv` | Règle `Block` de `srv` qui couvre aussi la passerelle | Ajouter une règle `Pass` sur LAN : source `LAN net`, destination `LAN address`, au-dessus du `Block` |
| Pas d'adresse DHCP sur un segment | Kea non activé pour l'interface, ou plage saturée | Services → Kea DHCP → Settings, vérifier les interfaces cochées |
| Ping du Pi vers OPNsense échoue | Option **Block private networks** cochée sur le WAN | Interfaces → WAN : décocher, puis appliquer |
| `Network is down` dans une VM Alpine | Interface `eth0` désactivée au démarrage | `ip link set eth0 up`, puis `udhcpc -i eth0` |
| `ip -br` introuvable dans une VM Alpine | BusyBox n'accepte pas cette option | Utiliser `ip a` |
| Route vers un segment absente sur le Pi | Route temporaire perdue après redémarrage | Relancer `ip route replace … via 10.0.10.204` (les routes permanentes sont à faire) |

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

- Ajouter la règle `Pass` sur `srv` vers `LAN address`, pour que la passerelle réponde.
- Valider la sortie Internet des segments depuis la VM 200.
- Rendre les routes du Pi permanentes.
- Réservation DHCP du WAN : `10.0.10.204` actuellement.
- Vérifier que l'ISO est retirée de la VM 100.
- Unbound DNS sur `srv`, `iot` et `guest`.
- Tailscale : routes, ACL par groupes.
- Supprimer la VM 200 après les tests.
- Mise à jour de Proxmox vers 9.2.24.
- Test du mode 4 adresses du RTL8188EUS (`iw list`).
- Disque 256 Go : reporté.
