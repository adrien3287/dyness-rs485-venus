# Dyness PowerHaus RS485 → Venus OS

**Sauvegarde source du lecteur Dyness PowerHaus fonctionnel, issue du Raspberry Pi le 10 octobre 2026.**

Ce dépôt regroupe les fichiers exécutés sur un Raspberry Pi 3B+ sous **Venus OS v3.80~39**, pour deux modules **Dyness PowerHaus 5.12 kWh**, adresses RS485 `0x02` (master) et `0x03` (slave).

> **Sécurité : RS485 = supervision uniquement.** Le **CAN `can8` reste le BMS de contrôle** du système Victron/DVCC. Ne jamais sélectionner les batteries RS485 ni l'agrégateur comme BMS de contrôle. Les limites RS485 de contrôle restent volontairement à zéro et ne représentent **pas** les autorisations réelles du BMS.

## Contenu

| Répertoire | Contenu |
|---|---|
| `snapshot/data/apps/dbus-serialbattery/` | Installation Python d'origine, dépendances locales, driver `bms/dyness_powerhaus.py`, parser `bms/dyness_powerhaus_protocol.py`, `config.ini`, modifications `dbushelper.py` |
| `snapshot/data/apps/dyness_powerhaus_v0_2/` | Agrégateur (`aggregate_dbus.py`), calcul TimeToGo (`energy.py`), services runit et `startup.sh` |
| `snapshot/data/apps/DynessDetails/` | Plugin GUI v2 personnalisé **v5**, avec diagnostics de charge/décharge et états MOSFET |
| `snapshot/data/apps/available/SerialbatteryGui/gui-v2/` | Plugin officiel précompilé, renommé en `SerialbatteryGui.json` pour FlashMQ |
| `snapshot/data/rc.local`, `snapshot/u-boot/`, `snapshot/etc/inittab` | **Références de configuration** seulement : ne pas écraser les fichiers OS sur une autre machine |
| `scripts/` | Préparation, activation contrôlée, diagnostics et création d'un hook de démarrage optionnel |
| `MANIFEST.sha256` | Empreintes des fichiers extraits de l'archive d'origine |

L'archive brute fournie à ChatGPT comprenait également des **caches `__pycache__`, journaux runtime, anciens backups, état `supervise` et anciennes distributions WebAssembly (~43 Mo)**. Ils ne sont pas nécessaires pour réinstaller et sont exclus de ce dépôt source. Voir `INVENTORY.json`. Les fichiers fonctionnels et les dépendances Python incluses ont été conservés sans modification.

## Architecture et câblage

- Raspberry Pi 3B+, Waveshare CAN/RS485 HAT Rev2.1.
- **CAN:** contrôleur MCP2515 renommé `can8` au niveau de l'OS, 500 kbit/s. Le CAN contrôle réellement la charge et la décharge via Victron. **Le renommage `can0`→`can8` et la configuration CAN ne sont pas sauvegardés intégralement dans cette archive : reconstruire et vérifier sur la machine cible.**
- **RS485:** `/dev/ttyAMA0`, `9600 8N1`, adresses `0x02` et `0x03`.
- Boot Raspberry Pi de référence : `enable_uart=1`, `dtoverlay=miniuart-bt` et overlay MCP2515 ; console `ttyAMA0` désactivée dans `/etc/inittab` ; `/u-boot/cmdline.txt` sans console série.
- Les valeurs physiques des tensions cellule 16 sont reconstruites depuis la tension du pack et 15 valeurs cellule : **l'index réel de la cellule absente reste à vérifier**.

## Choisir le port série RS485

Le port est paramétrable **à l'installation** (par défaut `/dev/ttyAMA0`, comme sur le Raspberry Pi d'origine).

```sh
sh scripts/install.sh --port /dev/ttyUSB0
# ou, pour reproduire exactement la configuration d'origine :
sh scripts/install.sh --port /dev/ttyAMA0
```

L'installateur génère `/data/apps/dyness_powerhaus_v0_2/serial-port.conf`, configure les noms D-Bus de l'agrégateur pour les deux adresses `0x02` et `0x03`, et installe un script de démarrage qui crée le service runit `dbus-serialbattery.<nom-du-port>`. Le port sélectionné est également utilisé par `scripts/activate.sh` et `scripts/check.sh`. Ports pris en charge : `ttyUSBn`, `ttyACMn`, `ttyAMAn` et `ttySn` (numéros décimaux). Pour les adaptateurs USB, vérifier la numérotation après redémarrage.

**Changer le port après activation :** arrêter et retirer proprement l'ancien service runit avant de lancer `sh scripts/configure-port.sh /dev/ttyUSB1`, puis `sh scripts/activate.sh`. Ne pas effectuer ce changement sur un système opérationnel sans plan de retour arrière : les services déjà enregistrés sont volontairement protégés.

La branche `snapshot/` demeure un **instantané immuable** et conserve `ttyAMA0`. Les scripts d'installation appliquent les réglages à la copie installée dans `/data/apps`. Les autres prérequis (UART, console série, CAN can8) restent à configurer sur la machine cible. Cette fonctionnalité n'a pas encore été validée sur un second appareil Venus OS.

## Installation sur un nouveau Venus OS

1. Installer d'abord Venus OS compatible, le CAN MCP2515, le renommage `can8`, et confirmer le pilotage CAN **sans brancher le RS485 comme BMS de contrôle**.
2. Activer physiquement l'UART RS485 sur `/dev/ttyAMA0`, désactiver la console série sur ce port, vérifier le câblage A/B, 9600 8N1.
3. Copier ce dépôt entier sur le Raspberry Pi, par exemple dans `/data/dyness-rs485-venus/` (via `scp` ou `git clone`).
4. Exécuter depuis la racine du dépôt :

```sh
sh scripts/install.sh --port /dev/ttyAMA0
```

L'installateur **refuse par défaut d'écraser** une installation `dbus-serialbattery` existante. Les réglages OS (`/u-boot/config.txt`, `/etc/inittab`, `/data/rc.local`) ne sont **jamais écrasés**. Les dossiers sources sont copiés et une copie de sauvegarde est faite avant toute mise à jour explicite.

5. Vérifier la configuration et le fonctionnement côté CAN. Ensuite, seulement après cette vérification :

```sh
sh scripts/activate.sh
```

Cela enregistre les services runit du RS485 et de l'agrégateur et active les plugins GUI. Cela **n'installe pas de hook de démarrage** automatiquement. Après validation d'un démarrage/arrêt manuel, installer le hook optionnel :

```sh
sh scripts/install-boot-hook.sh
```

**Attention au système source :** `snapshot/data/rc.local` présente deux lancements distincts de `enable.sh`, probablement une duplication accidentelle. **Ne jamais recopier ce fichier de référence tel quel.** Le nouveau hook crée une seule séquence. Il préserve les autres commandes `rc.local` et sauvegarde l'original.

## Vérification après installation

```sh
sh scripts/check.sh
```

Règles attendues : les deux services RS485 affichent leurs SOC, autorisations BMS réelles dans `/Diagnostics/BmsChargeAllowed` et `/Diagnostics/BmsDischargeAllowed`; l'agrégateur `com.victronenergy.battery.dynesspowerhausbank` est connecté ; **le contrôle reste au CAN** (`com.victronenergy.battery.socketcan_can8`).

GUI v2 (console distante) : `Settings` → `Devices` → `PowerHaus RS485 02/03` → **Dyness - Etat BMS reel (RS485)**. Le plugin officiel ajoute également ses pages à chaque batterie. FlashMQ exige que le **fichier JSON porte le nom du dossier applicatif** (`SerialbatteryGui/SerialbatteryGui.json`).

## Ce qui n'est PAS résolu

- `Balancing` réel et état par cellule **non décodés** : `/Balancing=0` et `/Balances/Cell*=0` peuvent être des valeurs par défaut, non une mesure.
- Décodage exhaustif des alarmes propriétaires, du dernier octet statut `0x44`, et stabilité prolongée de l'agrégateur : à valider.
- Les chemins `Io/AllowToCharge` / `Io/AllowToDischarge` des services RS485 sont neutralisés **volontairement**. Les valeurs utiles se trouvent sous `/Diagnostics/`.

## Maintenance / licence

Code tiers provenant de [mr-manuel/venus-os_dbus-serialbattery](https://github.com/mr-manuel/venus-os_dbus-serialbattery), avec fichiers de licence upstream conservés. Ce dépôt est une capture personnalisée, non une publication officielle Victron/Dyness. Vérifier les licences de chaque bibliothèque tierce et conserver leurs notices. Ne pas publier de logs contenant des informations privées ni de secrets dans `config.ini`.

## Retour arrière

```sh
sh snapshot/data/apps/DynessDetails/disable.sh
svc -d /service/dbus-dynesspowerhaus-bank
svc -d /service/dbus-serialbattery.ttyAMA0
```

Ne pas supprimer le pilote CAN ni modifier DVCC pour effectuer ce retour arrière.
