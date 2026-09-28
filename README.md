# PRL Vast.ai Miner — Kryptex → BNB — RTX 5090 OC

Projet Linux/Vast.ai prêt à lancer pour miner **Pearl (PRL)** avec **BzMiner** ou **SRBMiner-MULTI**, envoyer les shares vers **Kryptex Pool**, créditer les gains sur ton **compte Kryptex**, puis retirer le solde en **BNB sur BNB Smart Chain (BEP20)**.

> Important : pour recevoir en BNB via Kryptex, **ne mets pas une adresse PRL ni une adresse BNB dans BzMiner**. Le mineur doit utiliser ton **Mining Username Kryptex** (`krx...`). Le retrait BNB se fait ensuite depuis ton compte Kryptex.

## 🚀 Lancement rapide sur Vast.ai

### 1. Vérifier le compte Kryptex

Avant de démarrer, vérifie l'identifiant de minage configuré dans `run.sh`. Le dépôt est public : tout identifiant inscrit dans les fichiers publiés est visible par tous. N'y ajoute jamais de mot de passe, de clé API, de seed phrase ou de clé privée.

### 2. Mettre le projet sur GitHub

Le dépôt est disponible à l'adresse `https://github.com/dzvellox/prl-vast-miner`.

### 3. Commande à copier dans le terminal Vast.ai

```bash
git clone https://github.com/dzvellox/prl-vast-miner.git && \
cd prl-vast-miner && \
chmod +x *.sh scripts/*.sh && \
./run.sh
```

Ensuite le script :

1. détecte tous les GPU NVIDIA visibles ;
2. teste SRBMiner-MULTI v3.7.0 si le profil RTX 5090 est éligible ; sinon installe BzMiner v100.40 ;
3. vérifie le SHA-256 de l'archive officielle du mineur choisi ;
4. configure Pearl ;
5. se connecte au pool PRL Kryptex ;
6. utilise ton Mining Username Kryptex ;
7. crée automatiquement un nom de worker compatible Kryptex ;
8. applique le profil RTX 5090 si les conditions le permettent ;
9. lance le mineur choisi et le redémarre automatiquement s'il plante.

Sur une instance existante, mets le dépôt à jour puis relance `./run.sh` : SRBMiner est testé si le profil RTX 5090 est éligible ; BzMiner reste disponible en repli. Les installateurs vérifient la version et l'archive de chaque mineur. Un binaire personnalisé fourni par `MINER_BIN` n'est pas remplacé.

```bash
cd /root/prl-vast-miner && git pull --ff-only && ./stop.sh && ./run.sh
```

### 4. Commande Vast.ai On-start

Pour démarrer automatiquement au boot de l'instance :

```bash
bash -lc 'DIR=/root/prl-vast-miner; REPO=https://github.com/dzvellox/prl-vast-miner.git; if [ -d "$DIR/.git" ]; then git -C "$DIR" pull --ff-only; else git clone "$REPO" "$DIR"; fi; chmod +x "$DIR"/*.sh "$DIR"/scripts/*.sh; exec "$DIR/run.sh"'
```

Si ton dépôt est privé, il faudra fournir une méthode d'authentification GitHub. Pour un lancement sans interaction, un dépôt public est plus simple. Le Mining Username Kryptex est un identifiant de minage ; **ne mets jamais de mot de passe, seed phrase, clé privée ou clé API dans le dépôt**.

---

# 💰 Comment PRL → BNB fonctionne avec Kryptex

Le chemin est :

```text
GPU Vast.ai
   ↓
SRBMiner ou BzMiner / Pearl
   ↓
Kryptex PRL Pool
   ↓
Mining Username Kryptex (krx...)
   ↓
Auto-exchange / crédit sur ton compte Kryptex
   ↓
Retrait BNB
   ↓
Ton adresse BNB Smart Chain (BEP20)
```

Kryptex indique que le mode de minage vers un compte utilise le **Mining Username** à la place de l'adresse de wallet. Les gains sont crédités sur le compte Kryptex et peuvent ensuite être retirés dans différents moyens, dont **BNB (Smart Chain)**.

Au moment de cette version du projet, la page de frais Kryptex affiche pour BNB :

```text
Réseau / paiement : BNB (Smart Chain)
Retrait minimum    : 0.002 BNB
Frais de retrait   : 0.001 BNB
```

Ces seuils/frais peuvent changer : vérifie toujours la page Kryptex avant un retrait important.

## Retirer en BNB

Quand ton compte Kryptex a assez de solde :

1. ouvre les paiements/retraits Kryptex ;
2. sélectionne **BNB** ;
3. utilise une adresse qui accepte **BNB Smart Chain / BEP20** ;
4. vérifie soigneusement le réseau et l'adresse ;
5. demande le retrait.

L'adresse BNB **n'est pas nécessaire dans `run.sh`**.

---

# ⛏️ Configuration Kryptex utilisée

Pool global PRL :

```text
stratum+tcp://prl.kryptex.network:7048
```

BzMiner est lancé dans le format recommandé par Kryptex :

```bash
bzminer \
  -a pearl \
  -p stratum+tcp://prl.kryptex.network:7048 \
  -w KRYPTEX_MINING_USERNAME/WORKER \
  --nvidia 1 \
  --amd 0 \
  --intel 0 \
  --igpu 0 \
  --cpu 0 \
  --cpu_threads 0 \
  --nc 1
```

Le projet est configuré en **PPS+**, pas en SOLO. Aucun préfixe `solo:` n'est utilisé.

## Régions Kryptex PRL

Le script utilise **uniquement le pool Global par défaut** (`prl.kryptex.network:7048`). C’est volontaire : comme l’emplacement de la machine Vast.ai peut changer, aucune région n’est choisie automatiquement. Les adresses régionales ci-dessous restent seulement disponibles si tu veux les forcer manuellement.

```text
Global        prl.kryptex.network:7048
Europe        prl-eu.kryptex.network:7048
Amérique N.   prl-us.kryptex.network:7048
Amérique S.   prl-br.kryptex.network:7048
Singapour     prl-sg.kryptex.network:7048
Hong Kong     prl-hk.kryptex.network:7048
Russie        prl-ru.kryptex.network:7048
Moyen-Orient  prl-ae.kryptex.network:7048
```

Par exemple, pour forcer l'Europe :

```bash
POOL_URL=stratum+tcp://prl-eu.kryptex.network:7048 ./run.sh
```

Kryptex propose aussi SSL sur le port `8048`.

---

# Sélection automatique du mineur

Avec le profil RTX 5090 demandé et un processus root, `./run.sh` télécharge **SRBMiner-MULTI 3.7.0** depuis sa release officielle et vérifie le SHA-256 de l'archive Linux. Il lance un essai de **120 secondes au maximum** sur Kryptex avec :

```text
--gpu-coffset0 200 --gpu-cclock0 2490 --gpu-mclock0 7001 --gpu-plimit0 575
```

SRBMiner est retenu si `nvidia-smi` montre la limite de puissance et les fréquences attendues sur **tous** les GPU visibles **et** si le journal indique une share acceptée. Son identifiant de minage est envoyé sous la forme `identifiant.worker`, comme dans la commande Kryptex. Si l'essai échoue ou qu'aucune share n'arrive à temps, le projet démarre BzMiner. Le décalage du cœur (+200 MHz) ne peut pas être confirmé indépendamment par cette télémétrie.

Kryptex prend officiellement en charge **SRBMiner** et **BzMiner** pour Pearl. Les détails de l'essai sont dans `logs/srbminer-probe.log`, puis l'activité du mineur sélectionné dans `logs/miner.log`.

Forcer BzMiner sans essai SRBMiner :

```bash
SRBMINER_AUTO=0 ./run.sh
```

Changer la durée de l'essai (30 à 300 secondes) :

```bash
SRBMINER_TRIAL_SECONDS=180 ./run.sh
```

# 🔥 Profil RTX 5090 intégré

Le profil demandé est :

```text
Core offset : +200 MHz
Core lock   : 2490 MHz
Memory lock : 7001 MHz
Power limit : 575 W
```

BzMiner reçoit :

```bash
--oc-core-clock-offset 200 \
--oc-lock-core-clock 2490 \
--oc-lock-memory-clock 7001 \
--oc-power-limit 575
```

Sécurités intégrées :

- le profil n'est appliqué automatiquement que si **tous les GPU visibles sont des RTX 5090** ;
- le script doit être exécuté en root pour tenter les réglages sous Linux ;
- si Vast.ai ou le driver bloque la modification des clocks/power limit, le projet ne cherche pas à contourner cette restriction ;
- un autre modèle de GPU ne reçoit pas automatiquement ce profil 575 W.

Désactiver l'OC :

```bash
OC_ENABLE=0 ./run.sh
```

Changer seulement la puissance :

```bash
OC_POWER_LIMIT=500 ./run.sh
```

---

# 🧪 Vérifier avant de miner

```bash
./check.sh
```

Le script vérifie notamment :

- `nvidia-smi` ;
- le nombre de GPU visibles ;
- l'accès root ;
- la résolution DNS de Kryptex ;
- l'accès au port du pool ;
- la présence de BzMiner.

# 📊 Voir le statut

```bash
./status.sh
```

Ou directement :

```bash
nvidia-smi
```

Suivre le log :

```bash
tail -f logs/miner.log
```

# 🛑 Arrêter

```bash
./stop.sh
```

Le watchdog est arrêté en même temps pour éviter que BzMiner redémarre juste après.

---

# Worker Kryptex

Kryptex demande un nom de worker de maximum 32 caractères, avec lettres latines et chiffres, sans espaces/caractères spéciaux.

Le projet transforme automatiquement le hostname Vast.ai en worker valide. Tu peux également forcer ton propre nom :

```bash
WORKER_NAME=Vast5090A ./run.sh
```

# Sources de configuration

- Pool Pearl Kryptex : https://pool.kryptex.com/prl
- Guide Pearl Kryptex : https://pool.kryptex.com/articles/how-to-mine-pearl-en
- Miners Pearl / configuration BzMiner : https://pool.kryptex.com/articles/pearl-miners-en
- Minage vers un compte Kryptex : https://pool.kryptex.com/fr/articles/account-mining-fr
- Frais/retraits Kryptex : https://www.kryptex.com/fr/fees
- BzMiner releases : https://github.com/bzminer/bzminer/releases

