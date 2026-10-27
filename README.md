# HOMELAB

Un homelab moderne, réaliste et orienté **security-first**. On pose d'abord les fondations réseau, identité et secrets, avant de déployer les premiers workloads. Chaque étape renvoie vers un guide détaillé, pour avancer sans se disperser.

## Plan de travail

1. **Fondations réseau** : pare-feu **OPNsense** (ADR 0005), segmentation (VLAN), DNS interne, plan d'adressage, refus par défaut, détection d'intrusion avec Suricata.
2. **Accès sécurisé** : accès distant par VPN (WireGuard), sans port exposé directement sur Internet.
3. **Identité et secrets** : gestion centralisée des accès et des secrets, avant tout service qui en contient.
4. **Premiers workloads** : sauvegardes, reverse proxy HTTPS, gestionnaire de mots de passe, supervision.
5. **Observabilité et détection** : métriques, journaux, détection d'intrusion.

Contraintes : la stack d'identité demande davantage de mémoire. Le passage à 16 Go de RAM sur le serveur est donc un préalable à l'étape 3. Le choix du système d'exploitation du serveur (Proxmox ou autre) reste à trancher avant l'étape 1.

## Où on en est

Le lab est au tout début. Pour l'instant :

 Un Raspberry Pi 5 avec AdGuard Home (DNS filtrant), qui sert aussi de routeur temporaire au LAN homelab `10.0.10.0/24`. Voir [`pi/`](pi/README.md).
 Proxmox VE sur le mini PC AMD PRO A10 (8 Go de RAM, disque 500 Go), à acquérir puis installer.
 OPNsense, pare-feu et routeur du lab (ADR 0005). Il remplacera le Pi comme routeur.
 Un switch manageable, pour les VLANs.

## Objectif

Apprendre le réseau, la cybersécurité et l'hébergement de services, en gardant mes services chez moi plutôt que chez un fournisseur.

## Étapes

Chaque étape ajoute une section ici, avec ce qui a été fait et pourquoi.

### Étape 1 : choix de l'hyperviseur

J'ai choisi **Proxmox VE** plutôt que Debian avec Docker, pour pouvoir séparer les services dans des conteneurs et des machines virtuelles.

### Étape 2 : le serveur

Un mini PC AMD PRO A10 d'occasion (3,0 GHz, 4 cœurs, 8 Go de RAM, disque 500 Go), choisi pour son prix. Il remplace le HP EliteDesk 800 G3 initialement envisagé (voir [ADR 0004](docs/decisions/0004-serveur-amd-a10.md)). Plan : passer la RAM à 16 Go, ajouter un SSD de 256 ou 512 Go pour Proxmox, et réserver le disque de 500 Go aux données. pfSense y tournera en VM, avec un second port réseau (adaptateur USB Gigabit) pour séparer le WAN du LAN.

*À compléter après l'installation.*

### Étape 3 : DNS et réseau séparé, sur le Raspberry Pi

Le Raspberry Pi 5 fait tourner **AdGuard Home** dans Docker. Il a été mis en place avant le serveur, parce que c'est le seul matériel disponible pour l'instant. Ses ports sont liés à l'IP locale, pour ne pas l'exposer sur l'IPv6 publique du Pi.

En attendant pfSense, le Pi crée aussi un **LAN homelab séparé** de la box (`10.0.10.0/24`, plan provisoire). Il fournit le DHCP et le NAT avec le mode `shared` de NetworkManager, et sort sur Internet par le Wi-Fi. Le Pi est partagé avec un autre projet (SaytuMbaye), ce qui explique certains choix de ports.

Tutoriel pas à pas : [`docs/tutoriels/01-pi-adguard-reseau-homelab.md`](docs/tutoriels/01-pi-adguard-reseau-homelab.md). Fiche technique : [`pi/README.md`](pi/README.md). Historique : [`docs/journal.md`](docs/journal.md).

### Étape 4 : accès à distance

*En cours : la connexion est très probablement en DS-Lite (CGNAT), donc sans IPv4 entrante. Piste retenue : WireGuard direct en IPv6 vers le Pi, sous réserve d'un test en 4G. Sinon, un VPS à louer servira de relais. Voir l'[ADR 0003](docs/decisions/0003-acces-distant.md). Procédure préparée, pas encore exécutée : [tutoriel 02](docs/tutoriels/02-wireguard-pi.md).*

## Architecture (version actuelle)

Aujourd'hui :

```
Internet
   │
  Box ~~~ Wi-Fi ~~~ Raspberry Pi 5 (AdGuard, DHCP, NAT)
                         │ eth0, 10.0.10.0/24
                    1 poste en câble
```

Cible :

```
Internet
   │
  Box ── Mini PC A10 (Proxmox, pfSense en VM) ── switch manageable
                                                      │
                                         Raspberry Pi (DNS), serveurs, postes
```

Le plan d'adressage définitif sera ajouté quand les VLANs seront définis.

## Ce que je prévois d'ajouter

- Traefik et une autorité de certification interne
- Vaultwarden et Uptime Kuma
- Sauvegardes avec restic
- Supervision avec Prometheus et Grafana

Chacun de ces points sera ajouté comme une étape, une fois le précédent fonctionnel.

## Structure du dépôt

```
Homelab-/
├── README.md
├── LICENSE
├── docs/      # Journal, décisions (ADR), tutoriels et runbooks
├── pi/        # Raspberry Pi : AdGuard Home et LAN temporaire
├── network/   # Plan d'adressage et règles de pare-feu
├── services/  # Services à venir
└── backup/    # Stratégie de sauvegarde
```

Aucun mot de passe, clé privée ou secret n'est versionné.

## Licence

Documentation sous licence [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).
