# Homelab

Un homelab local, orienté security-first : fondations réseau, identité et secrets, puis les workloads. Chaque étape renvoie vers un guide détaillé.

## Stack

| Domaine | Choix | Statut |
|---|---|---|
| Matériel serveur | Mini-PC AMD PRO A10, 8 Go (16 Go prévus) | À acquérir |
| Pare-feu et routeur | OPNsense | À faire |
| Accès distant | WireGuard | À faire |
| Identité | authentik | À faire |
| Secrets | OpenBao | À faire |
| Automatisation | Ansible, Terraform | À venir |
| Cluster applicatif | K3s ou Talos, ArgoCD | À venir |

## Étapes

| # | Étape | Guide |
|---|---|---|
| 1 | Choisir le matériel | [Bien choisir son matériel](https://www.stephane-robert.info/docs/homelab/materiel/) |
| 2 | Poser les fondations réseau | [OPNsense + Tailscale](https://www.stephane-robert.info/docs/homelab/opnsense-tailscale/) |
| 3 | Déployer le nœud d'administration | [Premier nœud Proxmox admin](https://www.stephane-robert.info/docs/homelab/noeud-admin-proxmox/) |
| 4 | Industrialiser avec l'IaC | Guide en préparation |
| 5 | Déployer le cluster applicatif | [GitOps](https://www.stephane-robert.info/docs/devops/delivery/gitops/) |

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
