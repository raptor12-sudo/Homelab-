# ADR 0005 : OPNsense comme pare-feu et routeur

- **Statut** : Accepté
- **Date** : 2026-10-27
- **Remplace** : le choix implicite de pfSense

## Contexte

Le lab a besoin d'un pare-feu qui assure la segmentation VLAN, le routage inter-VLAN, le DNS interne, l'accès VPN et la détection d'intrusion. Le plan de travail place cette couche en première étape. Le guide de référence utilisé pour le plan s'appuie sur OPNsense.

## Décision

Utiliser **OPNsense** comme pare-feu et routeur du lab.

## Justification

- Suricata est intégré pour la détection d'intrusion (IDS/IPS).
- WireGuard est intégré pour l'accès distant.
- Les procédures du guide de référence correspondent directement.
- OPNsense et pfSense ont des fonctions équivalentes pour nos besoins de base : le choix repose donc sur l'intégration de Suricata et sur le plan suivi.

## Conséquences

- **Suricata** tourne sur le pare-feu lui-même, en mode détection (IDS) au départ. Pas de port miroir nécessaire, mais le pare-feu doit avoir deux interfaces (WAN et LAN).
- **Deux ports réseau** sont nécessaires : le port natif du mini PC et un adaptateur USB Gigabit. Le modèle d'adaptateur doit être vérifié pour sa compatibilité avec FreeBSD avant l'achat.
- **Mémoire** : 16 Go recommandés pour faire tourner OPNsense avec Suricata et les autres services.
- **DNS** : le rôle DNS entre OPNsense et AdGuard (sur le Pi) reste à trancher.
- **Système d'exploitation du serveur** : OPNsense peut être installé directement sur le mini PC, ou dans une VM sur un hyperviseur. Ce choix reste ouvert et conditionne l'emplacement des autres services.
