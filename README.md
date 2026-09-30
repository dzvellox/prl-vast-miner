# PRL Vast.ai Miner — BzMiner + Kryptex + failover réseau

Projet Linux/Vast.ai pour miner **Pearl (PRL)** avec **BzMiner**, envoyer les shares vers **Kryptex Pool**, créditer les gains sur un compte Kryptex et garder automatiquement le minage actif lorsqu'une route pool devient indisponible.

## Mineur utilisé

Le projet utilise désormais **uniquement BzMiner**.

SRBMiner a été complètement retiré :

- plus d'installation SRBMiner ;
- plus de probe SRBMiner ;
- plus de sélection automatique entre deux mineurs ;
- plus de logique SRBMiner dans le watchdog.

La version BzMiner est définie dans :

```text
scripts/miner-version.env
```

## Compte Kryptex

Dans `run.sh`, configure le Mining Username Kryptex :

```bash
KRYPTEX_MINING_USERNAME="krx..."
```

Le login envoyé à Kryptex est construit sous la forme :

```text
username/worker
```

Ne mets pas une adresse BNB dans cette variable. Le minage est crédité sur le compte Kryptex ; le retrait éventuel se fait ensuite depuis Kryptex.

## Routes pool et secours automatique

Route principale par défaut :

```text
stratum+tcp://prl.kryptex.network:7048
```

Routes de secours par défaut, dans cet ordre :

```text
stratum+ssl://prl.kryptex.network:8048
stratum+ssl://prl-eu.kryptex.network:8048
stratum+tcp://prl-eu.kryptex.network:7048
stratum+ssl://prl-us.kryptex.network:8048
stratum+tcp://prl-us.kryptex.network:7048
```

Cela permet notamment de continuer à miner si la route TCP globale `7048` est inaccessible : BzMiner peut alors passer au **SSL sur le port 8048**.

BzMiner reçoit toutes les routes dans une seule commande. La première est le primaire et les suivantes sont les pools de failover. Il peut donc basculer sans que le watchdog ait besoin de tuer et recréer le mineur juste pour changer de serveur.

### Changer la route principale

```bash
POOL_URL=stratum+ssl://prl.kryptex.network:8048 ./run.sh
```

### Personnaliser les routes de secours

Les URLs sont séparées par des virgules :

```bash
POOL_FALLBACKS="stratum+ssl://prl-eu.kryptex.network:8048,stratum+tcp://prl-eu.kryptex.network:7048" ./run.sh
```

### Désactiver les routes de secours

```bash
POOL_FALLBACKS="" ./run.sh
```

## Lancement

```bash
chmod +x run.sh check.sh status.sh stop.sh scripts/*.sh
./run.sh
```

Le script :

1. vérifie que les GPU NVIDIA sont visibles ;
2. crée un nom de worker compatible Kryptex ;
3. installe BzMiner si nécessaire ;
4. applique le profil OC lorsque les conditions sont réunies ;
5. lance BzMiner avec le primaire et les routes de secours ;
6. garde un watchdog autour du processus BzMiner ;
7. relance BzMiner s'il quitte complètement.

## Vérification réseau

```bash
./check.sh
```

Le check teste désormais **toutes les routes configurées** au lieu de vérifier uniquement le pool TCP principal. Ainsi une panne de `7048` n'est pas considérée comme bloquante si une route SSL ou régionale reste accessible.

## Statut

```bash
./status.sh
```

Le log principal est :

```text
logs/miner.log
```

## Arrêt

```bash
./stop.sh
```

Le watchdog est arrêté avec le mineur afin d'éviter un redémarrage automatique juste après l'arrêt volontaire.

## Overclock RTX 5090

Valeurs actuelles dans `run.sh` :

```text
core offset : +200 MHz
core lock   : 2490 MHz
memory lock : 7001 MHz
power limit : 575 W
```

Le profil est appliqué uniquement si les GPU visibles correspondent au modèle ciblé et si le processus dispose des droits nécessaires.

## Variables utiles

```text
KRYPTEX_MINING_USERNAME
POOL_URL
POOL_FALLBACKS
WORKER_NAME
MINER_BIN
OC_ENABLE
OC_TARGET_MODEL
OC_CORE_OFFSET
OC_LOCK_CORE
OC_LOCK_MEMORY
OC_POWER_LIMIT
RESTART_DELAY
MAX_RESTARTS
EXTRA_ARGS
```

## Structure

```text
run.sh
check.sh
status.sh
stop.sh
vast-onstart.sh
scripts/
  install_bzminer.sh
  miner-version.env
  watchdog.sh
```
