# RasNetLab

Mon homelab, construit étape par étape, en partant de zéro. Je documente chaque étape au fur et à mesure, pour apprendre et pour garder une trace de ce qui marche.

## Où on en est

Le lab est au tout début. Pour l'instant :

- ✅ Un VPS Contabo sous Ubuntu 24.04, avec Traefik, Docker Compose et des certificats Let's Encrypt via DuckDNS.
- ✅ Un routeur pfSense, avec un switch Omada.
- 🔲 Un mini PC pour le serveur, à acheter.
- 🔲 Proxmox VE, à installer une fois le mini PC acquis.

## Objectif

Apprendre le réseau, la cybersécurité et l'hébergement de services, en gardant mes services chez moi plutôt que chez un fournisseur.

## Étapes

Chaque étape ajoute une section ici, avec ce qui a été fait et pourquoi.

### Étape 1 : choix de l'hyperviseur

J'ai choisi **Proxmox VE** plutôt que Debian avec Docker, pour pouvoir séparer les services dans des conteneurs et des machines virtuelles.

### Étape 2 : le serveur

Un mini PC d'occasion, avec un Core i5 de 6e à 8e génération si possible, 16 Go de RAM minimum et un SSD de 256 à 512 Go. Le Raspberry Pi est reporté : le DNS tournera d'abord sur le mini PC.

*À compléter après l'achat.*

### Étape 3 : accès à distance

*À faire : vérifier si la connexion est en CGNAT (IP WAN de pfSense comparée à l'IP publique). Selon le résultat, WireGuard sur pfSense en direct, ou via le VPS.*

## Architecture (version actuelle)

```
Internet
   │
 pfSense ── Switch Omada
                 │
            Mini PC (Proxmox)   ← à venir
```

Le plan d'adressage sera ajouté quand les VLANs seront définis.

## Ce que je prévois d'ajouter

- AdGuard Home pour le DNS local
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
└── docs/      # Notes et décisions, au fil de l'eau
```

Aucun mot de passe, clé privée ou secret n'est versionné.

## Licence

Documentation sous licence [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).
