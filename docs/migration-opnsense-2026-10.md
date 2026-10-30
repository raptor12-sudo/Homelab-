# Migrer le routage du homelab vers OPNsense

Ce guide retrace la migration du routage d'un homelab vers OPNsense, exécutée en VM sur Proxmox, avec des segments isolés par SDN. Il raconte aussi les erreurs commises, parce qu'elles montrent mieux que n'importe quelle théorie pourquoi l'ordre des opérations compte.

## Étape 1 : Préparer Proxmox

Une installation fraîche de Proxmox VE 9.2.2 (noyau 7.0.2) donne une carte réseau `nic0`. Commencez par les dépôts : les dépôts entreprise renvoient une erreur 401 sans abonnement, donc on les désactive et on active `pve-no-subscription`.

### Désactiver les dépôts entreprise et activer le dépôt gratuit

Fenêtre de terminal
```bash
mkdir -p /root/apt-disabled
mv /etc/apt/sources.list.d/pve-enterprise.sources /root/apt-disabled/ 2>/dev/null
mv /etc/apt/sources.list.d/ceph.sources /root/apt-disabled/ 2>/dev/null
apt update
```

**Test** : `apt update` se termine sans erreur 401.

> **Reportez les mises à jour si la connexion est lente.** La mise à jour vers 9.2.24 (noyau 7.0.14) n'est pas bloquante pour la suite. On l'a reportée, et on peut la faire plus tard.

## Étape 2 : Créer les segments dans le SDN

Créez la zone `homelab` de type Simple, puis les VNet `srv`, `iot` et `guest`.

### Créer les sous-réseaux sans passerelle

Il y a un piège ici. Si vous donnez une passerelle au sous-réseau, Proxmox la place **sur le bridge de l'hôte**. Quand OPNsense prendra la même adresse sur sa carte, vous aurez un conflit d'IP.

Fenêtre de terminal
```bash
pvesh create /cluster/sdn/vnets/srv/subnets --subnet 10.0.30.0/24 --type subnet
pvesh create /cluster/sdn/vnets/iot/subnets --subnet 10.0.40.0/24 --type subnet
pvesh create /cluster/sdn/vnets/guest/subnets --subnet 10.0.50.0/24 --type subnet
pvesh set /cluster/sdn
ip -br a
```

**Test** : `srv`, `iot` et `guest` sont `UP` **sans** adresse IP, et `vmbr0` garde `10.0.10.148/24`.

## Étape 3 : Installer OPNsense en VM

### Vérifier l'empreinte avant d'utiliser l'ISO

Les images sont distribuées compressées en bzip2. Le fichier de sommes publié sur le miroir porte sur l'archive `.bz2` : c'est elle qu'il faut contrôler. Comparez l'empreinte à celle du fichier de sommes, puis seulement après décompressez.

Fenêtre de terminal
```bash
sha256sum OPNsense-26.7-dvd-amd64.iso.bz2
bzip2 -tv OPNsense-26.7-dvd-amd64.iso.bz2
bunzip2 -k OPNsense-26.7-dvd-amd64.iso.bz2
```

Pour nous, l'empreinte de l'archive est `95cafedd…186bfb`. Une autre valeur signifie un téléchargement corrompu : recommencez, sans décompresser.

### Créer la VM avec les cartes dans le bon ordre

OPNsense nomme les cartes selon leur ordre dans la VM. Respectez donc cet ordre :

| Carte VM | Bridge | Nom dans OPNsense | Rôle |
|---|---|---|---|
| `net0` | `vmbr0` | `em0` | WAN |
| `net1` | `srv` | `em1` | LAN (`srv`) |
| `net2` | `iot` | `em2` | OPT1 (`iot`) |
| `net3` | `guest` | `em3` | OPT2 (`guest`) |

**Test** : `qm config 100` affiche les quatre cartes `e1000` et le disque prévu.

## Étape 4 : Configurer les interfaces

Dans la console d'OPNsense, assignez les interfaces puis fixez les adresses. Pour chaque interface LAN, la passerelle reste vide : ce sont les segments qui passent par OPNsense, pas l'inverse.

| Interface | Rôle | Adresse |
|---|---|---|
| `em0` | WAN | DHCP, obtient `10.0.10.204` |
| `em1` | LAN (`srv`) | `10.0.30.1/24` |
| `em2` | OPT1 (`iot`) | `10.0.40.1/24` |
| `em3` | OPT2 (`guest`) | `10.0.50.1/24` |

**Test** : `ifconfig em0 | grep "inet "` affiche `10.0.10.204`, et `ping -c2 10.0.10.1` répond depuis OPNsense.

## Étape 5 : Ouvrir la route vers les segments depuis le Pi

Le Pi reste la passerelle du réseau principal (`10.0.10.1`). Il doit savoir qu'il faut passer par OPNsense pour atteindre les segments :

Fenêtre de terminal
```bash
sudo ip route replace 10.0.30.0/24 via 10.0.10.204
sudo ip route replace 10.0.40.0/24 via 10.0.10.204
sudo ip route replace 10.0.50.0/24 via 10.0.10.204
ip route | grep "10.0."
```

> **Une route annoncée n'est pas une route active.** Ces commandes sont temporaires : elles disparaissent au redémarrage. La version permanente passera par `nmcli`, à faire plus tard.

## Étape 6 : Autoriser le trafic dans le pare-feu

Deux réglages bloquent le trafic par défaut. Il faut les connaître avant de créer la moindre règle.

### Décocher « Block private networks » sur le WAN

Sur **Interfaces → WAN**, l'option **Block private networks** bloque tout le trafic venant d'une adresse privée, avant même que vos règles soient lues. Or le Pi est en `10.0.10.1`. Décochez cette option, sinon le Pi ne pourra jamais joindre OPNsense.

### Créer les règles dans le bon ordre

OPNsense applique la première règle qui correspond. Pour chaque segment :

**Règles de `srv` (LAN)**

| Ordre | Action | Source | Destination | Protocole | Journal | Rôle |
|---|---|---|---|---|---|---|
| 1 | Pass | `LAN net` | `LAN address` | any | non | La passerelle répond |
| 2 | Block | `LAN net` | `10.0.0.0/8` | any | oui | Pas de passage entre segments |
| 3 | Pass | `LAN net` | any | any | non | Sortie vers Internet |

**Règles de `iot` (OPT1)**

| Ordre | Action | Source | Destination | Protocole | Port | Rôle |
|---|---|---|---|---|---|---|
| 1 | Pass | `OPT1 net` | `10.0.40.1` | TCP/UDP | 53 (DNS) | Résolution de noms |
| 2 | Pass | `OPT1 net` | any | TCP | 443 (HTTPS) | Sortie web |
| 3 | Block | `OPT1 net` | `10.0.0.0/8` | any | any | Pas de passage entre segments |

**Règles de `guest` (OPT2)**

| Ordre | Action | Source | Destination | Protocole | Journal | Rôle |
|---|---|---|---|---|---|---|
| 1 | Block | `OPT2 net` | `10.0.0.0/8` | any | oui | Pas de passage entre segments |
| 2 | Pass | `OPT2 net` | any | any | non | Sortie vers Internet |

> **Un piège fréquent.** Si vous choisissez **TCP** comme protocole, le ping ne passe pas. Mettez **any** pour les tests, et réservez les protocoles précis aux règles qui en ont besoin.

> **Un second piège.** Une règle **Block** sur `10.0.0.0/8` bloque aussi la passerelle `10.0.30.1`. C'est pour ça que la règle **Pass** vers `LAN address` doit être au-dessus.

## Étape 7 : Configurer le DHCP avec Kea

Kea a remplacé ISC DHCP dans OPNsense 26.7. La configuration se fait en deux temps.

### Activer Kea sur les trois interfaces

**Services → Kea DHCP → Settings** : cochez **Enable**, sélectionnez `LAN`, `OPT1` et `OPT2`, puis cochez **Firewall rules** pour ouvrir automatiquement le DHCP sur ces interfaces.

### Créer un sous-réseau par segment

**Services → Kea DHCP → Subnets**, avec les valeurs suivantes :

| Sous-réseau | Plage | Passerelle |
|---|---|---|
| `10.0.30.0/24` | `10.0.30.100` à `10.0.30.200` | `10.0.30.1` |
| `10.0.40.0/24` | `10.0.40.100` à `10.0.40.200` | `10.0.40.1` |
| `10.0.50.0/24` | `10.0.50.100` à `10.0.50.200` | `10.0.50.1` |

Gardez **Auto collect option data** coché : Kea remplit alors la passerelle à partir de l'interface. Laissez les champs DNS dynamique vides.

> **Une erreur de saisie fréquente.** Le sous-réseau doit être `10.0.50.0/24`, et non `10.0.50.1/24`. OPNsense accepte les deux, mais le DHCP ne fonctionne pas correctement avec la seconde.

**Test** : une machine branchée sur `srv` reçoit une adresse `10.0.30.1xx` avec la passerelle `10.0.30.1`.

## Étape 8 : Tester avec une VM

### Préparer une VM de test sur `srv`

Nous avons utilisé une VM Alpine Linux 3.24.3 (67 Mo), branchée sur `srv`. Dans cette VM, l'interface est désactivée au démarrage. Activez-la d'abord, puis demandez une adresse :

Fenêtre de terminal
```bash
ip link set eth0 up
udhcpc -i eth0 -n
ip a
```

BusyBox n'accepte pas `ip -br a`, d'où l'usage de `ip a`.

### Lire les résultats

- **DHCP** : la VM reçoit `10.0.30.101`. Validé.
- **Isolation** : le nœud (`10.0.10.148`) et le segment `iot` (`10.0.40.1`) ne répondent pas depuis `srv`. Validé.
- **Passerelle** : le ping vers `10.0.30.1` échouait avant l'ajout de la règle **Pass** vers `LAN address`. À revalider.
- **Internet** : la sortie vers `1.1.1.1` reste à valider après correction de la passerelle.

## Ce que cette base permet

Une fois ces huit étapes validées, vous avez un routeur qui distribue des adresses, isole les segments et laisse sortir l'Internet. Chaque segment se teste indépendamment des autres.

Un homelab sans sauvegarde n'est pas plus sûr qu'un homelab sans pare-feu : gardez les archives de configuration de px1 et du Pi à portée de main.

## Pourquoi commencer par les segments et non par l'administration

Le plan initial voulait déplacer l'administration sur OPNsense. Il exigeait de changer l'adresse du nœud et celle du Pi dans le bon ordre, sans filet de sécurité. Une seule étape mal ordonnée, et l'accès au nœud tombait. Le plan retenu laisse le nœud à `10.0.10.148` et ajoute OPNsense à côté : on peut ensuite basculer l'administration quand on la maîtrise.

## Les choix et leurs raisons

Chaque choix de ce guide répond à une contrainte précise. Le tableau donne la raison de la solution retenue et l'alternative qu'on a écartée.

### Architecture

| Choix | Raison | Alternative écartée |
|---|---|---|
| Garder le nœud sur le réseau principal (`10.0.10.148`) | Aucun changement d'adresse sur le nœud, donc aucun risque de couper l'accès | Déplacer l'administration sur OPNsense, qui exigeait une bascule risquée |
| Garder le Pi comme passerelle (`10.0.10.1`) | Le Pi fait déjà le travail et porte les services web | Le remplacer par OPNsense tout de suite, avec les coupures que cela implique |
| Ne pas créer le VNet `mgmt` pour l'instant | Il n'a de sens que pour une administration séparée, qui n'est pas encore en place | Créer `mgmt` maintenant, sans rien y connecter |
| Brancher OPNsense sur le réseau principal par son WAN | Le WAN reçoit une adresse du Pi, sans changer le câblage | Un petit réseau de transit (`10.255.0.0/24`) : il imposait de changer l'adresse du Pi |
| Segmenter par bridges SDN, sans VLAN | Il n'y a pas de switch managé, donc pas de VLAN possibles au niveau matériel | Des VLAN sur un switch managé, que le matériel ne permet pas |

### SDN et Proxmox

| Choix | Raison | Alternative écartée |
|---|---|---|
| Zone de type **Simple** | Suffit pour des bridges isolés, sans VLAN ni tunnel | Zone VLAN ou VXLAN, inutiles sans switch ni deuxième nœud |
| Sous-réseaux **sans passerelle** | Proxmox placerait sinon la passerelle sur le bridge de l'hôte, en conflit avec OPNsense | Une passerelle côté Proxmox, qui crée un doublon d'adresse |
| Mise à jour de Proxmox **reportée** | La connexion est lente, et la mise à jour n'est pas bloquante | La faire tout de suite, au risque d'un téléchargement interrompu |

### OPNsense

| Choix | Raison | Alternative écartée |
|---|---|---|
| Cartes **e1000** | Le nom des cartes (`em0`, `em1`…) est stable et simple à lire | **VirtIO**, plus rapide, mais avec des noms `vtnet` ; à envisager plus tard |
| Ordre des cartes fixé | OPNsense nomme les cartes selon leur ordre, donc on fixe l'ordre pour ne pas se tromper | Changer l'ordre à chaque modification |
| Système installé en **UFS** | Simple et léger pour un disque de 20 Go | **ZFS**, qui demande plus de mémoire et de configuration |
| WAN en **DHCP** | Le Pi distribue l'adresse, sans configuration manuelle des deux côtés | Une adresse statique, à réserver seulement si besoin |
| Décocher **Block private networks** sur le WAN | Le réseau du Pi est privé, donc cette option bloquerait tout | Garder l'option et ouvrir des exceptions une par une |
| Passer par **Kea DHCP** | ISC DHCP a disparu d'OPNsense 26.7 | Une ancienne configuration ISC, qui n'existe plus |
| Plage DHCP `.100` à `.200` | Les adresses `.1` à `.99` restent libres pour les équipements fixes | Une plage qui couvre tout le sous-réseau, avec risque de conflit |
| **Auto collect option data** activé | Kea prend la passerelle depuis l'interface, sans saisie supplémentaire | Saisir la passerelle à la main, avec risque d'erreur |

### Pare-feu

| Choix | Raison | Alternative écartée |
|---|---|---|
| Bloquer `10.0.0.0/8` avant de laisser sortir vers `any` | Chaque segment ne sort que vers Internet et ne voit pas les autres segments | Laisser passer tout le trafic et bloquer au cas par cas |
| Autoriser la passerelle (`LAN address`) au-dessus du blocage | Sans cela, le blocage empêche les machines de joindre leur propre passerelle | Une passerelle inaccessible, qui casse le DNS et le DHCP |
| Limiter `iot` au DNS vers OPNsense et au HTTPS | Les objets connectés ont une surface d'attaque réduite, et on ne leur ouvre que le nécessaire | Une sortie complète, que les objets connectés n'ont pas besoin d'avoir |
| Action **Block** plutôt que **Reject** | Le blocage est silencieux, donc un scan ne voit rien | **Reject**, qui répond à l'émetteur et renseigne un attaquant |
| Protocole **any** pour les tests | Le ping (ICMP) passe, ce qui simplifie le diagnostic | TCP seul, qui bloque les tests de connectivité |
| Journalisation sur les blocages | On voit ce qui est bloqué, pour corriger une règle sans deviner | Pas de journal, qui laisse les erreurs invisibles |

### Test et exploitation

| Choix | Raison | Alternative écartée |
|---|---|---|
| Vérifier le **SHA-256 de l'archive** `.bz2` | Le fichier de sommes publié porte sur l'archive, pas sur l'image décompressée | Décompresser sans vérifier, au risque d'une image corrompue |
| Route du Pi **temporaire** d'abord | On valide la route avant de la figer dans la configuration | La rendre permanente tout de suite, et devoir la défaire si elle est fausse |
| Alpine Linux pour le test | Une image de 67 Mo qui démarre en direct, sans installation | Installer une VM complète, plus lourde à télécharger et à supprimer |
| Tailscale pour l'accès distant | Déjà actif sur le Pi, avec des ACL par identité et aucun port ouvert | WireGuard, supprimé pour éviter deux accès concurrents |
| Pas d'exposition publique pour l'instant | Proxmox, OPNsense, Portainer et AdGuard ne doivent jamais être visibles depuis Internet | Ouvrir un port et découvrir le risque après coup |

## Ce qu'il faut retenir

- **Changez une chose à la fois**, et vérifiez-la avant de passer à la suivante.
- **Gardez un accès de secours** : console physique, ou Tailscale vers une machine indépendante.
- **Une adresse de passerelle sur un bridge hôte** peut créer un conflit dès qu'un autre équipement la reprend.
- **Le WAN bloque les adresses privées** si l'option est cochée, même avec une règle qui autorise.
- **Une règle `Block` générale** peut bloquer la passerelle elle-même : placez une règle `Pass` vers `LAN address` au-dessus.

## Prochaines étapes

- Valider la passerelle et la sortie Internet depuis la VM de test.
- Rendre les routes du Pi permanentes avec `nmcli`.
- Fixer l'adresse du WAN par une réservation DHCP.
- Configurer Unbound DNS sur les trois segments.
- Approuver les routes et définir les ACL dans Tailscale.
- Supprimer la VM de test une fois les tests terminés.
- Mettre à jour Proxmox vers 9.2.24.

Pour les procédures d'exploitation au quotidien, voir le handbook : `docs/handbook.md`.
