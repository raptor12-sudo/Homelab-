# Journal du lab

Une entrée par étape ou incident. Plus récent en haut.

## 2026-10-27 : plan de travail security-first

- Adoption d'un plan en cinq étapes : fondations réseau, accès sécurisé, identité et secrets, premiers workloads, observabilité. Les étapes sont détaillées dans le README.
- Le choix du système d'exploitation du serveur reste ouvert.

## 2026-10-27 : serveur remplacé par un mini PC AMD PRO A10

- Choix du mini PC AMD PRO A10 pour le serveur Proxmox, en remplacement du HP EliteDesk 800 G3, pour des raisons de budget (ADR 0004). pfSense en VM aura besoin d'un adaptateur USB Gigabit pour le second port.
- À faire avant l'installation : activer SVM dans le BIOS, passer la RAM à 16 Go, ajouter un SSD pour Proxmox.

## 2026-10-26 : WireGuard sur le Pi

- `wireguard-tools` et `qrencode` installés. Serveur `wg0` en `10.0.20.1/24`, port UDP `51820`, démarré après Docker (drop-in `apres-docker.conf`). Règles `DOCKER-USER` ajoutées en `PostUp`.
- Clés générées sur le Pi, lisibles par root seulement. Trois pairs déclarés : iPhone `.2`, iPad `.3`, Mac `.4`.
- iPhone configuré par QR code, en tunnel partiel, avec AdGuard comme DNS. Vérifié à la maison : poignée de main établie, et requêtes DNS visibles dans AdGuard avec le client `10.0.20.2`.
- Incidents : le QR code ne tenait pas dans le panneau tmux, d'où le passage par une image PNG copiée sur le Mac puis effacée. Le premier import n'avait donné aucune poignée de main, un nouveau QR code a réglé le problème.
- Pas encore fait : l'iPad, le Mac, l'accès depuis l'extérieur (ADR 0003) et un test de redémarrage du Pi.

## 2026-10-26 : vérification du CGNAT et accès à distance

- L'IPv4 publique est partagée, et `192.0.0.1` apparaît juste après la box dans un `traceroute` : DS-Lite très probable chez Sonatel, donc pas de connexion entrante en IPv4. L'IPv6 publique native fonctionne. Reste à confirmer sur la page WAN de la box.
- ADR 0003 mise à jour : il n'y a pas de VPS, contrairement à l'état initial du dépôt. WireGuard direct en IPv6 vers le Pi est proposé, sous réserve d'un test IPv6 en 4G. À défaut, il faudra louer un VPS pour servir de relais. Objectif : administrer le lab et garder le filtrage AdGuard sur l'iPhone et l'iPad hors de chez soi.
- iPhone et iPad : DNS réglé manuellement sur AdGuard (`192.168.1.81`), sur le Wi-Fi de la box. Les publicités YouTube passent : un filtrage DNS ne peut pas les distinguer des vidéos, qui viennent des mêmes domaines. Pour YouTube, on utilise un navigateur bloqueur. L'interception TLS a été écartée (voir ADR 0003).

## 2026-10-26 : AdGuard Home et réseau homelab temporaire sur le Pi

Contexte : le seul matériel disponible est le Raspberry Pi. Le HP EliteDesk recevra plus tard Proxmox, avec pfSense en VM. pfSense n'est donc **pas encore installé**, contrairement à ce qu'indiquait l'état initial.

**Pi identifié** : Raspberry Pi 5, 8 Go, carte microSD 64 Go, Raspberry Pi OS (Bookworm). Le Pi est partagé : il fait déjà tourner la stack Docker du projet SaytuMbaye (InfluxDB, Grafana, MQTT, moteur IA). Il est connecté à la box en Wi-Fi, en `192.168.1.81`.

**AdGuard Home** (Docker Compose, `~/adguard/compose.yaml` sur le Pi) :
- Ports publiés uniquement sur l'IP locale `192.168.1.81` : DNS 53, interface web 8080, assistant d'installation 3001. Ce dernier est déplacé parce que le port 3000 est pris par Grafana.
- Pourquoi lier à l'IP locale : le Pi a une IPv6 publique, et AdGuard ne doit pas être joignable depuis Internet.
- Vérifié depuis le Mac : `example.com` est résolu, `doubleclick.net` est bloqué (`0.0.0.0`).

**Réseau homelab séparé de la box**, en attendant pfSense :
- Connexion NetworkManager `homelab-lan` sur `eth0`, en mode `shared`. Le Pi est en `10.0.10.1/24` et assure le DHCP et le NAT vers Internet par le Wi-Fi.
- `/etc/NetworkManager/dnsmasq-shared.d/adguard.conf` envoie les requêtes DNS du LAN vers AdGuard.
- `/etc/NetworkManager/dispatcher.d/90-homelab-forward` ajoute des règles dans `DOCKER-USER`, parce que Docker met la politique `FORWARD` en `DROP` et bloquait le routage.
- Économie d'énergie du Wi-Fi désactivée (`802-11-wireless.powersave 2`), après des coupures constatées.
- Vérifié depuis le Mac, branché en câble : adresse `10.0.10.137` reçue, Internet joignable par `10.0.10.1` puis la box, publicités bloquées.

**Incident** : `homelab-lan` ne démarrait pas, parce qu'une adresse manuelle `169.254.250.6/32` restée sur `eth0` faisait passer l'interface en `managed-type: external`. Corrigé avec `ip addr del` puis `nmcli connection up homelab-lan`.

**Limites connues** :
- Sans switch, un seul appareil peut être branché sur le LAN.
- La sortie vers Internet passe par le Wi-Fi, avec un signal moyen.
- Après un redémarrage du Pi, la règle `DOCKER-USER` peut échouer si Docker n'est pas encore démarré. Débrancher puis rebrancher le câble la réapplique. Le redémarrage n'a pas encore été testé.
- Le plan d'adressage `10.0.10.0/24` est provisoire, en attendant `network/addressing.md`.

**À suivre** :
- Grafana, InfluxDB et MQTT (SaytuMbaye) écoutent sur `[::]` alors que le Pi a une IPv6 publique. Vérifier le pare-feu IPv6 de la box.
- Un `traceroute` montre `192.0.0.1` juste après la box, ce qui fait penser à du DS-Lite (CGNAT). À confirmer avant l'ADR 0003.
- Mettre à jour `pi/README.md` et `pi/adguard/README.md`, qui décrivent une autre méthode d'installation (script et systemd).

## 2026-10-26

- Choix de Proxmox VE comme hyperviseur (ADR 0001).
- Adoption de l'ordre de construction inspiré du guide homelab de stephane-robert.info (ADR 0002).
- Proposition d'accès distant par WireGuard, en attente de la vérification du CGNAT (ADR 0003).
- Création de la structure du dépôt.
