# ADR 0002 : ordre de construction du lab

- **Statut** : Proposé
- **Date** : 2026-10-26

## Contexte

Le guide de référence [stephane-robert.info, homelab](https://www.stephane-robert.info/docs/homelab/) recommande de construire dans cet ordre : matériel, réseau, nœud d'administration, identité et secrets, puis applications. Son budget et sa pile complète (OPNsense, Tailscale, authentik, OpenBao, Kubernetes) dépassent nos moyens et nos besoins actuels.

## Décision

Garder l'ordre des fondations (réseau avant services, identité et secrets avant les applications sensibles) et adapter le contenu :

- pfSense au lieu d'OPNsense, déjà en place ;
- WireGuard au lieu de Tailscale, pour rester indépendant d'un service tiers ;
- Vaultwarden comme premier gestionnaire de secrets, authentik et OpenBao plus tard ;
- Proxmox avec LXC et VM au lieu de Kubernetes pour le moment.

## Conséquences

- La feuille de route du README suit cet ordre.
- Chaque étape ajoute une entrée au journal et, si nécessaire, une nouvelle ADR.
