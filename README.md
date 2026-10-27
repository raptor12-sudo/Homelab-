# HOMELAB

Un homelab moderne, réaliste et orienté **security-first**. On pose d'abord les fondations réseau, identité et secrets, avant de déployer les premiers workloads. Chaque étape renvoie vers un guide détaillé, pour avancer sans se disperser.

Guide de référence : [stephane-robert.info, homelab](https://www.stephane-robert.info/docs/homelab/roadmap/)

## Feuille de route

### 1. Choisir le matériel

Mini-PC, switch manageable, stockage. Budget : 500 à 1000 € pour un setup complet dans le guide ; ici, budget réduit.

- Serveur : mini PC AMD PRO A10 d'occasion, 8 Go de RAM, disque 500 Go. Passage à 16 Go prévu.
- Stockage : SSD 256 Go, disque 500 Go, HDD 1 To.
- Switch manageable : à acheter plus tard.

→ [Bien choisir son matériel](https://www.stephane-robert.info/docs/homelab/materiel/)

### 2. Poser les fondations réseau

Pare-feu OPNsense comme routeur, VLAN et plan d'adressage. Accès distant par WireGuard, à la place de Tailscale, pour rester indépendant d'un service tiers.

- Statut : à faire.

→ [OPNsense + Tailscale](https://www.stephane-robert.info/docs/homelab/opnsense-tailscale/)

### 3. Déployer le nœud admin

Premier nœud avec les services de confiance : authentik (identité, SSO) et OpenBao (secrets). Ce nœud doit rester séparé des services applicatifs.

- Statut : à faire. Prérequis : 16 Go de RAM.

→ [Premier nœud Proxmox admin](https://www.stephane-robert.info/docs/homelab/noeud-admin-proxmox/)

### 4. Industrialiser avec l'IaC

Templates Proxmox, golden images, Ansible pour la configuration, Terraform pour le provisioning.

- Statut : à venir.

→ Guide en préparation

### 5. Déployer le cluster applicatif

Kubernetes (K3s ou Talos), observabilité, GitOps avec ArgoCD.

- Statut : à venir.

→ [GitOps](https://www.stephane-robert.info/docs/devops/delivery/gitops/)

## Licence

Voir [LICENSE](LICENSE).
