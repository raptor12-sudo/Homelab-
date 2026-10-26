# Tutoriel 01 : un Raspberry Pi comme DNS filtrant et routeur de son propre réseau

Ce tutoriel reprend, étape par étape, ce qui a été réellement installé et vérifié le 2026-10-26 sur le Pi du homelab. Les erreurs rencontrées en cours de route sont dans la section [Dépannage](#9-dépannage-les-erreurs-rencontrées), avec leur solution.

**À la fin, tu auras :**

- **AdGuard Home**, qui bloque les publicités et les pisteurs pour tous les appareils qui l'utilisent ;
- **un réseau homelab séparé** (`10.0.10.0/24`), distinct du réseau de la box, dont le Pi est le routeur ;
- des **mises à jour de sécurité automatiques** et une **sauvegarde** de la configuration.

```
Internet
   │
  Box ~~~ Wi-Fi ~~~ wlan0 (192.168.1.81)
                       │
                 [Raspberry Pi]   AdGuard Home + DHCP + NAT
                       │
                     eth0 (10.0.10.1)
                       │ câble
                  ton ordinateur (10.0.10.x)
```

---

## Sommaire

0. [Prérequis](#0-prérequis)
1. [Faire l'état des lieux](#1-faire-létat-des-lieux)
2. [Stabiliser le Wi-Fi](#2-stabiliser-le-wi-fi)
3. [Installer AdGuard Home avec Docker](#3-installer-adguard-home-avec-docker)
4. [Configurer AdGuard Home](#4-configurer-adguard-home)
5. [Figer la version](#5-figer-la-version-et-fermer-lassistant)
6. [Créer le réseau homelab](#6-créer-le-réseau-homelab)
7. [Brancher un poste et tester](#7-brancher-un-poste-et-tester)
8. [Mises à jour et sauvegarde](#8-mises-à-jour-et-sauvegarde)
9. [Dépannage](#9-dépannage-les-erreurs-rencontrées)
10. [Utiliser AdGuard sur iPhone et iPad](#10-utiliser-adguard-sur-iphone-et-ipad)
11. [Tout annuler](#11-tout-annuler)

---

## 0. Prérequis

| Élément | Utilisé ici |
|---|---|
| Raspberry Pi | Pi 5, 8 Go de RAM (un Pi 4 avec 2 Go suffit) |
| Système | Raspberry Pi OS 64 bits (Bookworm), avec NetworkManager |
| Docker | Déjà installé, avec le plugin `docker compose` |
| Connexion du Pi à Internet | Wi-Fi de la box |
| Pour le réseau homelab | Un câble Ethernet, et un adaptateur USB-Ethernet si l'ordinateur n'a pas de port |
| Accès | SSH vers le Pi depuis l'ordinateur |

> **Bon à savoir** : sur ce homelab, le Pi est **partagé** avec un autre projet (SaytuMbaye : InfluxDB, Grafana, MQTT). Tout le tutoriel veille à ne pas le perturber, ce qui explique certains choix de ports.

---

## 1. Faire l'état des lieux

**Pourquoi** : avant d'installer quoi que ce soit, on vérifie ce qui tourne déjà, pour éviter les conflits de ports. Un DNS a besoin du port **53**, et AdGuard utilise le **3000** pour son assistant d'installation.

Sur le Pi :

```bash
docker ps --format '{{.Names}} {{.Image}} {{.Ports}}'
sudo ss -tulpn | grep -E ':(53|80|443|3000) '
nmcli -f SIGNAL,SSID device wifi | head -3
```

| Commande | Ce qu'elle montre |
|---|---|
| `docker ps` | Les conteneurs en service et leurs ports |
| `ss -tulpn` | Les programmes qui écoutent sur les ports 53, 80, 443 et 3000 |
| `nmcli ... wifi` | La force du signal Wi-Fi, de 0 à 100 |

**Ce qu'on a trouvé** : les ports 53 et 80 sont libres, le **3000 est pris par Grafana** et le signal Wi-Fi est moyen (47/100). On adapte la suite en conséquence.

---

## 2. Stabiliser le Wi-Fi

**Pourquoi** : par défaut, le Wi-Fi du Pi se met en **économie d'énergie** et s'endort par moments. Pour un DNS, c'est grave : si le Pi décroche, les appareils qui l'utilisent ne trouvent plus aucun site. On a constaté ces coupures (100 % de perte au ping).

```bash
sudo nmcli connection modify "<nom-de-ta-connexion-wifi>" 802-11-wireless.powersave 2
```

- `2` signifie « économie d'énergie **désactivée** ».
- Contrairement à `iw dev wlan0 set power_save off`, ce réglage est **enregistré** et survit au redémarrage.
- Pour trouver le nom de la connexion : `nmcli connection show --active`.

---

## 3. Installer AdGuard Home avec Docker

**Pourquoi Docker** : Docker est déjà présent. Le conteneur isole AdGuard du système et des autres projets, et on le supprime proprement si besoin.

### 3.1 Créer un dossier dédié

```bash
mkdir -p ~/adguard && cd ~/adguard
```

AdGuard a son propre dossier, séparé des autres projets : un projet = un dossier = un fichier `compose.yaml`.

### 3.2 Écrire le fichier `compose.yaml`

```bash
cat > compose.yaml <<'EOF'
services:
  adguardhome:
    image: adguard/adguardhome:latest
    container_name: adguardhome
    restart: unless-stopped
    volumes:
      - ./work:/opt/adguardhome/work
      - ./conf:/opt/adguardhome/conf
    ports:
      - "192.168.1.81:53:53/udp"
      - "192.168.1.81:53:53/tcp"
      - "192.168.1.81:3001:3000/tcp"
      - "192.168.1.81:8080:80/tcp"
EOF
```

**Ligne par ligne :**

| Ligne | Rôle |
|---|---|
| `restart: unless-stopped` | AdGuard redémarre tout seul après une panne ou un redémarrage du Pi |
| `./work` et `./conf` | Les données et la configuration sont stockées **hors du conteneur**, donc conservées si on le recrée |
| `53/udp` et `53/tcp` | Le DNS. L'UDP sert aux requêtes normales, le TCP aux grosses réponses |
| `3001:3000` | L'assistant d'installation. Le port 3000 de l'hôte est déjà pris par Grafana, donc on publie sur le **3001** |
| `8080:80` | L'interface web après l'installation. Le port 80 de l'hôte reste libre pour plus tard |

> **Le point de sécurité le plus important** : chaque port commence par `192.168.1.81:`. Sans ce préfixe, Docker publierait le port sur **toutes** les adresses du Pi, y compris son **IPv6 publique**. Le DNS serait alors joignable depuis Internet et pourrait servir à des attaques par amplification. Avec ce préfixe, AdGuard n'écoute que sur le réseau local.
>
> Remplace `192.168.1.81` par l'adresse locale de ton Pi (`hostname -I`).

### 3.3 Démarrer

```bash
docker compose up -d
docker compose ps
```

Le conteneur `adguardhome` doit être à l'état `Up`.

---

## 4. Configurer AdGuard Home

1. Depuis un ordinateur du réseau, ouvre **`http://192.168.1.81:3001`**.
2. **Interfaces d'écoute** : garde le port **80** pour l'interface web et le port **53** pour le DNS. Ce sont les ports **à l'intérieur** du conteneur, que Docker publie sur 8080 et 53.
3. **Compte administrateur** : un mot de passe fort, rangé dans un gestionnaire de mots de passe.
4. Une fois l'assistant terminé, l'interface se trouve sur **`http://192.168.1.81:8080`**.

**Réglages retenus :**

| Réglage | Valeur | Pourquoi |
|---|---|---|
| DNS en amont | `https://dns10.quad9.net/dns-query` | **DNS-over-HTTPS** : les requêtes vers l'extérieur sont chiffrées, donc ton fournisseur d'accès ne voit plus les sites visités |
| DNSSEC | activé | Vérifie que les réponses DNS n'ont pas été falsifiées |
| Liste de blocage | AdGuard DNS filter | Environ 184 000 domaines de publicité et de pistage |

### Vérifier

Depuis l'ordinateur :

```bash
dig +short @192.168.1.81 example.com       # doit répondre une adresse IP
dig +short @192.168.1.81 doubleclick.net   # doit répondre 0.0.0.0 (bloqué)
```

---

## 5. Figer la version et fermer l'assistant

**Pourquoi** : avec `latest`, une nouvelle version peut s'installer sans que tu l'aies décidé, au premier redémarrage qui retélécharge l'image. On fige donc la version en service. Quant au port 3001, il ne sert plus : on le retire.

```bash
docker exec adguardhome /opt/adguardhome/AdGuardHome --version   # ici : v0.107.79
cd ~/adguard
sed -i -e 's|adguardhome:latest|adguardhome:v0.107.79|' -e '/3001:3000/d' compose.yaml
docker compose up -d
```

AdGuard redémarre en environ 5 secondes. Les réglages sont conservés dans `conf/`.

Pour mettre à jour plus tard, change la version dans `compose.yaml` après avoir lu les notes de version, puis relance `docker compose up -d`.

---

## 6. Créer le réseau homelab

**Le but** : avoir **son propre réseau**, séparé de la box. On y gère soi-même les adresses, le DNS et le pare-feu, et les appareils de la maison ne le voient pas.

**Le principe** : le Pi sert de **routeur**. Il reçoit Internet par le Wi-Fi (`wlan0`) et le redistribue sur son port Ethernet (`eth0`).

NetworkManager a un mode **`shared`** qui fait tout le travail en une commande :

- il donne une adresse fixe à `eth0` (`10.0.10.1`) ;
- il lance un **serveur DHCP** (dnsmasq), qui distribue des adresses `10.0.10.x` ;
- il active le **NAT** : les appareils du réseau sortent sur Internet avec l'adresse du Pi.

### 6.1 Envoyer le DNS du réseau vers AdGuard

Par défaut, le dnsmasq du mode `shared` répond lui-même aux requêtes DNS, en passant par la box. On lui demande plutôt de tout transmettre à AdGuard :

```bash
echo -e "# DNS du LAN homelab : tout passe par AdGuard\nno-resolv\nserver=192.168.1.81" \
  | sudo tee /etc/NetworkManager/dnsmasq-shared.d/adguard.conf
```

- `no-resolv` : ignorer les DNS habituels du Pi.
- `server=192.168.1.81` : tout envoyer à AdGuard.

Fichier de référence : [`pi/lan/adguard.conf`](../../pi/lan/adguard.conf).

### 6.2 Débloquer le routage malgré Docker

**Le piège** : Docker règle le pare-feu du Pi pour **bloquer tout trafic qui traverse la machine** (`iptables -P FORWARD DROP`). C'est fait pour protéger les conteneurs, mais ça bloque aussi le routage de notre réseau.

On le vérifie avec :

```bash
sudo iptables -S FORWARD | head -3
# -P FORWARD DROP          ← tout est bloqué par défaut
# -A FORWARD -j DOCKER-USER
```

Docker prévoit une chaîne **`DOCKER-USER`**, lue en premier et réservée à nos propres règles. On y autorise deux choses :

1. ce qui va du réseau homelab (`eth0`) vers Internet (`wlan0`) ;
2. les réponses qui reviennent (`RELATED,ESTABLISHED`), et seulement elles. Internet ne peut pas ouvrir de connexion vers le réseau homelab.

Ces règles disparaissent au redémarrage. On les place donc dans un script **dispatcher** de NetworkManager, qui s'exécute chaque fois que `eth0` monte :

```bash
sudo tee /etc/NetworkManager/dispatcher.d/90-homelab-forward <<'EOF'
#!/bin/sh
# Autorise le LAN homelab (eth0) à sortir par le Wi-Fi (wlan0) malgré la politique DROP de Docker.
[ "$1" = eth0 ] && [ "$2" = up ] || exit 0
iptables -C DOCKER-USER -i eth0 -o wlan0 -j ACCEPT 2>/dev/null || iptables -I DOCKER-USER -i eth0 -o wlan0 -j ACCEPT
iptables -C DOCKER-USER -i wlan0 -o eth0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || iptables -I DOCKER-USER -i wlan0 -o eth0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
EOF
sudo chmod 755 /etc/NetworkManager/dispatcher.d/90-homelab-forward
```

- `iptables -C` vérifie si la règle existe déjà. Elle n'est ajoutée (`-I`) que si elle manque, ce qui évite les doublons.
- Le `chmod 755` est obligatoire : NetworkManager ignore les scripts non exécutables.

Fichier de référence : [`pi/lan/90-homelab-forward`](../../pi/lan/90-homelab-forward).

### 6.3 Créer le réseau

```bash
sudo nmcli connection add type ethernet ifname eth0 con-name homelab-lan \
  ipv4.method shared ipv4.addresses 10.0.10.1/24 ipv6.method disabled
```

| Option | Rôle |
|---|---|
| `con-name homelab-lan` | Le nom de la connexion, pour la retrouver |
| `ipv4.method shared` | Active le mode routeur : DHCP et NAT |
| `ipv4.addresses 10.0.10.1/24` | Le Pi prend `10.0.10.1`, et le réseau va de `10.0.10.1` à `10.0.10.254` |
| `ipv6.method disabled` | Réseau en IPv4 uniquement, plus simple à maîtriser pour commencer |

Pourquoi `10.0.10.0/24` : cette plage ne peut pas entrer en conflit avec la box (`192.168.1.x`). Elle reste **provisoire** jusqu'au plan d'adressage définitif.

> La connexion ne démarre **que lorsqu'un câble est branché** sur `eth0`.

---

## 7. Brancher un poste et tester

1. Relie l'ordinateur au port Ethernet du Pi, avec l'adaptateur USB-Ethernet si besoin.
2. Attends une dizaine de secondes : l'ordinateur demande une adresse au Pi.

Depuis l'ordinateur (exemple sur macOS) :

```bash
ipconfig getifaddr en8                 # adresse reçue : doit être en 10.0.10.x (en8 = l'adaptateur)
ping -c2 10.0.10.1                      # le Pi répond
dig +short @10.0.10.1 doubleclick.net   # 0.0.0.0 : le DNS passe bien par AdGuard
traceroute -n 1.1.1.1                   # le chemin vers Internet
```

**Résultat obtenu :**

```
1  10.0.10.1      ← le Pi (routeur)
2  192.168.1.1    ← la box
3  192.0.0.1      ← l'opérateur (indice de DS-Lite, voir ADR 0003)
...
```

L'ordinateur a reçu `10.0.10.137`, il sort sur Internet par le Pi, et les publicités sont bloquées. ✅

---

## 8. Mises à jour et sauvegarde

### 8.1 Mises à jour de sécurité automatiques

**Pourquoi** : le Pi tourne en permanence. Il doit recevoir les correctifs sans que tu y penses.

```bash
sudo apt-get update
sudo apt-get install -y unattended-upgrades
sudo dpkg-reconfigure -f noninteractive unattended-upgrades
cat /etc/apt/apt.conf.d/20auto-upgrades
```

Les deux lignes affichées doivent finir par `"1";`.

Par défaut, seuls les **correctifs de sécurité de Debian** sont appliqués. Docker n'est pas mis à jour automatiquement, donc les conteneurs ne redémarrent pas à l'improviste.

### 8.2 Sauvegarder la configuration d'AdGuard

**Pourquoi** : les cartes microSD lâchent souvent. Une copie sur la même carte ne sert à rien, on la met donc dans le dépôt Git.

**Le danger** : la configuration contient les mots de passe hachés, dans la section `users:`. On la retire avant toute copie.

Sur le Pi :

```bash
sudo awk '/^users:/{s=1;next} /^[^ \t#]/{s=0} !s' ~/adguard/conf/AdGuardHome.yaml \
  > ~/adguard/AdGuardHome.yaml.sanitized
grep -n -iE 'password|private_key' ~/adguard/AdGuardHome.yaml.sanitized
```

Le `awk` saute la ligne `users:` et toutes les lignes indentées qui suivent, jusqu'à la clé suivante. Le `grep` contrôle le résultat : il ne doit rester que des champs **vides** (`private_key: ""`).

Puis, sur l'ordinateur, dans un terminal local et pas dans celui du Pi :

```bash
scp <utilisateur>@192.168.1.81:adguard/AdGuardHome.yaml.sanitized ~/Developer/homelab/pi/adguard/
```

Relis le fichier en entier avant de le committer. Le script [`pi/adguard/export-config.sh`](../../pi/adguard/export-config.sh) fait la même chose.

---

## 9. Dépannage : les erreurs rencontrées

### Le Wi-Fi du Pi coupe, SSH n'arrive pas à se connecter

- **Symptôme** : le ping passe parfois avec beaucoup de latence, puis 100 % de perte.
- **Cause** : l'économie d'énergie du Wi-Fi.
- **Solution** : l'[étape 2](#2-stabiliser-le-wi-fi).

### L'assistant d'AdGuard ne répond pas sur le port 3000

- **Cause** : Grafana occupe déjà le port 3000.
- **Solution** : publier l'assistant sur un autre port (`3001:3000`).

### Le port 3001 ne répond plus

- **Ce n'est pas une panne.** L'assistant s'arrête une fois l'installation terminée, et l'interface passe sur le port 80 du conteneur, publié sur le 8080 de l'hôte.

### `homelab-lan` est créé mais ne démarre pas

```
eth0  ethernet  disconnected  --
eth0  UP  169.254.250.6/32
... (eth0): state change ... managed-type: 'external'
```

- **Cause** : une adresse ajoutée **à la main** auparavant (`ip addr add ...`) était restée sur `eth0`. NetworkManager en a conclu que l'interface était gérée par quelqu'un d'autre (`external`), et il n'y touche plus.
- **Solution** :

  ```bash
  sudo ip addr del 169.254.250.6/32 dev eth0
  sudo nmcli connection up homelab-lan
  ```

### L'ordinateur reste en `169.254.x.x` au lieu de `10.0.10.x`

- **Cause** : il a demandé une adresse **avant** que le réseau du Pi soit prêt. Sans réponse, il s'est donné une adresse de secours, et il ne redemande que de temps en temps.
- **Solution** : débrancher le câble, attendre 3 secondes, le rebrancher.

### Le réseau homelab n'a plus Internet après un redémarrage du Pi

- **Cause possible** : le script dispatcher s'est exécuté avant que Docker ait créé la chaîne `DOCKER-USER`.
- **Solution** : débrancher puis rebrancher le câble, ce qui relance le script.
- **Vérification** : `sudo iptables -S DOCKER-USER` doit afficher les deux règles `eth0`/`wlan0`.

---

## 10. Utiliser AdGuard sur iPhone et iPad

Un iPhone n'a pas de port Ethernet : il ne peut pas rejoindre le réseau homelab sans point d'accès Wi-Fi. En attendant, il peut quand même **utiliser AdGuard** depuis le Wi-Fi de la box :

1. **Réglages → Wi-Fi →** touche **ⓘ** à côté du réseau.
2. **Configurer le DNS → Manuel**.
3. Supprime les serveurs existants, puis **Ajouter un serveur → `192.168.1.81`**.
4. **Enregistrer**.

Pour vérifier, regarde dans AdGuard, **Journal des requêtes** : les requêtes de l'iPhone y apparaissent.

> **Limite : les publicités YouTube passent quand même.** Un filtrage DNS ne voit que des noms de domaine. Or YouTube envoie ses publicités depuis les **mêmes** domaines que ses vidéos (`googlevideo.com`) : les bloquer couperait aussi les vidéos. Les bloqueurs intégrés au navigateur, comme Brave, y arrivent parce qu'ils voient **l'intérieur de la page** déchiffrée. Pour YouTube, utilise donc un navigateur bloqueur. Le détail est dans l'[ADR 0003](../decisions/0003-acces-distant.md).
>
> Si le Pi s'éteint, l'iPhone n'a plus de DNS sur ce Wi-Fi. Il suffit alors de remettre **Automatique**.

---

## 11. Tout annuler

```bash
# Réseau homelab
sudo nmcli connection delete homelab-lan
sudo rm /etc/NetworkManager/dnsmasq-shared.d/adguard.conf
sudo rm /etc/NetworkManager/dispatcher.d/90-homelab-forward

# AdGuard Home
cd ~/adguard && docker compose down
# (optionnel) supprimer aussi la configuration : rm -rf ~/adguard
```

Les mises à jour automatiques peuvent rester : elles ne gênent rien.

---

## Et ensuite ?

- Tester un redémarrage complet du Pi, puis faire la mise à jour complète du système.
- Donner des noms locaux aux machines dans AdGuard (**Filtres → Réécritures DNS**).
- Installer Proxmox sur le HP, avec pfSense en VM : il reprendra le rôle de routeur, et le Pi redeviendra uniquement le DNS.
- Mettre en place l'accès distant par WireGuard ([ADR 0003](../decisions/0003-acces-distant.md)).
