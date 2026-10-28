# Raspberry Pi : routeur du homelab

Le Raspberry Pi transforme une simple connexion Wi-Fi (box ou bureau) en un **réseau local isolé** pour le homelab. Il capte le Wi-Fi amont par une clé USB c'est son **WAN**, applique le **NAT**, et crée un **sous-réseau** câblé et Wi-Fi avec DHCP, DNS filtrant et pare-feu. Il tient ce rôle en attendant OPNsense sur le serveur, et reste indépendant : sa panne n'empêche pas le serveur de fonctionner, et inversement.

**Statut** : en place et vérifié le 2026-10-28.

## Objectif

- Transformer une connexion Wi-Fi amont (reçue en **client**) en un réseau local complet.
- Isoler le homelab derrière un **NAT** ; aucun service exposé sur Internet.
- Filtrer le **DNS** (AdGuard Home) pour tout le réseau.
- Rester **reproductible** et indépendant du serveur.

## Matériel

| Élément | Spécification |
|---|---|
| Carte | Raspberry Pi 5, 8 Go de RAM |
| Alimentation | Officielle 5 V/5 A (une clé USB instable vient souvent d'une sous-tension) |
| Stockage | Carte microSD 64 Go |
| Système | Raspberry Pi OS, Debian 13 (trixie) |
| Clé Wi-Fi USB | Realtek RTL8188EUS — **sortie Internet (WAN, client)** |
| Wi-Fi intégré | **Point d'accès** du Wi-Fi homelab |
| Ethernet (`eth0`) | LAN homelab en câble |



> **Noms d'interface** : selon le pilote, la clé USB et le Wi-Fi intégré peuvent échanger leurs noms (`wlan0` ↔ `wlan1`) d'un démarrage à l'autre. On accroche donc chaque profil à son **adresse MAC**, jamais à un nom (voir [`wifi/`](wifi/README.md)). Dans l'état actuel : clé USB = `wlan0`, Wi-Fi intégré = `wlan1`.

## Architecture

```
Wi-Fi de la box ou du bureau ~~~ clé USB (WAN, client, adresse reçue en DHCP)
                                    │
                              [Raspberry Pi]  AdGuard Home + DHCP + NAT
                               │          │
   eth0 10.0.10.1/24 ── câble ─┘          └─ Wi-Fi intégré 10.0.11.1/24 ~~~ Wi-Fi homelab
   1 appareil (pas de switch)                téléphones, ordinateurs
```

| Réseau | Interface | Plage | Rôle du Pi |
|---|---|---|---|
| LAN câble | `eth0` | `10.0.10.0/24` | Passerelle, DHCP, DNS |
| LAN Wi-Fi | Wi-Fi intégré | `10.0.11.0/24` | Point d'accès, passerelle, DHCP, DNS |
| Sortie (WAN) | clé USB | DHCP de la box ou du bureau | Client |

Ces plages sont provisoires, en attendant le plan d'adressage avec la segmentation VLAN.

**Pourquoi la clé sert de sortie** : le Wi-Fi intégré gère le mode point d'accès (`AP`), pas la clé RTL8188EUS. C'est donc l'intégré qui diffuse le Wi-Fi homelab, et la clé qui va chercher Internet.

## Mise en place — comment le Pi devient routeur

### 1. Le WAN : capter le Wi-Fi amont par la clé USB

La clé se connecte au Wi-Fi amont comme un simple client ; l'adresse de sortie est reçue en DHCP. On accroche le profil à la **MAC de la clé** pour qu'il survive à un renommage d'interface, et on coupe l'économie d'énergie (source de coupures).

```bash
ip link show                       # relever la MAC de la clé USB
sudo nmcli connection modify "<profil-amont>" \
  802-11-wireless.mac-address <MAC-CLE-USB> connection.interface-name "" \
  802-11-wireless.powersave 2
sudo nmcli connection up "<profil-amont>"
```

> Le pilote du noyau (`rtl8xxxu`) rend cette clé très lente. Le passage au pilote `8188eu` (×55 sur le débit) est décrit dans [`wifi/`](wifi/README.md).

### 2. Le routage et le NAT

```bash
sudo cp lan/adguard.conf /etc/NetworkManager/dnsmasq-shared.d/
sudo install -m 755 lan/90-homelab-forward /etc/NetworkManager/dispatcher.d/
```

Le mode `shared` de NetworkManager (étapes 3 et 4) fournit le **DHCP** (dnsmasq) et le **NAT**. Docker met la politique `FORWARD` en `DROP` : le script `90-homelab-forward` ajoute dans `DOCKER-USER` les règles qui autorisent les deux LAN à sortir par la clé USB. NetworkManager l'exécute à chaque montée d'interface.

### 3. Le LAN câble (`eth0`)

```bash
sudo nmcli connection add type ethernet ifname eth0 con-name homelab-lan \
  ipv4.method shared ipv4.addresses 10.0.10.1/24 ipv6.method disabled
```

### 4. Le LAN Wi-Fi : le point d'accès

Le nom (SSID) et le mot de passe sont lus au clavier, pour ne pas apparaître dans l'historique. Coller les lignes une par une : une ligne collée pendant un `read` est prise comme réponse.

```bash
read -rp "SSID : " SSID; read -rsp "Mot de passe (8 caractères min.) : " PSK; echo
```
```bash
sudo nmcli connection add type wifi con-name homelab-ap autoconnect yes ssid "$SSID" \
  802-11-wireless.mode ap 802-11-wireless.band a 802-11-wireless.channel 36 \
  802-11-wireless.mac-address <MAC-WIFI-INTEGRE> connection.interface-name "" \
  ipv4.method shared ipv4.addresses 10.0.11.1/24 ipv6.method disabled \
  wifi-sec.key-mgmt wpa-psk wifi-sec.proto rsn wifi-sec.pairwise ccmp wifi-sec.group ccmp \
  wifi-sec.pmf disable wifi-sec.psk "$PSK"; unset PSK
sudo nmcli connection up homelab-ap
```

| Réglage | Raison |
|---|---|
| MAC + `interface-name ""` | Le profil suit la puce, pas le nom d'interface (qui peut permuter) |
| `band a` canal 36 (5 GHz) | Bande moins encombrée et plus rapide que la 2,4 GHz ; canal 36 sans contrainte radar (DFS) |
| WPA2 (`rsn`, `ccmp`) | Chiffrement standard, compatible avec tous les clients |
| `pmf disable` | La puce du Pi a des soucis connus avec la protection des trames de gestion en mode AP |

### 5. Le DNS filtrant : AdGuard Home

```bash
mkdir -p ~/adguard && cd ~/adguard   # copier ici compose.yaml
docker compose up -d
```

- Ports publiés sur **une seule adresse**, pas sur toutes les interfaces : le Pi a une IPv6 publique, et un DNS ouvert sur Internet serait exploité pour des attaques par amplification.
- Adresse réglable par `ADGUARD_IP`, `192.168.1.81` par défaut (la maison).
- Version **figée** : une mise à jour se fait volontairement, en changeant la version dans `compose.yaml`.
- DNS amont : Quad9 en DNS-over-HTTPS, avec DNSSEC.

## Fichiers

| Fichier | Emplacement sur le Pi | Rôle |
|---|---|---|
| [`adguard/compose.yaml`](adguard/compose.yaml) | `~/adguard/compose.yaml` | AdGuard Home dans Docker |
| [`lan/adguard.conf`](lan/adguard.conf) | `/etc/NetworkManager/dnsmasq-shared.d/` | DNS des LAN vers AdGuard |
| [`lan/90-homelab-forward`](lan/90-homelab-forward) | `/etc/NetworkManager/dispatcher.d/` (mode 755) | Routage des LAN vers la sortie, malgré Docker |
| [`wifi/README.md`](wifi/README.md) | — | Pilote de la clé USB : diagnostic, DKMS, bascule à distance |

## Hors de la maison

AdGuard et le DNS des LAN visent `192.168.1.81`, l'adresse du Pi à la maison. Ailleurs, elle n'existe pas : le conteneur refuse de démarrer (`cannot assign requested address`) et le DNS des LAN ne répond plus.

| Lieu | AdGuard | `lan/adguard.conf` |
|---|---|---|
| Maison | `docker compose up -d` | `server=192.168.1.81` |
| Ailleurs | `ADGUARD_IP=127.0.0.1 docker compose up -d` | `server=127.0.0.1` |

Après un changement de `adguard.conf` : `sudo nmcli connection up homelab-lan`, puis `sudo nmcli connection up homelab-ap`.

Hors de la maison, l'interface web n'est joignable que depuis le Pi lui-même. On y accède par un tunnel SSH : `ssh -N -L 8080:127.0.0.1:8080 <utilisateur>@10.0.10.1`, puis `http://localhost:8080`.

## Vérification

Depuis un poste du LAN :

```bash
dig +short @10.0.10.1 example.com       # une adresse
dig +short @10.0.10.1 doubleclick.net   # 0.0.0.0 : bloqué par AdGuard
traceroute -n 1.1.1.1                   # premier saut : 10.0.10.1
```

Sur le Pi :

```bash
ip route show default                    # sortie par la clé USB
sudo iptables -S DOCKER-USER             # règles des LAN vers la clé
sudo iw dev <if-ap> station dump         # clients du Wi-Fi homelab
```

## Sécurité

- **NAT** : le homelab est caché derrière l'adresse de sortie ; aucun port de service exposé.
- **DNS** lié à une seule adresse, jamais à toutes les interfaces (le Pi a une IPv6 publique).
- **Cloisonnement** : le LAN câble et le LAN Wi-Fi ne communiquent pas entre eux ; le pare-feu n'autorise que leur sortie vers Internet.
- **Secrets** : SSID et mot de passe du Wi-Fi lus au clavier, jamais versionnés.

## Points ouverts

- La clé n'a pas la même adresse MAC que le Wi-Fi intégré : la box lui donnera sans doute une autre adresse que `192.168.1.81`. Prévoir une réservation DHCP sur la box.
- Sans switch, un seul appareil peut être branché sur le LAN câble.
- Point d'accès plafonné à 20 MHz par NetworkManager ; le 40/80 MHz demandera `hostapd` (voir [`wifi/`](wifi/README.md)).
- Domaine réglementaire à régler sur le bon pays.
- Le comportement après un redémarrage du Pi reste à confirmer dans la durée.

## Références

- NetworkManager, partage de connexion (`shared`) et `nmcli` : <https://networkmanager.dev/docs/api/latest/nmcli.html>
- `dnsmasq` (DHCP/DNS) : <https://thekelleys.org.uk/dnsmasq/doc.html>
- AdGuard Home : <https://github.com/AdguardTeam/AdGuardHome/wiki>
- Pilote de la clé USB, DKMS et bascule à distance : [`wifi/README.md`](wifi/README.md)
