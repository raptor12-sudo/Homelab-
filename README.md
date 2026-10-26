# HOMELAB

Mon homelab, construit étape par étape, en partant de zéro. Je documente chaque étape au fur et à mesure, pour apprendre et pour garder une trace de ce qui marche.

## Où on en est

Le lab est au tout début. Pour l'instant :

- ✅ Un VPS Contabo sous Ubuntu 24.04, avec Traefik, Docker Compose et des certificats Let's Encrypt via DuckDNS.
- ✅ Un Raspberry Pi 5 avec AdGuard Home (DNS filtrant), qui sert aussi de routeur temporaire au LAN homelab `10.0.10.0/24`. Voir [`pi/`](pi/README.md).
- 🔲 Proxmox VE sur le HP EliteDesk 800 G3, à installer.
- 🔲 pfSense, en VM sur Proxmox. Il remplacera le Pi comme routeur.
- 🔲 Un switch manageable, pour les VLANs.

## Objectif

Apprendre le réseau, la cybersécurité et l'hébergement de services, en gardant mes services chez moi plutôt que chez un fournisseur.

## Étapes

Chaque étape ajoute une section ici, avec ce qui a été fait et pourquoi.

### Étape 1 : choix de l'hyperviseur

J'ai choisi **Proxmox VE** plutôt que Debian avec Docker, pour pouvoir séparer les services dans des conteneurs et des machines virtuelles.

### Étape 2 : le serveur

Un HP EliteDesk 800 G3 (Core i5 de 7e génération, SSD 256 Go). Il a 8 Go de RAM, ce qui suffit pour démarrer avec Proxmox et pfSense. Il faudra passer à 16 Go pour les services. pfSense y tournera en VM, avec un second port réseau (adaptateur USB ou carte PCIe) pour séparer le WAN du LAN.

*À compléter après l'installation.*

### Étape 3 : DNS et réseau séparé, sur le Raspberry Pi

Le Raspberry Pi 5 fait tourner **AdGuard Home** dans Docker. Il a été mis en place avant le serveur, parce que c'est le seul matériel disponible pour l'instant. Ses ports sont liés à l'IP locale, pour ne pas l'exposer sur l'IPv6 publique du Pi.

En attendant pfSense, le Pi crée aussi un **LAN homelab séparé** de la box (`10.0.10.0/24`, plan provisoire). Il fournit le DHCP et le NAT avec le mode `shared` de NetworkManager, et sort sur Internet par le Wi-Fi. Le Pi est partagé avec un autre projet (SaytuMbaye), ce qui explique certains choix de ports.

Détails, limites et retour arrière : [`pi/README.md`](pi/README.md). Historique : [`docs/journal.md`](docs/journal.md).

### Étape 4 : accès à distance

*À faire : vérifier si la connexion est en CGNAT. Un `traceroute` montre `192.0.0.1` juste après la box, ce qui fait penser à du DS-Lite. Selon le résultat, WireGuard sur pfSense en direct, ou via le VPS.*

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
  Box ── HP EliteDesk (Proxmox, pfSense en VM) ── switch manageable
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
├── docs/      # Journal, décisions (ADR) et runbooks
├── pi/        # Raspberry Pi : AdGuard Home et LAN temporaire
├── network/   # Plan d'adressage et règles de pare-feu
├── services/  # Services à venir
└── backup/    # Stratégie de sauvegarde
```

Aucun mot de passe, clé privée ou secret n'est versionné.

## Licence

Documentation sous licence [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).
