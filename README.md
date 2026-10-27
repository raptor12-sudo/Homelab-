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
| Serveur | Mini-PC AMD PRO A10, 4 cœurs, 8 Go de RAM, disque 500 Go | aquis |
| Mémoire cible | 16 Go | Prérequis de la couche identité |
| Pare-feu | Deux interfaces réseau (port natif et adaptateur USB Gigabit) | À valider (compatibilité) |
| Stockage | SSD 256 Go, disque 500 Go, HDD 1 To | Disponible |

## Équipement du serveur

### Machine

| Élément | Spécification | Statut |
|---|---|---|
| Modèle | Mini-PC AMD PRO A10 | À confirmer (référence exacte sur l'étiquette) |
| Processeur | AMD A10 PRO, 4 cœurs, 3,0 GHz | À confirmer |
| Mémoire | 8 Go, cible 16 Go | Extension à faire |
| Stockage système | SSD 256 Go ou 512 Go | À ajouter |
| Stockage données | Disque 500 Go | Type à confirmer (SSD ou mécanique) |
| Sauvegardes | HDD 1 To | Connexion USB |
<img width="577" height="445" alt="image" src="https://github.com/user-attachments/assets/f702fe9f-96af-470f-ac8d-c1443851e86d" />


### Ports et connectiques

| Port | Usage | Statut |
|---|---|---|
| RJ45 Gigabit (intégré) | Réseau LAN, côté switch ou postes | À confirmer |
| RJ45 Gigabit (adaptateur USB) | Réseau WAN, côté box | Adaptateur à valider (compatibilité OPNsense) |
| USB | Disque de sauvegarde (HDD 1 To) | À confirmer |
| USB | Clé d'installation, clavier | Disponible |
| HDMI ou DisplayPort | Console pendant l'installation | À confirmer |
| Alimentation | Adaptateur secteur | Vérifier la puissance fournie |

### Points de vigilance

- Le port natif et l'adaptateur USB doivent être reconnus séparément par OPNsense avant toute configuration.
- Le disque mécanique de 500 Go ne doit porter ni le système ni de service actif.
- Le port console sert à l'installation ; le reste de l'administration se fait à distance, par le réseau.

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
