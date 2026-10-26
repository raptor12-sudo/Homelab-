# ADR 0003 : accès à distance

- **Statut** : Proposé (CGNAT vérifié, décision à valider)
- **Date** : 2026-10-26 (mise à jour le même jour après la vérification du CGNAT)

## Contexte

Le lab doit être joignable depuis l'extérieur sans exposer les services directement sur Internet.

Deux usages sont visés :

1. **Administrer le lab** à distance : interfaces web, SSH, Proxmox plus tard.
2. **Garder le filtrage DNS d'AdGuard Home hors de chez soi**, sur l'iPhone et l'iPad en 4G ou sur un Wi-Fi public.

### Résultat de la vérification du CGNAT (2026-10-26)

- Opérateur : Sonatel.
- L'IPv4 vue depuis Internet est partagée : elle n'appartient pas à la box.
- Un `traceroute` montre `192.0.0.1` juste après la box. C'est l'adresse réservée par la RFC 6333 à l'équipement DS-Lite de l'opérateur (AFTR) : la box encapsule l'IPv4 dans de l'IPv6, et l'opérateur la traduit vers une IPv4 partagée.
- L'IPv6 est native et publique : chaque appareil a sa propre adresse joignable.

**Conclusion** : DS-Lite très probable, donc **aucune connexion entrante possible en IPv4**. Reste à le confirmer sur la page WAN de la box : l'IPv4 du WAN doit y être vide, ou la page doit indiquer « DS-Lite ».

## Options

| Option | Avantage | Limite |
|---|---|---|
| WireGuard direct en IPv4 | Simple | **Impossible** en DS-Lite |
| WireGuard direct en IPv6 | Pas de relais | Ne marche que si le réseau du client a de l'IPv6 (souvent absent en Wi-Fi public). Dépend du pare-feu IPv6 de la box |
| **WireGuard relayé par le VPS Contabo** | Marche partout : le lab ouvre une connexion sortante, que le CGNAT laisse passer. Le VPS existe déjà | Un saut de plus (latence), et le VPS devient un point d'entrée à durcir |
| NetBird auto-hébergé | Gère seul le relais et les pairs, zero-trust | Un service de plus à maintenir |
| Tailscale | Très simple | Dépend d'un service tiers, exclu par principe |

## Décision proposée

**WireGuard relayé par le VPS Contabo**, avec l'IPv6 directe gardée en bonus. NetBird auto-hébergé viendra en phase 2.

```
iPhone / iPad (4G) ──WireGuard──> VPS Contabo <──WireGuard (sortant, keepalive)── Pi, puis pfSense
                                       │
                          route vers le LAN homelab et vers AdGuard
```

- **Côté lab** : le Pi, puis pfSense quand il sera en service, ouvre le tunnel **vers** le VPS avec `PersistentKeepalive`. Comme la connexion part de chez soi, le CGNAT ne la bloque pas.
- **Côté VPS** : il relaie entre les clients mobiles et le tunnel du lab. Il n'expose que le port UDP de WireGuard.
- **Côté iPhone et iPad** : application WireGuard officielle, en **tunnel partiel**. Seuls le DNS et les sous-réseaux du lab passent par le tunnel, le reste du trafic sort directement. Le DNS du tunnel est AdGuard Home.

### Ce que ce tunnel ne fera pas

Il **ne bloquera pas les publicités YouTube**. Le trafic HTTPS reste chiffré de bout en bout : ni le VPS ni le Pi ne voient le contenu des pages, seulement les domaines. Bloquer ces pubs au niveau du réseau demanderait de déchiffrer tout le HTTPS (interception TLS avec un certificat racine installé sur les appareils). C'est refusé : ça exposerait tous les mots de passe et comptes au Pi, et ça casserait l'application YouTube et les applications bancaires, qui vérifient leurs certificats (*certificate pinning*). Pour YouTube, on utilise un navigateur bloqueur (Brave) sur l'appareil.

## Conséquences

- AdGuard n'écoute aujourd'hui que sur l'IP locale du Pi. Il devra aussi écouter sur l'adresse du Pi **dans le tunnel**, sans s'ouvrir sur l'IPv6 publique.
- Si le tunnel tombe, les appareils mobiles perdent leur DNS tant que WireGuard est actif. À compenser avec les règles « à la demande » de l'application WireGuard (désactiver le tunnel sur le Wi-Fi de la maison) et la supervision du tunnel.
- Le VPS doit être durci : SSH par clé, pare-feu limité au port WireGuard et au SSH, mises à jour automatiques.
- Aucune clé privée WireGuard n'est versionnée. Le dépôt ne contient que des modèles de configuration.

## À définir

- Sous-réseau du tunnel WireGuard.
- Port UDP de WireGuard sur le VPS.
- Quelle machine du lab porte le tunnel avant pfSense : le Pi, a priori.

## À faire

- [x] Vérifier le CGNAT : DS-Lite très probable (voir plus haut).
- [ ] Confirmer sur la page WAN de la box.
- [ ] Tester depuis le VPS le pare-feu IPv6 de la box, pour savoir si l'option IPv6 directe est possible et si les services du Pi sont exposés.
- [ ] Valider cette décision, puis passer le statut à « Accepté ».
- [ ] Mettre en place le tunnel lab → VPS, puis les profils iPhone et iPad.
