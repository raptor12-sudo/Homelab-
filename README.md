# RasNetLab : homelab local, indépendant et documenté

Homelab personnel, entièrement local, conçu pour apprendre et expérimenter en réseau, cybersécurité, hébergement de services et IoT/télécoms. L'objectif est de ne dépendre d'aucun fournisseur tiers pour les services du quotidien, et de documenter chaque étape pour qu'elle soit reproductible.

> Principe directeur : **ce qui peut tourner chez moi tourne chez moi.** Un service externe n'est utilisé qu'en dernier recours, et seulement après avoir été évalué.

---

## Sommaire

1. [Objectifs](#objectifs)
2. [Matériel](#matériel)
3. [Architecture réseau](#architecture-réseau)
4. [Services déployés](#services-déployés)
5. [Installation pas à pas](#installation-pas-à-pas)
6. [Sécurité](#sécurité)
7. [Sauvegardes](#sauvegardes)
8. [Observabilité](#observabilité)
9. [Structure du dépôt](#structure-du-dépôt)
10. [Feuille de route](#feuille-de-route)
11. [Ressources](#ressources)
12. [Licence](#licence)

---

## Objectifs

- **Apprendre** : VLANs, routage, pare-feu, DNS, VPN, conteneurs, supervision.
- **Sécuriser** : segmentation, accès à privilèges minimaux, journalisation centralisée, détection d'intrusion.
- **Héberger** : services personnels privés (mots de passe, fichiers, supervision, DNS).
- **Expérimenter** : IoT, télécoms mobiles (Open5GS, srsRAN) et tests de protocoles.
- **Documenter** : chaque composant a une procédure de reconstruction versionnée dans ce dépôt.

## Matériel

| Rôle | Matériel | Remarques |
|---|---|---|
| Hyperviseur / services | Mini PC Intel N100 ou N150 | 16 Go de RAM minimum, SSD NVMe 512 Go, 2,5 GbE si possible |
| Services permanents / DNS | Raspberry Pi 4 ou 5 (4 à 8 Go) | Stockage sur SSD USB, pas sur carte SD |
| Routage / pare-feu | pfSense (existant) | VLANs, règles inter-zones, WireGuard |
| Switch / Wi-Fi | Omada (existant) | Trunk vers le mini PC, ports taggés |
| Public (temporaire) | VPS Contabo | Point d'entrée public, à retirer une fois l'accès VPN en place |

## Architecture réseau

```
                    Internet
                        │
                ┌───────┴────────┐
                │    pfSense     │  Pare-feu, VLANs, WireGuard
                └───────┬────────┘
                        │ trunk 802.1Q
                ┌───────┴────────┐
                │  Switch Omada  │
                └┬──────┬──────┬─┘
                 │      │      │
      VLAN 10    │      │      │   VLAN 40
      Serveurs   │      │      │   Management
     ┌───────────┴┐  ┌──┴─────┐│   ┌──────────┐
     │  Mini PC   │  │   Pi   ││   │  Admin   │
     │ (services) │  │ (DNS)  ││   │  (poste) │
     └────────────┘  └────────┘│   └──────────┘
                              │
                 VLAN 20 IoT / Lab (isolé)
```

### Plan d'adressage

| VLAN | Nom | Sous-réseau | Passerelle | Accès |
|---|---|---|---|---|
| 10 | Serveurs | `10.10.10.0/24` | `10.10.10.1` | Lecture seule depuis Management |
| 20 | IoT / Lab | `10.10.20.0/24` | `10.10.20.1` | Internet uniquement, pas de LAN |
| 30 | Invités | `10.10.30.0/24` | `10.10.30.1` | Internet uniquement |
| 40 | Management | `10.10.40.0/24` | `10.10.40.1` | Accès aux interfaces d'administration |

**Règles de base** : par défaut, aucun trafic inter-VLAN n'est autorisé. Chaque flux est ouvert explicitement et documenté dans `network/firewall-rules.md`.

## Services déployés

| Service | Rôle | Hôte | Port interne | Statut |
|---|---|---|---|---|
| Pi-hole ou AdGuard Home | DNS local, filtrage | Raspberry Pi | 53, 3000 | À faire |
| Vaultwarden | Gestionnaire de mots de passe | Mini PC (Docker) | 80 | À faire |
| Uptime Kuma | Supervision de disponibilité | Mini PC (Docker) | 3001 | À faire |
| Prometheus + Grafana | Métriques et tableaux de bord | Mini PC (Docker) | 9090, 3000 | À faire |
| Traefik | Reverse proxy interne | Mini PC (Docker) | 80, 443 | À faire |
| step-ca | Autorité de certification interne | Mini PC (Docker) | 9000 | À faire |
| Wazuh ou Suricata | Détection d'intrusion | Mini PC (VM) | variable | Plus tard |
| Open5GS / srsRAN | Lab télécoms mobiles | Mini PC (VM) | variable | Plus tard |

## Installation pas à pas

### Étape 1 : système de base

1. Installer **Debian 12** (ou Proxmox VE) sur le mini PC.
2. Créer un utilisateur non-root avec `sudo`, puis désactiver la connexion root par SSH.
3. Configurer SSH par clé Ed25519 uniquement :

```bash
ssh-keygen -t ed25519 -C "admin-lab"
ssh-copy-id -i ~/.ssh/id_ed25519.pub admin@10.10.40.10
```

Dans `/etc/ssh/sshd_config` :

```
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
```

4. Mettre à jour le système et activer les mises à jour de sécurité automatiques :

```bash
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

### Étape 2 : DNS local (Raspberry Pi)

1. Installer AdGuard Home ou Pi-hole.
2. Dans pfSense, configurer le DHCP pour distribuer le Pi comme serveur DNS.
3. Créer un domaine interne (par exemple `lab.home.arpa`, réservé par la RFC 8375) et ajouter les enregistrements vers les services.

### Étape 3 : Docker et pile de services

```bash
sudo apt install -y docker.io docker-compose-plugin
sudo usermod -aG docker admin
```

Chaque service vit dans son propre dossier sous `services/`, avec un `docker-compose.yml` versionné. Exemple minimal pour Vaultwarden :

```yaml
services:
  vaultwarden:
    image: vaultwarden/server:latest
    restart: unless-stopped
    environment:
      DOMAIN: "https://vault.lab.home.arpa"
    volumes:
      - ./data:/data
    networks:
      - proxy

networks:
  proxy:
    external: true
```

### Étape 4 : reverse proxy et certificats internes

1. Créer le réseau Docker partagé : `docker network create proxy`.
2. Déployer Traefik et step-ca.
3. Importer le certificat racine de step-ca sur les postes clients.
4. Chaque service expose ses routes via des labels Traefik, en HTTPS uniquement.

### Étape 5 : accès à distance

Accès par WireGuard sur pfSense, ou NetBird auto-hébergé pour un maillage zero-trust. Aucun port de service n'est exposé directement sur Internet.

## Sécurité

- **Authentification** : clés SSH Ed25519 uniquement, pas de mot de passe. Double authentification sur les interfaces web lorsque c'est possible.
- **Principe du moindre privilège** : règles pare-feu par défaut en refus, ouverture explicite et documentée.
- **Segmentation** : le VLAN IoT ne peut pas atteindre le VLAN serveurs. Le VLAN de management est isolé.
- **Mises à jour** : `unattended-upgrades` pour les correctifs de sécurité, revue manuelle pour les mises à jour majeures.
- **Journalisation** : les logs de pfSense, Traefik et SSH sont centralisés (Loki ou Wazuh, selon l'étape).
- **Protection contre la force brute** : CrowdSec ou fail2ban sur les services exposés.
- **Secrets** : aucun secret en clair dans le dépôt. Utiliser des fichiers `.env` ignorés par Git, ou SOPS pour les secrets versionnés.

## Sauvegardes

Règle appliquée : **3 copies, 2 supports différents, 1 hors site**.

| Donnée | Outil | Fréquence | Destination |
|---|---|---|---|
| Volumes Docker | restic | Quotidienne | Disque externe local |
| Configuration Git | Git (push) | À chaque modification | Dépôt distant (GitHub) |
| Configuration pfSense | Export XML | Hebdomadaire | Disque externe local |
| Copie hors site | restic chiffré | Hebdomadaire | Stockage distant chiffré |

Test de restauration : **une fois par mois**, noté dans `docs/journal.md`. Une sauvegarde non testée n'existe pas.

## Observabilité

- **Uptime Kuma** : disponibilité de chaque service, alertes.
- **node_exporter** sur chaque hôte, **Prometheus** pour la collecte, **Grafana** pour les tableaux de bord.
- **Loki** pour les logs, avec agent Promtail ou Alloy.
- Tableaux de bord versionnés dans `monitoring/dashboards/`.

## Structure du dépôt

```
rasnetlab/
├── README.md
├── docs/
│   ├── journal.md              # Journal des modifications et incidents
│   ├── architecture.md         # Schémas détaillés
│   └── runbooks/               # Procédures pas à pas
├── network/
│   ├── addressing.md           # Plan d'adressage
│   ├── vlans.md                # Configuration des VLANs
│   └── firewall-rules.md       # Règles inter-zones documentées
├── services/
│   ├── traefik/
│   ├── vaultwarden/
│   ├── uptime-kuma/
│   └── monitoring/
├── pi/
│   └── adguard/
├── backup/
│   └── restic/                 # Scripts et politiques de sauvegarde
└── security/
    ├── ssh/                    # Politique SSH (sans clés)
    └── hardening.md
```

**Règle du dépôt** : aucun secret, mot de passe, clé privée ou IP publique sensible n'est versionné. Les exemples utilisent `.env.example`.

## Feuille de route

- [ ] Installation de base du mini PC (Debian, SSH, mises à jour)
- [ ] DNS local sur Raspberry Pi
- [ ] Vaultwarden et Uptime Kuma en Docker
- [ ] Reverse proxy Traefik avec certificats internes
- [ ] Segmentation VLAN dans pfSense
- [ ] Accès distant par WireGuard ou NetBird
- [ ] Sauvegardes restic testées
- [ ] Supervision Prometheus et Grafana
- [ ] Détection d'intrusion (Wazuh ou Suricata)
- [ ] Lab IoT (MQTT, capteurs)
- [ ] Lab télécoms (Open5GS, srsRAN)
- [ ] Retrait du VPS Contabo

## Ressources

- Documentation Debian, Docker, Traefik, pfSense, WireGuard
- RFC 8375 (domaine `home.arpa`)
- Guides de durcissement CIS Benchmarks pour Debian

## Licence

Documentation sous licence [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). Fichiers de configuration sous licence MIT, sauf mention contraire.
