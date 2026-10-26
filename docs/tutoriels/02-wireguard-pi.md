# Tutoriel 02 : WireGuard sur le Raspberry Pi

> **Statut : procédure préparée, pas encore exécutée.** Contrairement au [tutoriel 01](01-pi-adguard-reseau-homelab.md), rien de ce qui suit n'a encore été installé ni testé sur le Pi. Les valeurs marquées *(proposition)* restent à valider. Ce tutoriel sera corrigé avec les résultats réels au moment de l'installation.

**À la fin, tu auras :**

- un serveur **WireGuard** sur le Pi ;
- l'iPhone, l'iPad et le Mac capables de rejoindre le homelab à travers un tunnel chiffré ;
- le **filtrage AdGuard** sur ces appareils, même hors de chez toi, une fois le Pi joignable depuis l'extérieur (voir l'[étape 9](#9-rendre-le-pi-joignable-depuis-lextérieur)).

```
iPhone / iPad / Mac  (10.0.20.x)
        │  tunnel WireGuard chiffré (UDP 51820)
        ▼
  [Raspberry Pi]  wg0 = 10.0.20.1
        ├── AdGuard Home (192.168.1.81:53)   ← DNS des clients du tunnel
        └── LAN homelab (10.0.10.0/24)       ← machines du lab
```

---

## Sommaire

1. [Comprendre WireGuard en 2 minutes](#1-comprendre-wireguard-en-2-minutes)
2. [Choisir les valeurs](#2-choisir-les-valeurs)
3. [Installer WireGuard](#3-installer-wireguard)
4. [Générer les clés](#4-générer-les-clés)
5. [Configurer le serveur](#5-configurer-le-serveur-etcwireguardwg0conf)
6. [Démarrer le tunnel](#6-démarrer-le-tunnel)
7. [Configurer l'iPhone et l'iPad](#7-configurer-liphone-et-lipad)
8. [Tester à la maison](#8-tester-à-la-maison)
9. [Rendre le Pi joignable depuis l'extérieur](#9-rendre-le-pi-joignable-depuis-lextérieur)
10. [Ajouter ou retirer un appareil](#10-ajouter-ou-retirer-un-appareil)
11. [Dépannage](#11-dépannage)
12. [Tout annuler](#12-tout-annuler)

---

## 1. Comprendre WireGuard en 2 minutes

WireGuard crée un **réseau privé virtuel**. Chaque appareil reçoit une adresse dans le tunnel (`10.0.20.x`), et tout ce qui passe dedans est chiffré.

| Notion | Explication |
|---|---|
| **Paire de clés** | Chaque appareil a une **clé privée**, secrète et qui ne quitte jamais l'appareil, et une **clé publique**, qu'on donne aux autres. C'est le principe de SSH |
| **Pair (peer)** | Un appareil autorisé à se connecter. Le serveur connaît la clé publique de chaque pair, et chaque pair connaît celle du serveur |
| **`AllowedIPs`** | Côté serveur, les adresses que ce pair a le droit d'utiliser. Côté client, **ce qu'on envoie dans le tunnel** |
| **Endpoint** | L'adresse et le port où joindre le serveur |
| **Silencieux** | WireGuard **ne répond pas** aux paquets qui ne sont pas signés par une clé connue. Un scan de port ne le détecte même pas |

**Tunnel partiel** *(choix retenu)* : seuls le DNS et le homelab passent par le tunnel. Netflix, YouTube et le reste sortent directement par la 4G. C'est plus rapide, et la connexion lente du Pi en Wi-Fi n'est pas surchargée.

---

## 2. Choisir les valeurs

| Valeur | Proposition | Pourquoi |
|---|---|---|
| Sous-réseau du tunnel | `10.0.20.0/24` *(proposition)* | Ne chevauche ni la box (`192.168.1.x`) ni le LAN homelab (`10.0.10.x`) |
| Adresse du Pi dans le tunnel | `10.0.20.1` | |
| Port UDP | `51820` *(proposition)* | Le port par défaut de WireGuard |
| iPhone / iPad / Mac | `10.0.20.2` / `.3` / `.4` | Une adresse fixe par appareil |
| DNS des clients | `192.168.1.81` | L'adresse où AdGuard écoute déjà : rien à changer dans `compose.yaml` |

> **Pourquoi ne pas faire écouter AdGuard sur `10.0.20.1` ?** Docker refuse de démarrer un conteneur si l'adresse n'existe pas encore. Si `wg0` monte après Docker au démarrage du Pi, **AdGuard ne démarrerait pas du tout**, et tout le réseau perdrait son DNS. En visant `192.168.1.81`, le DNS passe par le tunnel puis est redirigé vers le conteneur comme n'importe quelle requête : aucun risque.

---

## 3. Installer WireGuard

Sur le Pi :

```bash
sudo apt-get update
sudo apt-get install -y wireguard-tools qrencode
```

- `wireguard-tools` fournit les commandes `wg` et `wg-quick`. Le module WireGuard lui-même est **déjà dans le noyau** de Raspberry Pi OS.
- `qrencode` affiche la configuration de l'iPhone sous forme de **QR code** : pas de clé à recopier à la main.

Vérification :

```bash
wg --version
```

---

## 4. Générer les clés

```bash
sudo -i                       # passer en root pour la suite de cette étape
cd /etc/wireguard
umask 077                     # tous les fichiers créés ici seront lisibles par root seulement

wg genkey | tee serveur.key | wg pubkey > serveur.pub
wg genkey | tee iphone.key  | wg pubkey > iphone.pub
wg genkey | tee ipad.key    | wg pubkey > ipad.pub
wg genkey | tee mac.key     | wg pubkey > mac.pub

ls -l                         # toutes les lignes doivent commencer par -rw-------
exit
```

- `wg genkey` crée une clé privée, et `wg pubkey` en déduit la clé publique.
- `umask 077` est essentiel : sans lui, n'importe quel utilisateur du Pi pourrait lire les clés privées.

> 🔒 **Ces fichiers ne vont JAMAIS dans Git.** Les clés des clients sont générées sur le Pi pour pouvoir afficher le QR code. Une fois les appareils configurés, supprime `iphone.key`, `ipad.key` et `mac.key` du Pi : le serveur n'a besoin que de leurs clés **publiques**.

---

## 5. Configurer le serveur (`/etc/wireguard/wg0.conf`)

```bash
sudo nano /etc/wireguard/wg0.conf
```

```ini
# Serveur WireGuard du homelab : accès au LAN homelab et à AdGuard pour les appareils nomades.
[Interface]
Address    = 10.0.20.1/24
ListenPort = 51820
PrivateKey = <contenu de serveur.key>

# Docker bloque le trafic qui traverse le Pi (FORWARD DROP) : on autorise le tunnel vers le LAN homelab.
PostUp   = iptables -I DOCKER-USER -i wg0 -o eth0 -j ACCEPT; iptables -I DOCKER-USER -i eth0 -o wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
PostDown = iptables -D DOCKER-USER -i wg0 -o eth0 -j ACCEPT; iptables -D DOCKER-USER -i eth0 -o wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

[Peer]
# iPhone
PublicKey  = <contenu de iphone.pub>
AllowedIPs = 10.0.20.2/32

[Peer]
# iPad
PublicKey  = <contenu de ipad.pub>
AllowedIPs = 10.0.20.3/32

[Peer]
# Mac
PublicKey  = <contenu de mac.pub>
AllowedIPs = 10.0.20.4/32
```

Pour afficher une clé à copier : `sudo cat /etc/wireguard/serveur.key`.

**Ligne par ligne :**

| Ligne | Rôle |
|---|---|
| `Address` | L'adresse du Pi dans le tunnel |
| `ListenPort` | Le port UDP sur lequel le Pi attend les connexions |
| `PostUp` / `PostDown` | Les règles de pare-feu, ajoutées au démarrage du tunnel et retirées à l'arrêt. Même problème Docker que dans le tutoriel 01, étape 6.2 |
| `AllowedIPs = 10.0.20.2/32` | L'iPhone n'a le droit d'utiliser **que** son adresse : il ne peut pas se faire passer pour un autre appareil |

**Le DNS (`192.168.1.81`) n'a pas besoin de règle supplémentaire** : Docker autorise déjà l'accès aux ports qu'il publie, quelle que soit l'interface d'arrivée.

### Démarrer après Docker

Les règles `PostUp` écrivent dans la chaîne `DOCKER-USER`, que Docker crée à son démarrage. Il faut donc que WireGuard démarre **après** Docker :

```bash
sudo systemctl edit wg-quick@wg0
```

Ajoute ces lignes dans la zone indiquée, puis enregistre :

```ini
[Unit]
After=docker.service
Wants=docker.service
```

---

## 6. Démarrer le tunnel

```bash
sudo systemctl enable --now wg-quick@wg0
sudo wg show
```

- `enable` : démarrage automatique à chaque redémarrage du Pi.
- `--now` : démarrage immédiat.

`wg show` doit afficher `interface: wg0`, le port `51820` et les trois pairs. Tant qu'aucun appareil ne s'est connecté, il n'y a pas encore de ligne `latest handshake`.

---

## 7. Configurer l'iPhone et l'iPad

### 7.1 Écrire la configuration du client

Sur le Pi, en root, un fichier par appareil. Exemple pour l'iPhone :

```bash
sudo -i
cd /etc/wireguard
cat > iphone.conf <<EOF
[Interface]
PrivateKey = $(cat iphone.key)
Address    = 10.0.20.2/32
DNS        = 192.168.1.81

[Peer]
PublicKey           = $(cat serveur.pub)
Endpoint            = 192.168.1.81:51820
AllowedIPs          = 10.0.20.0/24, 10.0.10.0/24, 192.168.1.81/32
PersistentKeepalive = 25
EOF
```

| Ligne | Rôle |
|---|---|
| `DNS = 192.168.1.81` | Tant que le tunnel est actif, toutes les requêtes DNS de l'iPhone vont à AdGuard |
| `Endpoint` | Où joindre le Pi. Ici, son adresse **locale**, pour tester à la maison. On la remplacera à l'[étape 9](#9-rendre-le-pi-joignable-depuis-lextérieur) |
| `AllowedIPs` | **Tunnel partiel** : seuls le tunnel, le LAN homelab et AdGuard passent par WireGuard |
| `PersistentKeepalive = 25` | Un petit paquet toutes les 25 secondes, pour que la box et l'opérateur ne coupent pas la connexion inactive |

### 7.2 Importer avec un QR code

1. Installe l'application **WireGuard**, l'officielle, sur l'App Store.
2. Sur le Pi : `qrencode -t ansiutf8 < iphone.conf`. Un QR code s'affiche dans le terminal.
3. Dans l'application : **+ → Créer à partir d'un code QR**, puis scanne et donne un nom (ex. « homelab »).
4. Supprime le fichier, qui contient la clé privée : `rm iphone.conf iphone.key`, puis `exit`.

Refais la même chose pour l'iPad (`10.0.20.3`, `ipad.key`) et le Mac (`10.0.20.4`, `mac.key`). Sur le Mac, l'application WireGuard du Mac App Store importe le fichier `.conf` directement.

### 7.3 Activation automatique (iOS)

Dans l'application : touche le tunnel, puis **Modifier → Activation à la demande** :

- ✅ **Données cellulaires** : actif en 4G ;
- ✅ **Wi-Fi**, **sauf** le Wi-Fi de la maison, où AdGuard est déjà joignable directement.

---

## 8. Tester à la maison

L'iPhone est sur le Wi-Fi de la maison, avec le tunnel activé à la main.

| Test | Où | Résultat attendu |
|---|---|---|
| `sudo wg show` | Pi | Une ligne `latest handshake: … seconds ago` pour l'iPhone, et des octets reçus et envoyés |
| Ouvrir `http://192.168.1.81:8080` | iPhone | L'interface d'AdGuard s'affiche |
| Journal des requêtes d'AdGuard | AdGuard | Les requêtes de l'iPhone apparaissent |
| Ping de `10.0.20.2` | Pi | L'iPhone répond. iOS peut ignorer les pings : ce n'est pas bloquant |

> Ce test prouve que le serveur, les clés, le DNS et le pare-feu fonctionnent. Il **ne prouve pas** l'accès depuis l'extérieur : c'est l'étape suivante.

---

## 9. Rendre le Pi joignable depuis l'extérieur

C'est la partie délicate du homelab. La connexion Sonatel est en **DS-Lite** (CGNAT) : **aucune connexion IPv4 entrante** n'est possible (voir l'[ADR 0003](../decisions/0003-acces-distant.md)). Il reste deux voies :

| Voie | Ce qu'il faut | Statut |
|---|---|---|
| **A. IPv6 directe** | Que le téléphone ait de l'IPv6 en 4G (test sur `test-ipv6.com`). Une règle dans le pare-feu IPv6 de la box (UDP 51820 vers le Pi). Un nom DNS dynamique (AAAA), parce que l'IPv6 peut changer | À vérifier |
| **B. Relais par un VPS** | Louer un petit VPS. Le Pi ouvre le tunnel **vers** lui, ce que le CGNAT laisse passer | Pas de VPS pour l'instant |

Une fois la voie choisie, il suffit de **changer la ligne `Endpoint`** de chaque client, par exemple `Endpoint = pi.mondomaine.example:51820`. Rien d'autre ne bouge.

> **Avant d'ouvrir le port 51820 dans la box** : vérifier qu'aucun autre service du Pi n'est déjà exposé en IPv6. Les services SaytuMbaye écoutent sur `[::]`.

---

## 10. Ajouter ou retirer un appareil

**Ajouter** : générer une nouvelle paire de clés (étape 4), ajouter un bloc `[Peer]` avec la prochaine adresse libre (étape 5), puis recharger le tunnel sans couper les autres appareils :

```bash
sudo systemctl reload wg-quick@wg0
```

**Retirer**, en cas d'appareil perdu ou volé : supprimer son bloc `[Peer]` dans `wg0.conf`, puis `reload`. Sa clé ne sert plus à rien.

> Une clé par appareil, jamais partagée. Sinon, un seul appareil perdu oblige à reconfigurer tous les autres.

---

## 11. Dépannage

| Symptôme | Piste |
|---|---|
| `wg-quick@wg0` ne démarre pas | `journalctl -u wg-quick@wg0 -n 30`. Souvent une clé mal copiée, ou `DOCKER-USER` qui n'existe pas encore (vérifier le `After=docker.service`) |
| Pas de `latest handshake` | Le client ne joint pas le Pi : `Endpoint` faux, port bloqué, ou clés inversées (la clé **publique** du serveur va chez le client, et inversement) |
| Handshake OK, mais pas de DNS | `DNS = 192.168.1.81` absent du client, ou `192.168.1.81/32` absent de ses `AllowedIPs` |
| Handshake OK, mais le LAN homelab est injoignable | Règles `PostUp` absentes : `sudo iptables -S DOCKER-USER` doit montrer les lignes `wg0` |
| Internet coupé sur l'iPhone dès que le tunnel est actif | Le tunnel est actif mais le Pi est injoignable, donc plus de DNS. Désactiver le tunnel, puis corriger l'`Endpoint` |

---

## 12. Tout annuler

```bash
sudo systemctl disable --now wg-quick@wg0
sudo rm -r /etc/systemd/system/wg-quick@wg0.service.d
sudo rm /etc/wireguard/*
sudo apt-get remove wireguard-tools qrencode
```

Puis supprimer le tunnel dans l'application WireGuard de chaque appareil.

---

## À faire au moment de l'installation réelle

- [ ] Valider les valeurs marquées *(proposition)* et les reporter dans `network/addressing.md`.
- [ ] Exécuter les étapes 3 à 8, puis corriger ce tutoriel avec les résultats réels.
- [ ] Retirer l'avertissement « procédure préparée » en haut de page.
- [ ] Choisir la voie de l'étape 9.
