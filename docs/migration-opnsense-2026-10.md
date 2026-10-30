# Migration vers OPNsense et SDN Proxmox (octobre 2026)

Journal de la bascule du routage du homelab : le Raspberry Pi cesse d'être le routeur, et OPNsense (VM 100 sur px1) prend le rôle de routeur et de pare-feu. Le Pi garde Caddy et les services Docker.

> Statut au 29 octobre 2026 : **en cours**. Les étapes 1 à 4 sont faites, l'étape 5 (bascule) est partiellement appliquée.

## Contraintes de départ

- Un seul nœud Proxmox VE 9 (px1, mini-PC AMD) avec un seul port Ethernet, sans switch.
- Le Raspberry Pi 5 reste le point d'accès au réseau existant (câble vers `eth0`, Wi-Fi `misen` en client, Wi-Fi `homelab-ap` en point d'accès).
- Pas de matériel supplémentaire pour l'instant.
- WireGuard est supprimé au profit de Tailscale.

## Architecture cible

| Élément | Rôle | Réseau |
|---|---|---|
| Pi `eth0` | Lien vers OPNsense | `10.255.0.1/24` |
| OPNsense WAN (`em0`) | Accès vers le Pi | `10.255.0.2` (DHCP réservé) |
| OPNsense LAN `mgmt` (`em1`) | Passerelle d'administration | `10.0.10.1/24` |
| px1 `mgmt` | Administration du nœud | `10.0.10.2/24` |
| VNet `srv` | Services | `10.0.30.0/24` |
| VNet `iot` | Objets connectés | `10.0.40.0/24` |
| VNet `guest` | Invités | `10.0.50.0/24` |

Le SDN Proxmox (zone `homelab`, type Simple) crée les VNet `mgmt`, `srv`, `iot` et `guest`. Il n'y a ni DHCP ni SNAT au niveau du SDN : ces fonctions restent sur OPNsense.

## Étapes

### 1. Préparer Proxmox

- Dépôts `pve-no-subscription` actifs, dépôts entreprise désactivés (déplacés dans `/root/apt-disabled/`).
- Zone SDN `homelab` et VNet `mgmt`, `srv`, `iot`, `guest` créés et vérifiés (`ip -br a`).
- Clé USB exFAT `USB1` testée.

### 2. Installer OPNsense 26.7

- VM ID 100, carte WAN sur `vmbr0` (`net0`, e1000).
- Cartes VNet ajoutées : `net1` `mgmt`, `net2` `guest`, `net3` `srv`, `net4` `iot` (toutes en e1000).
- OPNsense nomme les cartes `em0` à `em4` (e1000). Un modèle VirtIO donnerait `vtnet0` à `vtnet4`.
- Le WAN est `em0`, en DHCP.

### 3. Vérifier le WAN

- `em0` obtient `10.255.0.2` après la réservation DHCP sur le Pi.
- Le Pi répond sur `eth0` avec `10.255.0.1`.

### 4. Basculer le Pi

- Retrait de WireGuard (`wg0`) qui était en conflit avec le plan `10.0.20.0/24`.
- Suppression de l'ancien fichier DHCP AdGuard (`adguard.conf`).
- Réservation DHCP `10.255.0.2` pour le WAN d'OPNsense (fichier `dnsmasq-shared.d/homelab-dhcp.conf`).
- `eth0` passe en `10.255.0.1/24`, avec les routes vers `10.0.10.0/24`, `10.0.20.0/24`, `10.0.30.0/24` et `10.0.40.0/24` via `10.255.0.2`.

### 5. Basculer le nœud (en cours)

- `vmbr0` garde le transit du WAN, sans adresse IP.
- Le VNet `mgmt` reçoit `10.0.10.2/24`, avec la passerelle `10.0.10.1` (OPNsense LAN).
- Problème rencontré : après la bascule, le nœud n'avait plus de lien physique, car le nom de la carte a changé avec le noyau. La carte est passée de `nic0` à `enp1s0`. Le bridge `vmbr0` pointait encore sur `nic0`.
- Correction : `bridge-ports` et `iface` passent sur `enp1s0`, puis `ifreload -a`.
- Problème restant : OPNsense ne répondait pas sur `10.0.10.1`, car l'interface LAN (`em1`) n'avait pas encore d'adresse IP. La configuration est à terminer dans l'interface web (Interfaces → opt1 / em1).

## Sauvegardes

- Nœud : `/root/backup-bascule-2026-10-29-1245/` (`interfaces`, `interfaces.d`, `sdn`, `100.conf`).
- Pi : `/root/backup-bascule-2026-10-29-1247/` (`system-connections`, `dnsmasq-shared.d`, états `ip` et `nmcli`).

## Points ouverts

- Terminer la configuration LAN `em1` (`10.0.10.1/24`) et vérifier les pings vers `10.0.10.1` et `1.1.1.1`.
- Règles de pare-feu OPNsense par VNet.
- Unbound DNS vers `10.255.0.1`.
- Décision sur AdGuard et Portainer côté Pi.
- Tailscale : routes `10.0.10.0/24` et `10.0.20.0/24`, validation dans la console, ACL par groupes (Tailscale est déjà actif sur le Pi).
- Test du mode 4 adresses du RTL8188EUS (`iw list`), pour savoir si le Pi peut redevenir pont de couche 2.
- Disque 256 Go : reporté.
