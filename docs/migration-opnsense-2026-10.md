# Journal de la migration vers OPNsense (octobre 2026)

Journal de ce qui a été fait pour passer le routage du homelab sur OPNsense (VM 100 sur px1), avec le Raspberry Pi qui garde la passerelle du réseau et les services web.

> Statut au 30 octobre 2026 : **en cours**. Les segments `srv`, `iot` et `guest` sont créés et leur DHCP répond. Il reste à valider la sortie Internet des segments et à finir les règles.

## Changement de plan

Le plan initial prévoyait de déplacer la passerelle d'administration sur OPNsense (`10.0.10.1`) et de passer le Pi sur `10.255.0.0/24`. Ce plan a été abandonné : il coupait trop facilement l'accès au nœud.

Le plan retenu :
- le Pi reste sur `10.0.10.1` et continue de router le réseau principal `10.0.10.0/24` ;
- le nœud px1 reste sur `10.0.10.148`, sans changement d'adresse ;
- OPNsense se branche sur ce même réseau par son WAN (`10.0.10.204`, DHCP) et route les segments `srv`, `iot` et `guest`.

## Contraintes de départ

- Un seul nœud Proxmox VE 9 (px1, mini-PC AMD), un seul port Ethernet (`nic0`), sans switch.
- Pas de matériel supplémentaire.
- WireGuard supprimé au profit de Tailscale, déjà actif sur le Pi.

## Chronologie

### 1. Réinstallation de Proxmox
- Proxmox 9.2.2 réinstallé, carte `nic0` (`d8:cb:8a:b2:90:40`), noyau 7.0.2.
- Dépôts entreprise désactivés, dépôt `pve-no-subscription` actif, `apt update` sans erreur.
- Mise à jour vers 9.2.24 (noyau 7.0.14) **reportée** à cause de la connexion lente.

### 2. Réseau SDN
- Zone `homelab` de type Simple.
- VNet `srv`, `iot` et `guest` créés, sans DHCP ni SNAT au niveau du SDN.
- Le VNet `mgmt` n'est pas utilisé pour l'instant : le nœud reste sur le réseau principal.
- Les sous-réseaux ont été créés **sans passerelle** : Proxmox plaçait sinon l'adresse de passerelle sur le bridge de l'hôte, ce qui aurait créé un conflit avec OPNsense.

### 3. VM OPNsense (VM 100)
- ISO OPNsense 26.7 téléchargée depuis le miroir officiel, archive vérifiée (SHA-256 `95cafedd…186bfb`).
- Disque de 20 Go sur `local-lvm`, 4 Go de RAM, 2 cœurs.
- Cartes `e1000` dans cet ordre :
  - `net0` sur `vmbr0` → `em0` (WAN, DHCP)
  - `net1` sur `srv` → `em1` (LAN)
  - `net2` sur `iot` → `em2` (OPT1)
  - `net3` sur `guest` → `em3` (OPT2)
- Adresses : WAN `10.0.10.204/24` (DHCP), `srv` `10.0.30.1/24`, `iot` `10.0.40.1/24`, `guest` `10.0.50.1/24`.

### 4. Pi
- Routes temporaires ajoutées pour atteindre les segments via OPNsense :
  - `10.0.30.0/24 via 10.0.10.204`
  - `10.0.40.0/24 via 10.0.10.204`
  - `10.0.50.0/24 via 10.0.10.204`
- Ces routes ne sont **pas encore permanentes** (à faire avec `nmcli`).

### 5. Pare-feu OPNsense
- WAN : option **Block private networks** décochée (sinon tout le trafic du réseau privé `10.0.10.0/24` était bloqué).
- WAN : règle `Pass` depuis le Pi (`10.0.10.1`) vers `10.0.0.0/8`, pour l'administration des segments.
- `srv` : `Block` vers `10.0.0.0/8`, puis `Pass` vers `any`.
- `iot` : `Pass` DNS vers `10.0.40.1`, `Pass` HTTPS vers `any`, puis `Block` vers `10.0.0.0/8`.
- `guest` : `Block` vers `10.0.0.0/8`, puis `Pass` vers `any`.

### 6. DHCP (Kea)
- Kea DHCPv4 activé sur `LAN`, `OPT1` et `OPT2`, avec les règles de pare-feu automatiques pour le DHCP.
- Trois sous-réseaux :
  - `10.0.30.0/24`, plage `10.0.30.100` à `10.0.30.200`
  - `10.0.40.0/24`, plage `10.0.40.100` à `10.0.40.200`
  - `10.0.50.0/24`, plage `10.0.50.100` à `10.0.50.200`
- Passerelle et DNS collectés automatiquement à partir de l'interface.

### 7. Test avec une VM (VM 200, Alpine Linux 3.24.3)
- DHCP : la VM reçoit `10.0.30.101`, passerelle `10.0.30.1`. **Validé.**
- Isolation : `10.0.10.148` (nœud) et `10.0.40.1` (iot) ne répondent pas depuis `srv`. **Validé.**
- Ping vers la passerelle `10.0.30.1` : échoue, car la règle `Block` de `srv` couvre aussi `10.0.30.1`. **À corriger.**
- Sortie vers `1.1.1.1` : à revalider après correction de la passerelle et vérification de la route par défaut de la VM.

## Problèmes rencontrés et solutions

| Problème | Cause | Solution |
|---|---|---|
| Coupure d'accès au nœud | Changement d'adresse du nœud et du Pi dans le mauvais ordre | Abandon du plan, nœud laissé sur `10.0.10.148` |
| Nom de carte `enp1s0` après mise à jour du noyau | Le nom de la carte a changé | Réinstallation : `nic0` est revenu |
| Interface web OPNsense inaccessible | Interface LAN sans adresse | Adresse `10.0.30.1` configurée depuis la console |
| Pings du Pi vers OPNsense en échec | Option **Block private networks** sur le WAN | Option décochée |
| Erreur « Source ports are only valid for tcp or udp » | Port source renseigné avec le protocole `any` | Port laissé vide |
| Sous-réseau `guest` enregistré en `10.0.50.1/24` | Erreur de saisie | Corrigé en `10.0.50.0/24` |
| Proxmox place la passerelle sur le bridge de l'hôte | Passerelle renseignée dans le sous-réseau SDN | Sous-réseaux recréés sans passerelle |
| `ip -br a` introuvable dans la VM | BusyBox ne prend pas cette option | Utiliser `ip a` |

## Points ouverts

- Ajouter une règle `Pass` sur `LAN` (`srv`) : source `LAN net`, destination `LAN address`, **au-dessus** du `Block`.
- Valider la sortie vers `1.1.1.1` depuis la VM 200 (route par défaut à vérifier).
- Rendre les routes du Pi permanentes (`nmcli`).
- Décider de la réservation DHCP du WAN (`10.0.10.204` actuellement, éventuellement `10.0.10.2`).
- Vérifier que l'ISO a bien été retirée de la VM 100 (`qm set 100 --ide2 none,media=cdrom`).
- Unbound DNS : écouter sur les interfaces `srv`, `iot` et `guest`.
- Tailscale : routes `10.0.10.0/24` et `10.0.30.0/24`, ACL par groupes, suppression de WireGuard.
- Sauvegardes : vzdump de la VM 100 et de la VM 200 (à supprimer après les tests), clé USB2.
- Mise à jour de Proxmox vers 9.2.24 quand la connexion le permettra.
- Disque 256 Go : reporté.
