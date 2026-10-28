# Feuille de route détaillée

Ce document décline la feuille de route du README en étapes concrètes, avec pour chaque
phase ses dépendances et sa définition de « terminé ». L'ordre est strict et security-first :
on durcit chaque socle **avant** d'y poser la couche suivante.

## État actuel

- **Phase 1 (matériel)** : serveur mini-PC AMD PRO A10 acquis ; un hyperviseur **Proxmox**
  est installé et accessible sur le réseau d'administration du homelab.
- **Choix tranché** : le serveur tourne sous Proxmox ; OPNsense sera une VM, pas une
  installation directe.
- **Dispositif temporaire** (hors roadmap) : le Raspberry Pi assure le DNS filtrant, un
  routeur Wi-Fi provisoire, WireGuard et un accès distant par maillage. Il sera retiré une
  fois OPNsense en place.
- **En cours** : durcissement du socle Proxmox avant tout déploiement.

## Principes

- Hébergement local ; aucun port de service exposé sur Internet.
- Accès distant par VPN uniquement.
- Moindre privilège : pas d'usage quotidien du compte root.
- Refus par défaut sur le pare-feu ; chaque flux autorisé est documenté.
- Aucun secret versionné ; tout script est relu avant exécution.

## Phase 1 — Matériel

Fait :

- Mini-PC AMD PRO A10 acquis.
- Proxmox installé et joignable.

À faire :

- Étendre la mémoire à 16 Go (prérequis de la Phase 3).
- Valider les deux interfaces réseau : port natif et adaptateur USB Gigabit, vues
  séparément par l'OS.
- Brancher le stockage et attribuer les rôles : SSD système, disque 500 Go, HDD 1 To.

## Durcir le socle Proxmox

Prérequis avant la Phase 2. On sécurise de l'extérieur vers l'intérieur : d'abord *qui
entre*, puis *par où*, puis on *garde à jour* et on *sauvegarde*.

1. **Dépôts et mises à jour** — retirer le dépôt *enterprise*, activer *no-subscription*,
   lancer un `apt full-upgrade`. Un système à jour, c'est les failles connues corrigées.
2. **Comptes** — créer un compte admin dédié, activer la 2FA (TOTP), réserver root à
   l'urgence. C'est le moindre privilège.
3. **SSH** — authentification par clé, auth par mot de passe coupée. Une clé ne se
   brute-force pas.
4. **Pare-feu** — activer le pare-feu Proxmox, refus par défaut, n'ouvrir l'administration
   (8006 et 22) qu'au LAN d'admin et au VPN.
5. **Fail2ban** — bannir les adresses qui multiplient les échecs de connexion. Défense en
   profondeur.
6. **Sauvegardes** — `vzdump` planifié vers le HDD 1 To. Une infra sans backup n'est pas
   une infra.
7. **Hygiène** — NTP, nom d'hôte, certificat, retrait du bandeau d'abonnement.

Garde-fou : garder une session ouverte en secours avant d'activer le refus par défaut
(étape 4), pour ne pas se couper l'accès.

## Phase 2 — Fondations réseau

Dépend du socle durci.

- Définir le plan d'adressage et la segmentation VLAN (admin, services, invités, etc.).
- Créer la VM OPNsense (routage et pare-feu), une fois les deux NIC validées.
- Configurer les VLAN et les règles de pare-feu en refus par défaut, chaque flux autorisé
  documenté.
- Activer la détection d'intrusion (Suricata) sur le WAN.
- Mettre en place l'accès distant par WireGuard.
- Trancher l'accès distant selon le CGNAT de la ligne : accès direct ou relais.

## Phase 3 — Nœud d'administration

Dépend de la Phase 2 et des 16 Go de RAM.

- Déployer authentik (SSO OIDC) pour l'authentification centralisée.
- Déployer OpenBao (secrets et PKI interne).
- Rattacher au moins un service à l'authentification centralisée, en démonstration.

## Phase 4 — Industrialisation

Dépend de la Phase 3.

- Ansible pour la configuration ; un hôte reconstruit depuis les playbooks.
- Terraform pour le provisionnement ; une VM créée depuis le code.
- Templates de VM et de conteneurs, base réinstallable et reproductible.

## Phase 5 — Cluster applicatif

Dépend des Phases 3 et 4.

- Déployer Kubernetes (K3s ou Talos).
- Mettre en place le GitOps : déploiements pilotés depuis le dépôt Git.

## Points ouverts

- Plan d'adressage : à définir avec la segmentation VLAN (Phase 2).
- Accès distant : le choix direct contre relais dépend de la présence d'un CGNAT.
- Distribution du cluster : K3s ou Talos, à trancher en Phase 5.
