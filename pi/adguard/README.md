# AdGuard Home : DNS filtrant du homelab

AdGuard Home fournit le DNS de tout le réseau homelab et bloque la publicité et le pistage à la source. Il tourne dans Docker sur le Pi, et le dnsmasq du routeur (voir le [README du Pi](../README.md)) lui transmet toutes les requêtes des clients.

**Statut** : en place et vérifié le 2026-10-28.

## Objectif

- Un **DNS filtrant** unique pour tout le homelab (câble et Wi-Fi).
- **Aucune exposition sur Internet** : le Pi a une IPv6 publique, et un résolveur DNS ouvert servirait à des attaques par amplification. Les ports n'écoutent donc que sur une seule adresse, jamais `0.0.0.0`.
- Déploiement **reproductible** et versionné (image figée).

## Déploiement

```bash
mkdir -p ~/adguard && cd ~/adguard   # y copier compose.yaml
docker compose up -d
```

Par défaut, AdGuard n'écoute que sur `127.0.0.1`. Pour servir le LAN, fixer son adresse d'écoute dans un fichier `.env` **non versionné** :

```bash
echo "ADGUARD_IP=<ip-du-pi-sur-le-lan>" > .env
docker compose up -d
```

Au premier accès, l'assistant d'installation écoute sur le port **3000** ; une fois l'installation terminée, l'interface passe sur le port **8080** (voir le `compose.yaml`). Créer le compte administrateur, puis configurer le filtrage et le DNS amont.

## Fonctionnalités activées

Objectif : tirer le maximum d'AdGuard, tout en restant privé et chiffré. Ces réglages se
font dans l'interface web après l'installation.

### Filtrage

| Fonction | Réglage | Raison |
|---|---|---|
| Listes de blocage | AdGuard DNS filter + listes **malware** et **hameçonnage** (OISD, Phishing Army) | Publicité, pistage, domaines malveillants |
| Navigation sécurisée | activée | Bloque les sites connus comme dangereux |
| Contrôle parental | activé si besoin | Filtre le contenu adulte |
| Recherche sécurisée | activée | Force le SafeSearch des moteurs |
| Règles personnalisées | au besoin | Exceptions et blocages sur mesure |

### DNS amont (chiffré)

| Réglage | Valeur | Raison |
|---|---|---|
| Amont principal | Quad9 en **DNS-over-HTTPS** (`https://dns.quad9.net/dns-query`) | Requêtes chiffrées, filtrage malware |
| Amont de secours | un second résolveur DoH (ex. Cloudflare `https://cloudflare-dns.com/dns-query`) | Disponibilité |
| DNSSEC | activé | Réponses authentifiées |
| Mode de répartition | parallèle ou le plus rapide | Latence réduite |

### Résolution locale du homelab (réécritures DNS)

Donne un nom lisible à chaque service, au lieu de retenir des adresses :

| Nom | Pointe vers |
|---|---|
| `pi.homelab` | l'adresse du Pi sur le LAN |
| `proxmox.homelab` | l'adresse du serveur Proxmox |
| `portainer.homelab` | l'adresse du Pi (port 9443) |

*(À saisir dans Filtres → Réécritures DNS. Les adresses ne sont pas versionnées.)*

### Journalisation et clients

| Fonction | Réglage | Raison |
|---|---|---|
| Journal des requêtes | conservé 7 à 90 jours | Diagnostic et visibilité |
| Statistiques | activées | Voir ce qui est bloqué et pour qui |
| Clients | nommer chaque appareil | Réglages et filtres par client |
| Limite de débit | laissée par défaut | Protège d'un abus local |

### DNS chiffré pour les clients (optionnel)

AdGuard peut aussi **servir** du DNS-over-TLS / QUIC / HTTPS aux appareils du LAN. Cela
demande un certificat TLS configuré dans AdGuard et l'ouverture des ports correspondants
(853, 443) dans le `compose.yaml` — liés à l'adresse du LAN, jamais à Internet.

| Fixe | Valeur |
|---|---|
| Image | `v0.107.79` (figée) : montée de version volontaire, après lecture des notes |
| Écoute | une seule adresse (`ADGUARD_IP`), jamais `0.0.0.0` |

## Accès à l'interface

| Mode | Commande | Interface |
|---|---|---|
| Tunnel SSH (défaut local) | `ssh -N -L 8080:127.0.0.1:8080 <utilisateur>@<ip-du-pi>` | `http://localhost:8080` |
| Direct sur le LAN | — (avec `ADGUARD_IP` fixé) | `http://<ip-du-pi-sur-le-lan>:8080` |

## Fichiers

| Fichier | Emplacement sur le Pi | Rôle |
|---|---|---|
| [`compose.yaml`](compose.yaml) | `~/adguard/compose.yaml` | Déploiement d'AdGuard Home |
| [`../lan/adguard.conf`](../lan/adguard.conf) | `/etc/NetworkManager/dnsmasq-shared.d/` | dnsmasq des LAN → AdGuard |
| `.env` (non versionné) | `~/adguard/.env` | `ADGUARD_IP`, l'adresse d'écoute réelle |

Les données d'exécution (`work/`, `conf/`) restent sur le Pi et ne sont pas versionnées : elles contiennent la configuration propre à l'installation.

## Sécurité

- Ports liés à **une seule adresse**, jamais `0.0.0.0` ; le Pi ayant une IPv6 publique, un DNS ouvert serait abusé.
- DNS amont **chiffré** (DoH Quad9) : le fournisseur d'accès ne voit pas les requêtes.
- Image **figée** : pas de mise à jour automatique silencieuse.
- Mot de passe administrateur fort ; interface jamais exposée sur Internet.

## Références

- AdGuard Home (wiki) : <https://github.com/AdguardTeam/AdGuardHome/wiki>
- Déploiement Docker : <https://github.com/AdguardTeam/AdGuardHome/wiki/Docker>
- Quad9 (DNS-over-HTTPS) : <https://quad9.net/service/service-addresses-and-features>
