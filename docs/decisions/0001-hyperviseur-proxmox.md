# ADR 0001 : Proxmox VE comme hyperviseur

- **Statut** : Accepté
- **Date** : 2026-10-26

## Contexte

Le lab doit séparer les services dans des conteneurs (LXC) et des machines virtuelles (VM), pour isoler les charges et apprendre des outils proches de la production.

## Décision

Installer **Proxmox VE** sur le serveur, plutôt que Debian avec Docker seul.

## Conséquences

- Gestion native des LXC et des VM, avec sauvegardes et snapshots intégrés.
- Un système à entretenir en plus de Debian, mais formateur.
- Le serveur doit supporter la virtualisation matérielle (AMD-V ou Intel VT-x).
