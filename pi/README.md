# Raspberry Pi : DNS filtrant et routeur temporaire

Le Raspberry Pi assure le DNS filtrant (AdGuard Home) et sert de routeur au réseau homelab, en attendant OPNsense sur le serveur. Il est indépendant du serveur : sa panne n'empêche pas les autres machines de naviguer, et inversement.

**Statut** : en place et vérifié le 2026-10-28.

## Matériel

| Élément | Spécification |
|---|---|
| Carte | Raspberry Pi 5, 8 Go de RAM |
| Stockage | Carte microSD 64 Go |
| Système | Raspberry Pi OS, Debian 13 (trixie) |
| Wi-Fi intégré (`wlan0`) | Point d'accès du Wi-Fi homelab |
| Clé Wi-Fi USB (`wlan1`) | Realtek RTL8188EUS, sortie Internet (client) |
| Ethernet (`eth0`) | LAN homelab en câble |

Le Pi est partagé avec un autre projet (SaytuMbaye : InfluxDB, Grafana, MQTT, dans Docker). Ses ports sont réservés, en particulier le 3000 pris par Grafana.

## Architecture

```
Wi-Fi de la box ou du bureau ~~~ clé USB wlan1 (client, adresse reçue en DHCP)
                                    │
                              [Raspberry Pi]  AdGuard Home + DHCP + NAT
                               │          │
   eth0 10.0.10.1/24 ── câble ─┘          └─ wlan0 10.0.11.1/24 ~~~ Wi-Fi homelab
   1 appareil (pas de switch)                téléphones, ordinateurs
```

| Réseau | Interface | Plage | Rôle du Pi |
|---|---|---|---|
| LAN câble | `eth0` | `10.0.10.0/24` | Passerelle, DHCP, DNS |
| LAN Wi-Fi | `wlan0` | `10.0.11.0/24` | Point d'accès, passerelle, DHCP, DNS |
| Sortie | `wlan1` | DHCP de la box ou du bureau | Client |

Ces plages sont provisoires, en attendant le plan d'adressage avec la segmentation VLAN.

**Pourquoi la clé sert de sortie** : `iw phy` montre que la RTL8188EUS ne gère que le mode client (`managed`) avec le pilote du noyau. Le Wi-Fi intégré gère aussi le mode point d'accès (`AP`) : c'est donc lui qui diffuse.

## Fichiers

| Fichier | Emplacement sur le Pi | Rôle |
|---|---|---|
| [`adguard/compose.yaml`](adguard/compose.yaml) | `~/adguard/compose.yaml` | AdGuard Home dans Docker |
| [`lan/adguard.conf`](lan/adguard.conf) | `/etc/NetworkManager/dnsmasq-shared.d/` | DNS des LAN vers AdGuard |
| [`lan/90-homelab-forward`](lan/90-homelab-forward) | `/etc/NetworkManager/dispatcher.d/` (mode 755) | Routage des LAN vers la sortie, malgré Docker |

## Mise en place

### 1. AdGuard Home

```bash
mkdir -p ~/adguard && cd ~/adguard   # copier ici compose.yaml
docker compose up -d
```

- Ports publiés sur une seule adresse, et non sur toutes les interfaces : le Pi a une IPv6 publique, et un DNS ouvert sur Internet serait exploité pour des attaques par amplification.
- Adresse réglable par `ADGUARD_IP`, `192.168.1.81` par défaut (la maison).
- Version figée : une mise à jour se fait volontairement, en changeant la version dans `compose.yaml`.
- DNS amont : Quad9 en DNS-over-HTTPS, avec DNSSEC.

### 2. LAN câble

```bash
sudo cp lan/adguard.conf /etc/NetworkManager/dnsmasq-shared.d/
sudo install -m 755 lan/90-homelab-forward /etc/NetworkManager/dispatcher.d/
sudo nmcli connection add type ethernet ifname eth0 con-name homelab-lan \
  ipv4.method shared ipv4.addresses 10.0.10.1/24 ipv6.method disabled
```

Le mode `shared` de NetworkManager fournit le DHCP (dnsmasq) et le NAT. Docker met la politique `FORWARD` en `DROP` : le script `90-homelab-forward` ajoute dans `DOCKER-USER` les règles qui autorisent `eth0` et `wlan0` à sortir par `wlan1`. NetworkManager l'exécute chaque fois que l'une de ces interfaces monte.

### 3. Sortie par la clé USB

Tous les profils Wi-Fi clients sont rattachés à `wlan1`. Sinon, le Wi-Fi intégré s'y reconnecte et ne peut plus diffuser.

```bash
nmcli -t -f NAME,TYPE connection show | grep ':802-11-wireless$' | cut -d: -f1 \
  | while IFS= read -r c; do sudo nmcli connection modify "$c" connection.interface-name wlan1; done
sudo nmcli connection up "<profil-wifi>"
sudo nmcli connection modify "<profil-wifi>" 802-11-wireless.powersave 2
```

La dernière ligne désactive l'économie d'énergie, qui provoque des coupures.

### 4. Wi-Fi homelab

Le nom et le mot de passe sont lus au clavier, pour ne pas apparaître dans l'historique. Coller les lignes une par une : une ligne collée en même temps qu'un `read` est prise comme réponse.

```bash
read -rp "SSID : " SSID; read -rsp "Mot de passe (8 caractères min.) : " PSK; echo
```
```bash
sudo nmcli connection add type wifi ifname wlan0 con-name homelab-ap autoconnect yes ssid "$SSID" \
  802-11-wireless.mode ap 802-11-wireless.band bg \
  ipv4.method shared ipv4.addresses 10.0.11.1/24 ipv6.method disabled \
  wifi-sec.key-mgmt wpa-psk wifi-sec.proto rsn wifi-sec.pairwise ccmp wifi-sec.group ccmp \
  wifi-sec.pmf disable wifi-sec.psk "$PSK"; unset PSK
sudo nmcli connection up homelab-ap
```

| Réglage | Raison |
|---|---|
| `band bg` (2,4 GHz) | Le 5 GHz en point d'accès exige un pays réglementaire correctement configuré |
| WPA2 (`rsn`, `ccmp`) | Chiffrement standard, compatible avec tous les clients |
| `pmf disable` | La puce du Pi a des soucis connus avec la protection des trames de gestion en mode point d'accès |

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
ip route show default                    # dev wlan1
sudo iptables -S DOCKER-USER             # règles eth0 et wlan0 vers wlan1
sudo iw dev wlan0 station dump           # clients du Wi-Fi homelab
```

## Limites connues

- **Sortie très lente** : environ 1,3 Mbit/s par la clé, contre environ 154 Mbit/s sur le même Wi-Fi en direct (mesuré le 2026-10-28). Le câble n'est pas en cause : 1 Gbit/s négocié, 0 % de perte. Pistes : économie d'énergie de la clé, interférences entre la clé et le point d'accès (tous deux en 2,4 GHz), pilote de la puce. Une clé à puce MediaTek (MT7612U, MT7921AU) est une alternative mieux gérée sous Linux.
- La clé n'a pas la même adresse MAC que le Wi-Fi intégré : la box lui donnera sans doute une autre adresse que `192.168.1.81`. Prévoir une réservation DHCP sur la box.
- Sans switch, un seul appareil peut être branché sur le LAN câble.
- Le LAN câble et le LAN Wi-Fi ne communiquent pas entre eux : le pare-feu n'autorise que leur sortie vers Internet.
- Le comportement après un redémarrage du Pi n'a pas encore été testé.
