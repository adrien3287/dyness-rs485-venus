# Dyness PowerHaus RS485 → Victron Venus OS

Sauvegarde et projet de réinstallation de la supervision **Dyness PowerHaus** pour Victron Venus OS.

## Configuration de référence (10 octobre 2026)

- Venus OS `v3.80~39`, Raspberry Pi 3B+.
- Deux batteries Dyness PowerHaus 5,12 kWh : module **02** (Master) et **03** (Slave).
- CAN `can8` (500 kbit/s) : **BMS principal**, gestion DVCC et sécurité Victron.
- RS485 `/dev/ttyAMA0` (9600, 8N1) : **supervision en lecture seule**, via `dbus-serialbattery`.
- Services distincts `com.victronenergy.battery.ttyAMA0__0x02` et `...__0x03`.
- Agrégateur d'observation `com.victronenergy.battery.dynesspowerhausbank`, instance 40.
- Pages Venus OS GUI v2 : plugin officiel `dbus-serialbattery` et plugin personnalisé `DynessDetails v5`.

**Important :** le pilotage CAN doit rester prioritaire. Ne pas utiliser les valeurs de courant 0 A du service RS485 comme limites BMS réelles : elles sont neutralisées intentionnellement pour éviter de prendre le contrôle DVCC.

### État du projet

**La sauvegarde réelle a été reçue, inspectée et conditionnée** le 10 octobre 2026 : 289 fichiers opérationnels et dépendances, plus scripts de réinstallation. Cependant, **les fichiers restent à importer dans ce dépôt** : tant que `snapshot/`, `scripts/` et `MANIFEST.sha256` ne sont pas sur `main`, le dépôt GitHub n'est PAS encore une sauvegarde complète. L'archive préparée est disponible dans le chat ChatGPT comme `dyness-rs485-venus-source.zip`.

## Importer la sauvegarde préparée sur GitHub

Sur Windows, télécharger dans la conversation ChatGPT le fichier `dyness-rs485-venus-source.zip`. Une fois Git pour Windows installé et l'accès GitHub configuré, lancer :

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\import-source.ps1 -ZipPath .\dyness-rs485-venus-source.zip
```

Le script [tools/import-source.ps1](tools/import-source.ps1) doit être téléchargé depuis GitHub ou exécuté dans un clone de ce dépôt. Il clone le dépôt dans `%TEMP%`, vérifie les fichiers indispensables, demande confirmation avant toute publication, puis effectue `git push origin main`. Comme le dépôt est public, vérifier son contenu avant de confirmer.

Un workflow [Validate Dyness Venus OS backup](.github/workflows/validate.yml) vérifie les empreintes SHA256, les modules Python et les manifestes GUI lors de l'import.

## Exporter l'installation actuelle (facultatif — déjà reçu)

Sur le Venus OS **source**, exécuter :

```sh
wget -O /data/export-dyness.sh https://raw.githubusercontent.com/adrien3287/dyness-rs485-venus/main/tools/export-from-venus.sh
sh /data/export-dyness.sh
```

Le script affiche le chemin de l'archive `/data/dyness-venus-export-*.tar.gz`. Transférer cette archive pour analyse/import ; ne pas publier directement sans la vérifier.

L'export récupère les fichiers spécifiques du pilote, du parseur, de l'agrégateur, des services et des interfaces graphiques. Les paramètres dont le nom évoque un secret sont masqués dans `config.ini`. Les journaux et clés privées sont exclus.

## Réinstallation sur un autre Venus OS

Le paquet préparé contient des scripts d'installation (`scripts/install.sh`), d'activation (`scripts/activate.sh`), de vérification (`scripts/check.sh`) et de configuration du démarrage (`scripts/install-boot-hook.sh`). Ils seront disponibles sur GitHub après l'import. Ils n'écrasent pas automatiquement `/u-boot/config.txt`, `/etc/inittab` ou `/data/rc.local`.

**Ne pas utiliser le dépôt comme installateur complet tant que ces fichiers n'ont pas été importés et vérifiés.**

## Périmètre et limites

Les chemins `/Diagnostics/BmsChargeAllowed`, `/Diagnostics/BmsDischargeAllowed`, `/Diagnostics/BmsChargeMosOn` et leurs homologues proviennent des trames BMS. Le balancing réel n'est pas encore décodé : `/Balancing=0` et `/Balances/CellN=0` ne prouvent pas que l'équilibrage soit inactif.

Ce travail contient une intégration expérimentale : toute migration doit être testée sans perdre le contrôle CAN et les protections matérielles du fabricant.

## Licences

`dbus-serialbattery`, Venus OS et les éventuelles ressources tierces appartiennent à leurs auteurs respectifs. La provenance et les licences seront documentées au moment de l'import des fichiers exacts.
