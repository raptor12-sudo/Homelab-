# Caddy : reverse proxy du homelab

Caddy publie les services du homelab sous des **noms lisibles en HTTPS** (`adguard.homelab`, `portainer.homelab`, `proxmox.homelab`) au lieu d'`IP:port`. Il est déployé dans `~/caddy` sur le Pi et n'est joignable que par le VPN.

**Statut** : en place et vérifié le 2026-10-29.

## Objectif

- Un **point d'entrée unique** en HTTPS pour tous les services, avec de vrais noms.
- **Chiffrement de confiance** via une **CA interne à Caddy** (`tls internal`), sans dépendre d'un domaine public.
- **Aucune exposition sur Internet** : Caddy n'écoute que sur l'adresse VPN (Tailscale).

## Architecture

```
navigateur (https://<service>.homelab)
      │  (résolu par AdGuard : *.homelab -> adresse VPN du Pi)
      ▼
   [ Caddy ]  écoute sur l'adresse VPN, :443, CA interne
      ├─ adguard.homelab   -> AdGuard   (port 8080, http)
      ├─ portainer.homelab -> Portainer (port 9443, https auto-signé)
      └─ proxmox.homelab   -> Proxmox   (port 8006, https auto-signé)
```

La résolution `*.homelab` est fournie par AdGuard (réécriture DNS) et distribuée aux appareils par le split-DNS Tailscale. Voir [`../adguard/README.md`](../adguard/README.md).

## Déploiement

Les adresses réelles ne sont pas versionnées : elles vont dans un fichier `.env` à côté du `compose.yaml`.

```bash
mkdir -p ~/caddy && cd ~/caddy        # y copier compose.yaml et Caddyfile
cat > .env <<'ENV'
CADDY_BIND=<adresse-vpn-du-pi>        # ex. l'IP Tailscale du Pi
PROXMOX_UPSTREAM=<ip-proxmox>:8006
ENV
docker compose up -d
```

## Résolution des noms (pour que `*.homelab` marche partout)

1. **AdGuard** : réécriture DNS `*.homelab` → adresse VPN du Pi (voir le README d'AdGuard).
2. **Tailscale** (console admin → DNS → Nameservers) : ajouter un nameserver **Custom** = adresse VPN du Pi, **restreint au domaine** `homelab`. Tout appareil du tailnet résout alors `*.homelab`.

## Faire confiance au certificat (une fois par appareil)

La CA interne de Caddy n'est pas distribuée automatiquement : installer son certificat racine sur chaque appareil.

```bash
# récupérer la CA depuis le conteneur
docker exec caddy cat /data/caddy/pki/authorities/local/root.crt > caddy-root-ca.crt
```

- **macOS** : `sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain caddy-root-ca.crt` (quitter/rouvrir le navigateur ; Firefox utilise son propre magasin ou `security.enterprise_roots.enabled=true`).
- **iOS** : envoyer le fichier → installer le profil → Réglages → Général → Informations → Réglages des certificats de confiance → activer.

## Fichiers

| Fichier | Emplacement sur le Pi | Rôle |
|---|---|---|
| [`compose.yaml`](compose.yaml) | `~/caddy/compose.yaml` | Déploiement de Caddy |
| [`Caddyfile`](Caddyfile) | `~/caddy/Caddyfile` | Définition des sites et du reverse proxy |
| `.env` (non versionné) | `~/caddy/.env` | Adresse d'écoute VPN et upstreams réels |

## Sécurité

- Caddy n'écoute **que** sur l'adresse VPN (`CADDY_BIND`), jamais sur `0.0.0.0` ni l'IPv6 publique.
- `tls_insecure_skip_verify` ne concerne que le lien **interne** Caddy → service (certs auto-signés des backends) ; le lien navigateur → Caddy, lui, est validé par la CA interne.
- La **clé privée de la CA** vit dans le volume `caddy_data` : à sauvegarder, jamais à versionner. Qui l'obtient peut forger des certificats de confiance.
- Mises à jour d'image volontaires (version figée).

## Références

- Caddy, `reverse_proxy` : <https://caddyserver.com/docs/caddyfile/directives/reverse_proxy>
- Caddy, `tls internal` (CA locale) : <https://caddyserver.com/docs/caddyfile/directives/tls>
- Caddy, variables d'environnement dans le Caddyfile : <https://caddyserver.com/docs/caddyfile/concepts#environment-variables>
