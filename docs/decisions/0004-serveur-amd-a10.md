# ADR 0004 : mini PC AMD PRO A10 comme serveur

- **Statut** : Accepté
- **Date** : 2026-10-27

## Contexte

Le serveur Proxmox devait initialement tourner sur un HP EliteDesk 800 G3 (Core i5-7500, 8 Go de RAM, SSD 256 Go). Le budget disponible ne permet pas d'acheter de matériel plus récent et de le faire évoluer.

## Décision

Utiliser un **mini PC AMD PRO A10** (3,0 GHz, 4 cœurs, 8 Go de RAM, disque 500 Go) comme serveur principal, à la place du HP EliteDesk 800 G3.

## Justification

- Le coût d'acquisition reste dans le budget.
- Quatre cœurs et la virtualisation AMD-V suffisent pour Proxmox et les services de base (DNS, reverse proxy, gestionnaire de mots de passe, supervision).

## Conséquences

- **Avant installation** : activer SVM dans le BIOS, vérifier le nombre d'emplacements RAM et le plafond supporté.
- **Stockage** : ajouter un SSD de 256 ou 512 Go pour le système Proxmox. Le disque de 500 Go sert aux données et aux sauvegardes, et ne porte pas de VM active s'il est mécanique.
- **Mémoire** : passer à 16 Go dès que possible. À 8 Go, prévoir peu de services en parallèle.
- **Limites** : performances monocœur inférieures au i5-7500 et consommation électrique plus élevée. La phase observabilité (Prometheus, Grafana) et la phase sécurité (Wazuh) demanderont probablement une autre machine ou plus de RAM.
- **Réseau** : un seul port Gigabit. La détection réseau par miroir (Suricata) devra attendre une machine à deux ports.
- L'ADR 0001 reste valable : Proxmox VE est toujours l'hyperviseur retenu.
