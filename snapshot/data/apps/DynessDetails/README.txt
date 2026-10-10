DynessDetails v5 – Venus OS v3.80~39 GUI v2
Fix erreur ligne 56 v4 "Cannot assign to non-existent property text":
Remplace les 7 sections ListItem { text: ... } par ListText natif.
Conserve GradientListView, le passage de device.serviceUid et tous les chemins D-Bus.
Lecture seule : aucun changement au pilote CAN, RS485 ou DVCC.

Transfert scp / installation (depuis Venus OS):
  unzip -o /data/dyness_details_venus_v5.zip -d /data/apps/DynessDetails
  sh /data/apps/DynessDetails/install.sh

Retour arriere:
  sh /data/apps/DynessDetails/disable.sh
