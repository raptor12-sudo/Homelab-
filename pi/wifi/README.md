# Rendre la clé Wi-Fi performante, et basculer un pilote à distance sans se couper l'accès

**Niveau** : intermédiaire · **Durée** : ~45 min · **Vérifié le** : 2026-10-28

Ce document décrit, étape par étape, comment on a fait passer la sortie Internet du
Raspberry Pi de **1,3 Mbit/s à 72 Mbit/s** en changeant le pilote de la clé Wi-Fi USB, et
comment on a mené cette bascule **à distance** sans jamais risquer de perdre l'accès à la
machine. Il couvre autant le réglage Wi-Fi que l'administration à distance.

> Aucune donnée réelle de l'infrastructure n'apparaît ici : adresses MAC, noms de réseaux
> Wi-Fi (SSID), mots de passe et noms de lieux sont remplacés par des `<PLACEHOLDER>`.
> Remplace-les par les tiens avant d'exécuter.

## Prérequis

- Un **Raspberry Pi 5** (ou équivalent) sous **Raspberry Pi OS** (Debian 13), avec une
  **alimentation officielle 5 V/5 A** (indispensable pour une clé USB stable).
- Une **clé Wi-Fi USB Realtek RTL8188EUS** (`lsusb` doit montrer `0bda:8179`).
- Le Pi déjà configuré en **routeur** : clé USB en sortie Internet (client), Wi-Fi intégré
  en **point d'accès**, le tout géré par **NetworkManager**, avec **dnsmasq** pour le
  DHCP/DNS. *(C'est le point de départ ; la mise en place du routeur est couverte par le
  [README du Pi](../README.md).)*
- Un **accès à la machine** : soit en local (écran + clavier), soit à distance (SSH, VPN).
  **En local, le filet de sécurité de l'étape 3b est facultatif** — il ne sert que si une
  erreur peut te couper ta voie d'accès à distance.
- Les droits `sudo`.

## Conventions — les placeholders à remplacer

| Placeholder | Ce que c'est | Comment le trouver |
|---|---|---|
| `<PROFIL-SORTIE>` | Nom du profil NetworkManager de la sortie Internet | `nmcli connection show` |
| `<PROFIL-AP>` | Nom du profil NetworkManager du point d'accès | `nmcli connection show` |
| `<MAC-CLE-USB>` | Adresse MAC de la clé Wi-Fi USB | `ip link show` (interface de la clé) |
| `<MAC-WIFI-INTEGRE>` | Adresse MAC du Wi-Fi intégré | `ip link show` (interface interne) |
| `<IF-AP>` | Nom de l'interface qui porte le point d'accès | `nmcli device status` |

> Une adresse MAC ressemble à `aa:bb:cc:dd:ee:ff`. Elle identifie physiquement la carte et
> ne change pas, même si le système renomme l'interface — c'est pour ça qu'on s'appuie
> dessus (étape 3a).

## Le contexte

Le Pi prend Internet par une clé Wi-Fi USB (chipset **Realtek RTL8188EUS**) et le
redistribue. Symptôme : un débit ridicule (~1,3 Mbit/s) alors que le lien direct donnait
plus de 150 Mbit/s. Matériel en cause ? Non. **Pilote en cause.**

## La notion de départ : pilote ≠ matériel

Un même chipset Wi-Fi peut donner 1 Mbit/s ou 40 Mbit/s **selon le pilote**. Le noyau Linux
charge par défaut `rtl8xxxu`, un pilote générique qui gère mal le RTL8188EUS. Le bon pilote
pour ce chip est celui de la communauté, **`8188eu`** (dépôt aircrack-ng), qu'on compile
soi-même.

## Étape 1 — diagnostiquer

```bash
# Quel pilote porte la clé, et quel chip est-ce vraiment ?
sudo ethtool -i wlan1 | grep driver        # -> driver: rtl8xxxu  (le coupable)
lsusb | grep -i realtek                     # -> RTL8188EUS 802.11n
iw dev wlan1 link | grep -iE 'signal|bitrate'   # débit négocié ridicule
vcgencmd get_throttled                      # 0x0 = OK ; sinon sous-tension
```

`vcgencmd get_throttled` à `0x50000` signalait qu'une **sous-tension** s'était produite :
une clé USB qui manque de courant perd des paquets, le débit s'effondre. Leçon : avant
d'accuser le logiciel, vérifie l'alimentation (PSU officiel 5 V/5 A pour un Pi 5).

## Étape 2 — compiler le bon pilote en DKMS

**La notion — DKMS** : un pilote doit être compilé *contre le noyau exact* de la machine.
DKMS (Dynamic Kernel Module Support) automatise ça et **recompile le module à chaque mise à
jour du noyau** — sinon un `apt upgrade` te ferait perdre le Wi-Fi.

```bash
sudo apt update && sudo apt install -y git dkms build-essential bc
git clone https://github.com/aircrack-ng/rtl8188eus
cd rtl8188eus
sudo ./dkms-install.sh        # compile + enregistre le module 8188eu
```

Vérifier que le module est bien construit **avant toute suite** :

```bash
sudo dkms status                                   # doit lister 8188eu, installed
find /lib/modules/$(uname -r) -name '8188eu.ko*'   # le fichier doit exister
```

> Sur un noyau très récent (ici 6.12), la compilation peut échouer : lis les lignes
> `error:` et cherche un correctif pour ta version avant d'aller plus loin.

## Étape 3 — LE pattern : basculer à distance sans se couper l'accès

Le piège : **la sortie Internet passe par cette clé**, et si tu travailles à distance (SSH
ou VPN), ton accès dépend de cette même sortie. Changer le pilote, c'est risquer de scier la
branche sur laquelle on est assis, sur une machine qu'on n'a pas sous la main. *(Si tu es en
local, écran et clavier branchés, saute le 3b : tu pourras toujours corriger à la main.)*

Deux garde-fous, dans cet ordre.

### 3a. Accrocher les profils réseau à la MAC, pas au nom d'interface

Un nouveau pilote peut **renommer** l'interface (`wlan1` → `wlan0` ou `wlx<mac>`). Si ton
profil est accroché au *nom*, il ne se reconnecte pas. Accroche-le à l'**adresse MAC**, qui
ne change jamais :

```bash
ip link show                 # lire la MAC de chaque interface
sudo nmcli connection modify <PROFIL-SORTIE> \
  802-11-wireless.mac-address <MAC-CLE-USB> \
  connection.interface-name ""
```

**La notion** : identifier le matériel par ce qui lui est propre (la MAC), jamais par une
étiquette que le système peut réattribuer (le nom).

### 3b. Un filet de rollback automatique et temporisé

Si après le reboot il n'y a plus d'Internet, la machine doit **se réparer seule**. Script :

```bash
sudo tee /usr/local/sbin/driver-rollback.sh >/dev/null <<'SH'
#!/bin/bash
if ping -c3 -W2 1.1.1.1 >/dev/null 2>&1; then
    logger -t rollback "Internet OK, rien a faire"; exit 0
fi
logger -t rollback "Pas d'Internet -> retour a l'ancien pilote"
rm -f /etc/modprobe.d/blacklist-rtl8xxxu.conf
echo 'blacklist 8188eu' > /etc/modprobe.d/blacklist-8188eu.conf
systemctl disable driver-rollback.timer
/sbin/reboot
SH
sudo chmod +x /usr/local/sbin/driver-rollback.sh
```

Déclenché **5 minutes après le boot** par un timer systemd :

```bash
sudo tee /etc/systemd/system/driver-rollback.service >/dev/null <<'SVC'
[Unit]
Description=Rollback pilote Wi-Fi si pas d'Internet
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/driver-rollback.sh
SVC
sudo tee /etc/systemd/system/driver-rollback.timer >/dev/null <<'TMR'
[Unit]
Description=Verifie Internet 5 min apres boot
[Timer]
OnBootSec=5min
Unit=driver-rollback.service
[Install]
WantedBy=timers.target
TMR
sudo systemctl daemon-reload
sudo systemctl enable driver-rollback.timer
```

**La notion** : toute commande qui touche à ton propre chemin d'accès (réseau, pilote,
pare-feu, SSH) sur une machine distante doit avoir un rollback **automatique et temporisé**.
C'est le réflexe qui distingue un admin d'un bricoleur.

### 3c. Armer la bascule, puis redémarrer

```bash
echo 'blacklist rtl8xxxu' | sudo tee /etc/modprobe.d/blacklist-rtl8xxxu.conf
sudo reboot
```

Au boot : `rtl8xxxu` est bloqué → le noyau charge `8188eu` → l'interface revient → le profil
se reconnecte par sa MAC. Si Internet manque, le filet rebascule tout seul au bout de 5 min.

## Étape 4 — après la bascule : gérer la permutation des noms

Ici le nouveau pilote a **échangé les noms** : la clé USB est devenue `wlan0` et le Wi-Fi
intégré `wlan1`. Grâce au 3a, la sortie s'est reconnectée seule. Mais le **point d'accès**,
lui, était resté accroché à l'ancien nom et n'est pas remonté. Correctif : l'accrocher à la
MAC de la puce interne.

```bash
# retrouver le nom/pilote/MAC de chaque interface Wi-Fi
for i in /sys/class/net/wlan*; do
  echo "$(basename $i) driver=$(basename $(readlink $i/device/driver)) mac=$(cat $i/address)"
done

sudo nmcli connection modify <PROFIL-AP> \
  802-11-wireless.mac-address <MAC-WIFI-INTEGRE> \
  connection.interface-name ""
sudo nmcli connection up <PROFIL-AP>
```

Vérifier que l'AP est bien remonté, avec son DHCP et son DNS :

```bash
nmcli -t -f DEVICE,STATE,CONNECTION device status | grep -i <PROFIL-AP>
sudo ss -lunp | grep ':67 '     # DHCP (dnsmasq) à l'écoute
sudo ss -lunp | grep ':53 '     # DNS relayé vers AdGuard
```

## Étape 5 — passer le point d'accès en 5 GHz

**La notion** : le débit Wi-Fi dépend surtout de la **largeur de canal**, pas de la bande.
20 MHz ≈ 72 Mbit/s, 40 MHz ≈ 150, 80 MHz ≈ 400. La bande 5 GHz est moins encombrée que la
2,4 GHz et autorise des canaux larges.

Vérifier d'abord ce que la puce sait faire (et quels canaux sont permis) :

```bash
iw reg get                                  # domaine réglementaire (ton pays)
PHY=$(cat /sys/class/net/<IF-AP>/phy80211/name)
iw phy $PHY info | grep -A8 'interface modes' | grep AP    # mode AP supporté ?
iw phy $PHY info | grep -iE '5[0-9]{3} MHz'                # canaux 5 GHz
```

Les canaux **36, 40, 44, 48** sont utilisables sans contrainte. Les canaux 52+ sont « DFS »
(détection radar) : à éviter pour un AP, ils retardent ou empêchent le démarrage.

```bash
sudo nmcli connection modify <PROFIL-AP> 802-11-wireless.band a 802-11-wireless.channel 36
sudo nmcli connection up <PROFIL-AP>
iw dev <IF-AP> info | grep -iE 'channel|width'
```

**Limite rencontrée** : le mode AP intégré de NetworkManager plafonne à **20 MHz**. Pour le
40/80 MHz, il faut remplacer cet AP par **hostapd** (qui expose `ht_capab` et le VHT). À
faire quand le WAN passera en Ethernet — tant que la sortie plafonne à 72 Mbit/s, élargir
l'AP ne profite qu'au trafic local.

## Nettoyage — retirer le filet

Une fois la sortie **et** l'AP confirmés, on retire le rollback (sinon une coupure passagère
à un futur reboot pourrait rebasculer par erreur) :

```bash
sudo systemctl disable --now driver-rollback.timer
sudo rm /etc/systemd/system/driver-rollback.{service,timer} /usr/local/sbin/driver-rollback.sh
sudo rm -f /etc/modprobe.d/blacklist-8188eu.conf
sudo systemctl daemon-reload
# on garde /etc/modprobe.d/blacklist-rtl8xxxu.conf : c'est lui qui maintient le bon pilote
```

## Résultats

| Mesure | Avant | Après |
|---|---|---|
| Pilote de la clé | `rtl8xxxu` | `8188eu` (DKMS) |
| Débit négocié de la sortie | 1,3 Mbit/s | 72,2 Mbit/s |
| Signal de la sortie | — | −54 dBm |
| Économie d'énergie Wi-Fi | ? | désactivée |
| Sous-tension | détectée | aucune |
| Bande du point d'accès | 2,4 GHz canal 1 | 5 GHz canal 36 |
| Profils réseau | accrochés au nom | accrochés à la MAC |

**Gain : ×55 sur le débit de la sortie Internet.**

## Ce qu'on a appris

1. Un débit Wi-Fi catastrophique vient souvent du **pilote**, pas du matériel.
2. **DKMS** compile et maintient un module hors-noyau à travers les mises à jour.
3. Accrocher les profils réseau à la **MAC** les rend immunisés au renommage d'interface.
4. Une bascule risquée à distance se fait **avec un rollback automatique et temporisé** —
   jamais à nu.
5. Le débit Wi-Fi tient surtout à la **largeur de canal** ; NetworkManager plafonne à
   20 MHz, hostapd débloque le reste.

## Limites et suite

- La sortie Internet reste plafonnée par la clé USB (2,4 GHz, 1 antenne, ~72 Mbit/s). Pour
  un vrai saut : **WAN sur Ethernet** ou clé USB 5 GHz (type MT7612U).
- Domaine réglementaire à régler sur le bon pays (prudence : selon la base, changer de pays
  peut retirer l'accès au 5 GHz).
- Point d'accès à passer sous **hostapd** pour le 40/80 MHz, une fois le WAN rapide en place.

## Sources

- Pilote RTL8188EUS (aircrack-ng) : <https://github.com/aircrack-ng/rtl8188eus>
- DKMS, principe et usage (Debian) : <https://wiki.debian.org/KernelDKMS> — projet : <https://github.com/dell/dkms>
- `nmcli` et propriétés de connexion NetworkManager : <https://networkmanager.dev/docs/api/latest/nmcli.html> (voir aussi `man nm-settings`)
- Minuteries systemd (`OnBootSec`) : <https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html>
- Raspberry Pi — `vcgencmd get_throttled` et alimentation : <https://www.raspberrypi.com/documentation/computers/os.html#get_throttled>
- Alimentation officielle Pi 5 (5 V/5 A) : <https://www.raspberrypi.com/products/27w-power-supply/>
- Domaine réglementaire Wi-Fi (Linux wireless) : <https://wireless.wiki.kernel.org/en/developers/regulatory>
- `iw`, canaux et largeur de canal : <https://wireless.wiki.kernel.org/en/users/documentation/iw>
- Canaux 5 GHz et DFS (liste) : <https://en.wikipedia.org/wiki/List_of_WLAN_channels#5_GHz_(802.11a/h/n/ac/ax)>
- `hostapd` (point d'accès, HT/VHT) : <https://w1.fi/hostapd/> — wiki Arch : <https://wiki.archlinux.org/title/Software_access_point>
