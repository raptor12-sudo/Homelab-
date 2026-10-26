# Raspberry Pi : DNS et routeur temporaire du homelab

Le Raspberry Pi héberge AdGuard Home, le DNS filtrant du réseau. En attendant pfSense sur le HP, il sert aussi de routeur au LAN homelab.

**Statut** : en place et vérifié le 2026-10-26 (voir `docs/journal.md`).

## Matériel et contexte

- Raspberry Pi 5, 8 Go de RAM, carte microSD 64 Go, Raspberry Pi OS (Bookworm, 64 bits).
- Le Pi est **partagé** : il fait aussi tourner la stack Docker du projet SaytuMbaye (InfluxDB, Grafana, MQTT). Les ports de cette stack sont réservés, en particulier le 3000 pris par Grafana.
- Il est connecté à la box en **Wi-Fi** (`wlan0`, `192.168.1.81`). Le port Ethernet (`eth0`) sert au LAN homelab.

## Pourquoi un DNS séparé du serveur

Si le serveur Proxmox tombe, le réseau doit continuer de résoudre les noms. Le Pi reste allumé en permanence, et sa panne n'empêche pas les autres machines de naviguer.

## Architecture actuelle

```
Box ~~~ Wi-Fi ~~~ wlan0 (192.168.1.81)
                     │
               [Raspberry Pi]  AdGuard Home + DHCP + NAT
                     │
                   eth0 (10.0.10.1/24) ── câble ── 1 appareil (pas encore de switch)
```

Le plan d'adressage `10.0.10.0/24` est provisoire, en attendant `network/addressing.md`.

## 1. AdGuard Home

Installation dans Docker : voir [`adguard/README.md`](adguard/README.md).

## 2. LAN homelab (routeur temporaire)

Le mode `shared` de NetworkManager attribue une IP fixe à `eth0`, lance un DHCP (dnsmasq) et fait du NAT vers le Wi-Fi. Aucun paquet supplémentaire n'est nécessaire.

1. **DNS du LAN vers AdGuard** : copier [`lan/adguard.conf`](lan/adguard.conf).

   ```bash
   sudo cp lan/adguard.conf /etc/NetworkManager/dnsmasq-shared.d/
   ```

2. **Autoriser le routage malgré Docker**, qui met la politique `FORWARD` en `DROP` : copier [`lan/90-homelab-forward`](lan/90-homelab-forward). NetworkManager l'exécute chaque fois que `eth0` monte.

   ```bash
   sudo install -m 755 lan/90-homelab-forward /etc/NetworkManager/dispatcher.d/
   ```

3. **Créer le réseau** :

   ```bash
   sudo nmcli connection add type ethernet ifname eth0 con-name homelab-lan \
     ipv4.method shared ipv4.addresses 10.0.10.1/24 ipv6.method disabled
   ```

   La connexion ne démarre que lorsqu'un câble est branché. Si une adresse manuelle traîne sur `eth0` (`ip -br addr show eth0`), NetworkManager considère l'interface comme `external` et ne démarre rien : la retirer avec `sudo ip addr del <adresse> dev eth0`, puis lancer `sudo nmcli connection up homelab-lan`.

4. **Stabiliser le Wi-Fi**, puisque la sortie Internet en dépend :

   ```bash
   sudo nmcli connection modify "<nom-du-wifi>" 802-11-wireless.powersave 2
   ```

Retour arrière : `sudo nmcli connection delete homelab-lan`, puis supprimer les deux fichiers copiés.

## Vérification

Depuis un poste branché en câble sur le Pi :

- Le poste reçoit une adresse `10.0.10.x`, avec `10.0.10.1` comme routeur et comme DNS.
- `dig @10.0.10.1 example.com` répond, et `dig @10.0.10.1 doubleclick.net` renvoie `0.0.0.0`.
- `traceroute 1.1.1.1` passe par `10.0.10.1`, puis par la box.

## Limites connues

- Sans switch, un seul appareil peut être branché sur le LAN.
- La sortie Internet passe par le Wi-Fi : le débit et la stabilité dépendent du signal.
- Après un redémarrage du Pi, la règle `DOCKER-USER` peut échouer si Docker n'a pas encore démarré. Débrancher puis rebrancher le câble la réapplique. Le redémarrage n'a pas encore été testé.

## `bootstrap.sh` : non appliqué sur ce Pi

`bootstrap.sh` prépare un Pi **neuf et dédié** : compte admin, SSH par clé uniquement, pare-feu ufw. Il n'a pas été lancé sur ce Pi, parce qu'il est partagé avec SaytuMbaye : changer le nom d'hôte, l'accès SSH ou le pare-feu le perturberait. Il reste utile si le DNS passe un jour sur un Pi dédié.

Attention : sur un hôte Docker, ufw ne filtre pas les ports publiés par les conteneurs, parce que Docker insère ses propres règles avant celles d'ufw. C'est pour cette raison que les ports d'AdGuard sont liés à l'IP locale dans `compose.yaml`.

## Ce qui reste à décider

- Plan d'adressage définitif (`network/addressing.md`).
- Serveurs DNS en amont : DNS-over-HTTPS ou DNS-over-TLS.
- Exposition IPv6 des services SaytuMbaye, qui écoutent sur `[::]` alors que le Pi a une IPv6 publique.
- Passage en Ethernet vers pfSense quand le HP sera en service. Le Pi redeviendra alors uniquement le DNS.
