# Portainer : gestion Docker du homelab

Portainer CE donne une interface web pour gérer les conteneurs Docker du Pi (déployer, lire les journaux, redémarrer) sans passer par la ligne de commande. Il est déployé dans `~/portainer` sur le Pi.

**Statut** : en place et vérifié le 2026-10-28.

## Objectif

- Gérer les conteneurs Docker du homelab depuis une interface web.
- **Aucune exposition sur Internet** : écoute sur une seule adresse, atteinte uniquement par le réseau d'administration (VPN) ou un tunnel SSH.
- Déploiement **reproductible** et versionné (image figée).

## Déploiement

```bash
mkdir -p ~/portainer && cd ~/portainer   # y copier compose.yaml
docker compose up -d
```

Par défaut, Portainer n'écoute que sur `127.0.0.1` (accès local / tunnel SSH). Pour un accès direct depuis le VPN, créer un fichier `.env` **non versionné** à côté du `compose.yaml` :

```bash
echo "PORTAINER_IP=<ip-vpn-du-pi>" > .env
docker compose up -d
```

Au premier accès, créer le compte administrateur **dans les 5 minutes** : passé ce délai, Portainer se verrouille par sécurité et il faut redémarrer le conteneur (`docker restart portainer`).

## Accès

| Mode | Commande | Interface |
|---|---|---|
| Tunnel SSH (défaut) | `ssh -N -L 9443:127.0.0.1:9443 <utilisateur>@<ip-du-pi>` | `https://localhost:9443` |
| Direct via VPN | — (avec `PORTAINER_IP` fixé) | `https://<ip-vpn-du-pi>:9443` |

Le certificat est auto-signé : accepter l'avertissement du navigateur au premier accès.

## Sécurité

- **Le socket Docker (`/var/run/docker.sock`) donne un contrôle quasi-root** sur le Pi : qui atteint Portainer peut tout faire sur l'hôte. La protection repose donc entièrement sur le fait qu'il **n'écoute jamais sur Internet** — seulement sur `127.0.0.1` ou l'adresse VPN.
- Ne jamais publier le port sur `0.0.0.0` ni l'exposer via une redirection de port sur la box.
- Mot de passe administrateur fort ; activer la double authentification dans Portainer.
- Image figée : une montée de version se fait volontairement, après lecture des notes de version.

## Fichiers

| Fichier | Emplacement sur le Pi | Rôle |
|---|---|---|
| [`compose.yaml`](compose.yaml) | `~/portainer/compose.yaml` | Déploiement de Portainer CE |
| `.env` (non versionné) | `~/portainer/.env` | `PORTAINER_IP` pour l'accès direct via VPN |

## Références

- Portainer CE, installation Docker : <https://docs.portainer.io/start/install-ce/server/docker/linux>
- Sécurité du socket Docker : <https://docs.docker.com/engine/security/protect-access/>
