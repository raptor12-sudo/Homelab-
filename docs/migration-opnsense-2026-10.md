# Migrer le routage du homelab vers OPNsense

**Ce guide retrace la migration du routage d'un homelab vers OPNsense, exécutée en VM sur Proxmox, avec des segments isolés par SDN. Il raconte aussi les erreurs commises, parce qu'elles montrent mieux que n'importe quelle théorie pourquoi l'ordre des opérations compte.**

## Ce que vous allez mettre en place

- Un routeur et pare-feu **OPNsense 26.7** en VM sur un seul nœud Proxmox VE 9.
- Trois segments isolés, `srv`, `iot` et `guest`, créés par le SDN de Proxmox.
- Un DHCP par segment, avec **Kea DHCP**.
- Un Raspberry Pi qui reste passerelle du réseau principal et garde ses services web.

## Le changement de plan

Le plan initial voulait déplacer la passerelle d'administration sur OPNsense (`10.0.10.1`) et placer le Pi sur un petit réseau de transit (`10.255.0.0/24`).

**Ce plan a été abandonné.** Il exigeait de changer l'adresse du nœud et celle du Pi dans le bon ordre, sans aucun filet de sécurité. Un seul oubli, et l'accès au nœud tombait.

Le plan retenu est plus simple :

- le Pi reste sur `10.0.10.1` et continue de router le réseau principal ;
- le nœud reste sur `10.0.10.148`, sans changement d'adresse ;
- OPNsense se branche sur ce même réseau par son WAN, en DHCP (`10.0.10.204`), et route les trois segments.

> **Gardez toujours un accès de secours.** Avant de toucher à une adresse, vérifiez que vous avez la console physique ou un accès Tailscale vers une machine qui ne dépend pas du changement.

## Étape 1 : réinstaller et préparer Proxmox

Une installation fraîche de Proxmox VE 9.2.2 (noyau 7.0.2) donne une carte `nic0`. Désactivez les dépôts entreprise, qui renvoient une erreur 401 sans abonnement, puis activez `pve-no-subscription`.

**Test** : `apt update` se termine sans erreur.

La mise à jour vers 9.2.24 (noyau 7.0.14) a été reportée à cause d'une connexion lente. Ce n'est pas bloquant pour la suite.

## Étape 2 : créer les segments dans le SDN

Créez la zone `homelab` de type Simple, puis les VNet `srv`, `iot` et `guest`.

Il y a un piège ici : si vous donnez une passerelle au sous-réseau, Proxmox la place **sur le bridge de l'hôte**. Au moment où OPNsense prendra la même adresse sur sa carte, vous aurez un conflit d'IP. Créez donc les sous-réseaux **sans passerelle** :

```bash
pvesh create /cluster/sdn/vnets/srv/subnets --subnet 10.0.30.0/24 --type subnet
pvesh set /cluster/sdn
ip -br a
```

**Test** : `srv`, `iot` et `guest` sont `UP` **sans** adresse IP, et `vmbr0` garde `10.0.10.148/24`.

## Étape 3 : créer la VM OPNsense

Créez la VM 100 avec une carte par bridge, dans cet ordre précis, parce que OPNsense nomme les cartes selon cet ordre :

- `net0` sur `vmbr0` → `em0` (WAN)
- `net1` sur `srv` → `em1` (LAN)
- `net2` sur `iot` → `em2` (OPT1)
- `net3` sur `guest` → `em3` (OPT2)

Vérifiez l'empreinte de l'ISO avant de l'installer. Le fichier de sommes publié ne contient que l'empreinte de l'archive `.bz2` : c'est elle qu'il faut comparer.

**Test** : `qm config 100` affiche les quatre cartes `e1000` et le disque prévu.

## Étape 4 : configurer les interfaces

Dans la console d'OPNsense :

| Interface | Rôle | Adresse |
|---|---|---|
| `em0` | WAN | DHCP, obtient `10.0.10.204` |
| `em1` | LAN (`srv`) | `10.0.30.1/24` |
| `em2` | OPT1 (`iot`) | `10.0.40.1/24` |
| `em3` | OPT2 (`guest`) | `10.0.50.1/24` |

Pour chaque interface LAN, la passerelle reste vide. Ce sont les segments qui passent par OPNsense, pas OPNsense qui a une passerelle.

**Test** : `ifconfig em0` affiche `10.0.10.204`, et `ping 10.0.10.1` depuis OPNsense répond.

## Étape 5 : ouvrir la route vers les segments depuis le Pi

Le Pi doit savoir qu'il faut passer par OPNsense pour atteindre les segments :

```bash
sudo ip route replace 10.0.30.0/24 via 10.0.10.204
sudo ip route replace 10.0.40.0/24 via 10.0.10.204
sudo ip route replace 10.0.50.0/24 via 10.0.10.204
ip route | grep "10.0."
```

> **Une route annoncée n'est pas une route active.** Ces commandes sont temporaires : elles disparaissent au redémarrage. La version permanente passera par `nmcli`, à faire plus tard.

## Étape 6 : autoriser le trafic dans le pare-feu

Deux réglages bloquent le trafic par défaut, et il faut les connaître.

### Le WAN bloque les adresses privées

Sur **Interfaces → WAN**, l'option **Block private networks** bloque tout le trafic venant d'une adresse privée, avant même que vos règles soient lues. Or le Pi est en `10.0.10.1`. **Décochez cette option**, sinon le Pi ne pourra jamais joindre OPNsense.

### Les règles se lisent de haut en bas

OPNsense applique la première règle qui correspond. Pour chaque segment, l'ordre est le suivant :

**`srv` (LAN)** :
1. **Block**, source `LAN net`, destination `10.0.0.0/8`, avec journalisation.
2. **Pass**, source `LAN net`, destination `any`.

**`iot` (OPT1)** :
1. **Pass**, TCP et UDP, source `OPT1 net`, destination `10.0.40.1`, port 53 (DNS).
2. **Pass**, TCP, source `OPT1 net`, destination `any`, port 443 (HTTPS).
3. **Block**, source `OPT1 net`, destination `10.0.0.0/8`.

**`guest` (OPT2)** :
1. **Block**, source `OPT2 net`, destination `10.0.0.0/8`.
2. **Pass**, source `OPT2 net`, destination `any`.

Pour l'interface `srv`, il manque encore une règle, et elle est importante : la règle 1 bloque aussi la passerelle `10.0.30.1`, qui fait partie de `10.0.0.0/8`. Ajoutez en tête une règle **Pass** : source `LAN net`, destination `LAN address`.

> **Un piège fréquent.** Si vous choisissez **TCP** comme protocole, le ping ne passe pas. Mettez **any** pour les tests, et réservez les protocoles précis aux règles qui en ont besoin.

## Étape 7 : configurer le DHCP avec Kea

Kea a remplacé ISC DHCP dans OPNsense 26.7.

1. **Services → Kea DHCP → Settings** : activez le service et cochez les trois interfaces `LAN`, `OPT1` et `OPT2`. Cochez aussi les règles de pare-feu automatiques pour le DHCP.
2. **Services → Kea DHCP → Subnets** : créez un sous-réseau par segment.

| Sous-réseau | Plage | Passerelle |
|---|---|---|
| `10.0.30.0/24` | `10.0.30.100` à `10.0.30.200` | `10.0.30.1` |
| `10.0.40.0/24` | `10.0.40.100` à `10.0.40.200` | `10.0.40.1` |
| `10.0.50.0/24` | `10.0.50.100` à `10.0.50.200` | `10.0.50.1` |

Gardez **Auto collect option data** coché : Kea remplit alors la passerelle à partir de l'interface. Laissez les champs DNS dynamique vides.

Une erreur de saisie fréquente : le sous-réseau doit être `10.0.50.0/24`, et non `10.0.50.1/24`. OPNsense l'accepte sans broncher, mais le DHCP ne fonctionne pas correctement.

**Test** : une machine branchée sur `srv` reçoit une adresse `10.0.30.1xx` avec la passerelle `10.0.30.1`.

## Étape 8 : tester avec une VM

Pour tester, nous avons utilisé une VM Alpine Linux 3.24.3 (67 Mo) branchée sur `srv`.

Dans la VM, l'interface est désactivée au démarrage. Activez-la d'abord, puis demandez une adresse :

```bash
ip link set eth0 up
udhcpc -i eth0 -n
ip a
```

BusyBox n'accepte pas `ip -br a`, d'où l'option `ip a`.

Résultats observés :

- le DHCP attribue `10.0.30.101`, **validé** ;
- le nœud (`10.0.10.148`) et le segment `iot` (`10.0.40.1`) ne répondent pas depuis `srv`, **validé** : l'isolation fonctionne ;
- le ping vers la passerelle `10.0.30.1` échoue, à cause de la règle **Block** de l'étape 6 ;
- la sortie vers `1.1.1.1` reste à revalider après correction de la passerelle.

## Ce qu'il faut retenir

- **Changez une chose à la fois**, et vérifiez-la avant de passer à la suivante.
- **Gardez un accès de secours** : console physique, ou Tailscale vers une machine indépendante.
- **Une adresse de passerelle sur un bridge hôte** peut créer un conflit dès qu'un autre équipement la reprend.
- **Le WAN bloque les adresses privées** si l'option est cochée, même avec une règle qui autorise.
- **Une règle `Block` générale** peut bloquer la passerelle elle-même : pensez à une règle `Pass` vers `LAN address`, placée au-dessus.

## Prochaines étapes

- Ajouter la règle `Pass` vers `LAN address` sur `srv`, puis retester la passerelle et `1.1.1.1`.
- Rendre les routes du Pi permanentes avec `nmcli`.
- Fixer l'adresse du WAN par une réservation DHCP.
- Configurer Unbound DNS sur les trois segments.
- Approuver les routes et définir les ACL dans Tailscale.
- Supprimer la VM de test une fois les tests terminés.
- Mettre à jour Proxmox vers 9.2.24.
