# ADR 0003 : accès à distance

- **Statut** : Proposé (dépend de la vérification du CGNAT)
- **Date** : 2026-10-26

## Contexte

Le lab doit être joignable depuis l'extérieur sans exposer les services directement sur Internet. Si la connexion est en CGNAT, aucune connexion entrante directe n'est possible.

## Options

| Option | Avantage | Limite |
|---|---|---|
| WireGuard sur pfSense | Léger, déjà intégré | Nécessite une IP publique ou un relais |
| NetBird auto-hébergé | Fonctionne en CGNAT, zero-trust | Un service de plus à maintenir |
| Tailscale | Très simple | Dépend d'un service tiers |

## Décision proposée

Commencer par **WireGuard sur pfSense**. Si le CGNAT est confirmé, relayer via le VPS Contabo. Passer à NetBird auto-hébergé en phase 2.

## À faire

- [ ] Comparer l'IP WAN de pfSense et l'IP publique visible sur Internet.
- [ ] Mettre à jour cette ADR avec le résultat.
