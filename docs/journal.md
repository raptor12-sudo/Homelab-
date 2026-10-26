# Journal du lab

Une entrée par étape ou incident. Plus récent en haut.

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
