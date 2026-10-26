# ADR 0003 : accès à distance

- **Statut** : Proposé (CGNAT vérifié, en attente du test IPv6 en 4G)
- **Date** : 2026-10-26 (mise à jour le même jour après la vérification du CGNAT)

## Contexte

Le lab doit être joignable depuis l'extérieur sans exposer les services directement sur Internet.

Deux usages sont visés :

1. **Administrer le lab** à distance : interfaces web, SSH, Proxmox plus tard.
2. **Garder le filtrage DNS d'AdGuard Home hors de chez soi**, sur l'iPhone et l'iPad en 4G ou sur un Wi-Fi public.

Contrainte : **pas de VPS** pour l'instant, et pas de service tiers (Tailscale exclu).

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
| **WireGuard direct en IPv6** | Gratuit, sans relais ni matériel en plus | Ne marche que si le réseau du client a de l'IPv6. Il faut ouvrir le port UDP de WireGuard vers le Pi dans le pare-feu IPv6 de la box. L'adresse IPv6 peut changer : un nom DNS dynamique est nécessaire |
| WireGuard relayé par un VPS | Marche depuis n'importe quel réseau, même sans IPv6 | Nécessite de louer un VPS (quelques euros par mois), à durcir et à entretenir |
| NetBird auto-hébergé | Gère seul le relais et les pairs | Nécessite aussi un serveur joignable, donc un VPS |
| Tailscale ou NetBird en version hébergée | Très simple, marche en CGNAT | Dépend d'un service tiers, exclu par principe |

## Décision proposée

**WireGuard direct en IPv6 vers le Pi**, si le test en 4G le permet. Sinon, louer un petit VPS et le relayer par lui.

```
iPhone / iPad (4G, IPv6) ──WireGuard sur IPv6──> box (pare-feu IPv6 : port UDP ouvert vers le Pi) ──> Pi
                                                                         │
                                                        AdGuard Home et LAN homelab
```

- **Côté iPhone et iPad** : application WireGuard officielle, en **tunnel partiel**. Seuls le DNS et les sous-réseaux du lab passent par le tunnel, le reste du trafic sort directement. Le DNS du tunnel est AdGuard Home.
- **Côté box** : une seule règle dans le pare-feu IPv6, qui ouvre le port UDP de WireGuard vers l'adresse IPv6 du Pi, et rien d'autre.
- **Nom DNS dynamique** : un enregistrement AAAA mis à jour automatiquement par le Pi, puisque l'adresse IPv6 peut changer.

### Test à faire avant de valider

Sur l'iPhone, **Wi-Fi coupé** (4G seule), ouvrir `https://test-ipv6.com`. Si le site affiche une adresse IPv6, l'option directe est possible. Sinon, il faut un VPS.

### Ce que ce tunnel ne fera pas

Il **ne bloquera pas les publicités YouTube**. Le trafic HTTPS reste chiffré de bout en bout : le Pi ne voit pas le contenu des pages, seulement les domaines. Bloquer ces pubs au niveau du réseau demanderait de déchiffrer tout le HTTPS (interception TLS avec un certificat racine installé sur les appareils). C'est refusé : ça exposerait tous les mots de passe et comptes au Pi, et ça casserait l'application YouTube et les applications bancaires, qui vérifient leurs certificats (*certificate pinning*). Pour YouTube, on utilise un navigateur bloqueur (Brave) sur l'appareil.

## Conséquences

- AdGuard n'écoute aujourd'hui que sur l'IP locale du Pi. Il devra aussi écouter sur l'adresse du Pi **dans le tunnel**, sans s'ouvrir sur l'IPv6 publique.
- Ouvrir un port dans le pare-feu IPv6 de la box rend le Pi joignable sur ce port. WireGuard ne répond pas aux paquets non authentifiés, ce qui limite le risque. Mais il faut d'abord vérifier que les autres ports du Pi (services SaytuMbaye) ne sont pas déjà ouverts.
- Si le tunnel tombe, les appareils mobiles perdent leur DNS tant que WireGuard est actif. À compenser avec les règles « à la demande » de l'application WireGuard (désactiver le tunnel sur le Wi-Fi de la maison).
- Aucune clé privée WireGuard n'est versionnée. Le dépôt ne contient que des modèles de configuration.

## À définir

- Sous-réseau du tunnel WireGuard.
- Port UDP de WireGuard.
- Fournisseur du nom DNS dynamique (AAAA).

## À faire

- [x] Vérifier le CGNAT : DS-Lite très probable (voir plus haut).
- [ ] Confirmer sur la page WAN de la box.
- [ ] Tester l'IPv6 en 4G sur l'iPhone (`test-ipv6.com`).
- [ ] Vérifier le pare-feu IPv6 de la box : entrant bloqué par défaut ? ouverture de port possible ?
- [ ] Valider cette décision, puis passer le statut à « Accepté ».
- [ ] Mettre en place WireGuard sur le Pi, puis les profils iPhone et iPad.
