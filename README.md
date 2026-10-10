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

Le dépôt vient d'être initialisé. **Les fichiers réellement exécutés sur le Raspberry Pi ne sont pas encore importés.** Ils doivent être exportés depuis cette machine avant de pouvoir annoncer une sauvegarde complète et écrire un installateur reproductible. Le script d'export est fourni dans [tools/export-from-venus.sh](tools/export-from-venus.sh).

## Exporter l'installation actuelle

Sur le Venus OS **source**, exécuter :

```sh
wget -O /data/export-dyness.sh https://raw.githubusercontent.com/adrien3287/dyness-rs485-venus/main/tools/export-from-venus.sh
sh /data/export-dyness.sh
```

Le script affiche le chemin de l'archive `/data/dyness-venus-export-*.tar.gz`. Transférer cette archive pour analyse/import ; ne pas publier directement sans la vérifier.

L'export récupère les fichiers spécifiques du pilote, du parseur, de l'agrégateur, des services et des interfaces graphiques. Les paramètres dont le nom évoque un secret sont masqués dans `config.ini`. Les journaux et clés privées sont exclus.

## Réinstallation sur un autre Venus OS

**À documenter après l'import de la sauvegarde réelle** : version de `dbus-serialbattery` épinglée, câblage CAN/RS485, configuration UART, installation des fichiers, intégration avec les services existants, activation GUI et contrôles de non-régression.

Pour l'instant **ne pas utiliser ce dépôt comme installateur complet**.

## Périmètre et limites

Les chemins `/Diagnostics/BmsChargeAllowed`, `/Diagnostics/BmsDischargeAllowed`, `/Diagnostics/BmsChargeMosOn` et leurs homologues proviennent des trames BMS. Le balancing réel n'est pas encore décodé : `/Balancing=0` et `/Balances/CellN=0` ne prouvent pas que l'équilibrage soit inactif.

Ce travail contient une intégration expérimentale : toute migration doit être testée sans perdre le contrôle CAN et les protections matérielles du fabricant.

## Licences

`dbus-serialbattery`, Venus OS et les éventuelles ressources tierces appartiennent à leurs auteurs respectifs. La provenance et les licences seront documentées au moment de l'import des fichiers exacts.
