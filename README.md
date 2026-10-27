# Homelab

Un homelab local, orienté security-first : fondations réseau, identité et secrets, puis les workloads. Chaque étape renvoie vers un guide détaillé.

## Stack

| Domaine | Choix | 
|---|---|---|
| Matériel serveur | Mini-PC AMD PRO A10, 8 Go (16 Go prévus)et un pi5 comme routeur  | 
| Pare-feu et routeur | OPNsense |
| Accès distant | WireGuard |
| Identité | authentik | 
| Secrets | OpenBao | 
| Automatisation | Ansible, Terraform |
| Cluster applicatif | K3s ou Talos, ArgoCD |

## Étapes

| # | Étape | 
|---|---|---|
| 1 | Choisir le matériel |
| 2 | Poser les fondations réseau |
| 3 | Déployer le nœud d'administration |
| 4 | Industrialiser avec l'IaC | 
| 5 | Déployer le cluster applicatif |

## Paramètres à renseigner

| Élément | Valeur | Remarque |
|---|---|---|
| Plan d'adressage | À définir | Pas de valeur tant que les VLAN ne sont pas décidés |
| Système du serveur | À décider | Proxmox ou OPNsense directement |
| Accès distant | À confirmer | Vérifier le CGNAT avant tout |

Aucun mot de passe, clé privée ni secret n'est versionné dans ce dépôt.

## Documentation

Le guide de référence : [stephane-robert.info, homelab](https://www.stephane-robert.info/docs/homelab/roadmap/).

## Licence

Voir [LICENSE](LICENSE).

## Inspirations

- [Guide homelab de stephane-robert.info](https://www.stephane-robert.info/docs/homelab/)
