# AdGuard Home

AdGuard Home tourne dans Docker sur le Pi. Docker y était déjà installé pour la stack SaytuMbaye : le conteneur évite de toucher au système et isole AdGuard des autres services.

## Installation

Sur le Pi, dans un dossier séparé de SaytuMbaye :

```bash
mkdir -p ~/adguard && cd ~/adguard
# copier ici le fichier compose.yaml de ce dossier, puis :
docker compose up -d
docker compose ps    # le conteneur adguardhome doit être « Up »
```

Choix faits dans [`compose.yaml`](compose.yaml) :

- **Ports liés à `192.168.1.81`** plutôt qu'à toutes les interfaces. Le Pi a une IPv6 publique : un DNS ouvert sur Internet serait exploité pour des attaques par amplification.
- **L'assistant d'installation est sur le port 3001**, parce que le 3000 est pris par Grafana.
- **L'interface web est sur le port 8080** : le port 80 de l'hôte reste libre pour un futur reverse proxy.
- **Image `latest`** pour la première installation. À figer sur la version en service une fois validée.

## Premier démarrage

1. Ouvrir `http://192.168.1.81:3001` depuis le réseau local.
2. Dans l'assistant, garder le port **80** pour l'interface web et le port **53** pour le DNS. Ce sont les ports *dans* le conteneur : Docker les publie sur 8080 et 53.
3. Créer le compte administrateur avec un mot de passe fort, stocké dans un gestionnaire de mots de passe.
4. L'assistant se ferme ensuite : l'interface est sur `http://192.168.1.81:8080`.

Le port 3001 ne répond plus après l'installation, c'est normal. On peut retirer sa ligne de `compose.yaml`.

## Vérification

```bash
dig @192.168.1.81 example.com       # doit répondre une adresse
dig @192.168.1.81 doubleclick.net   # doit répondre 0.0.0.0 (bloqué)
docker logs --tail 20 adguardhome
```

## Sauvegarde de la configuration

La configuration se trouve dans `~/adguard/conf/AdGuardHome.yaml`, sur le Pi. Le script `export-config.sh` la copie sans la section des utilisateurs, qui contient les mots de passe hachés.

```bash
./export-config.sh                                  # chemin par défaut
ADGUARD_CONF=/autre/chemin.yaml ./export-config.sh  # si le dossier diffère
```

Relire le fichier produit avant tout commit : il ne doit contenir aucun secret.

## Restauration

Arrêter AdGuard, remettre la sauvegarde, redémarrer, puis recréer le compte administrateur, qui n'est pas dans la sauvegarde. Tant qu'aucun compte n'existe, l'interface web n'est pas protégée : la recréer tout de suite.

```bash
cd ~/adguard
docker compose down
cp AdGuardHome.yaml.sanitized conf/AdGuardHome.yaml
docker compose up -d
```
