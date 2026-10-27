# Homelab

Infrastructure locale de test et d'apprentissage, conçue selon une approche security-first. Le déploiement suit un ordre strict : réseau, identité et secrets, puis charges applicatives.

## Objectif

Concevoir, déployer et exploiter une infrastructure réseau et de services complète, avec les contraintes suivantes :

- Hébergement exclusivement local pour les données et les services internes.
- Accès distant par VPN, sans port de service exposé sur Internet.
- Séparation des rôles : routage et filtrage, administration, services applicatifs.
- Reproductibilité : chaque composant est documenté et réinstallable.

## Architecture

| Couche | Composant | Rôle |
|---|---|---|
| Réseau | OPNsense | Routage, pare-feu, VLAN, détection d'intrusion (Suricata) |
| Accès distant | WireGuard | Tunnel VPN vers le réseau interne |
| Identité | authentik | Authentification centralisée, SSO OIDC |
| Secrets | OpenBao | Stockage et émission de secrets, PKI interne |
| Charges | Conteneurs ou VM | Services applicatifs, isolés par rôle |

## Ressources

| Élément | Spécification | État |
|---|---|---|
| Serveur | Mini-PC AMD PRO A10, 4 cœurs, 8 Go de RAM, disque 500 Go | À acquérir |
| Mémoire cible | 16 Go | Prérequis de la couche identité |
| Pare-feu | Deux interfaces réseau (port natif et adaptateur USB Gigabit) | À valider (compatibilité) |
| Stockage | SSD 256 Go, disque 500 Go, HDD 1 To | Disponible |

## Feuille de route

| Phase | Périmètre | Dépendances |
|---|---|---|
| 1. Matériel | Serveur, stockage, équipement réseau | Aucune |
| 2. Fondations réseau | OPNsense, VLAN, adressage, accès distant | Phase 1 |
| 3. Nœud d'administration | authentik, OpenBao | Phase 2, 16 Go de RAM |
| 4. Industrialisation | Ansible, Terraform, templates | Phase 3 |
| 5. Cluster applicatif | Kubernetes (K3s ou Talos), GitOps | Phases 3 et 4 |

## Points ouverts

- **Système du serveur** : Proxmox (VM OPNsense et nœud d'administration) ou OPNsense installé directement.
- **Plan d'adressage** : à définir avec la segmentation VLAN.
- **Accès distant** : la présence d'un CGNAT conditionne le choix entre accès direct et relais.

## Sécurité

- Aucun secret, mot de passe ni clé privée n'est versionné.
- Tout script est relu avant exécution.
- Le pare-feu applique un refus par défaut ; chaque flux autorisé est documenté.

## Licence

Voir [LICENSE](LICENSE).

## Références

Guide [stephane-robert.info, homelab](https://www.stephane-robert.info/docs/homelab/), pour l'ordre des phases et les outils retenus.
