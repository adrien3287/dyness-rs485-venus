// Dyness PowerHaus: lecture seule via le BMS RS485.
// Plugin GUI v2, intégré aux appareils ProductId 0xBA77.
import QtQuick
import Victron.VenusOS

// GUIv2 device-list integration (type 2) passes 'device' to a Page component.
Page {
    id: root
    title: "Dyness – État BMS réel (RS485)"
    // DevicePage (GUIv2) passe un objet "device" dans pushPage().
    // Ne pas utiliser DeviceListPluginPage : peut être indisponible en Venus OS 3.80~39.
    property var device: null
    readonly property string bindPrefix: (device && device.serviceUid) ? device.serviceUid : ""

    function valueText(item, kind) {
        if (!item || !item.valid || item.value === null || item.value === undefined)
            return "—"
        var v = item.value
        if (Array.isArray(v) && v.length === 0)
            return "—"
        if (kind === "raw") return String(v)
        var n = Number(v)
        if (!isFinite(n)) return "—"
        if (kind === "bool") return n === 1 ? "Oui" : "Non"
        if (kind === "connected") return n === 1 ? "Connecté" : "Déconnecté"
        if (kind === "alarm") return n === 0 ? "Aucune" : n === 1 ? "Avertissement" : n === 2 ? "Alarme" : String(n)
        if (kind === "hex") return "0x" + n.toString(16).toUpperCase().padStart(2, "0")
        if (kind === "int") return String(Math.round(n))
        return String(v)
    }

    VeQuickItem { id: socItem; uid: root.bindPrefix + "/Soc" }
    VeQuickItem { id: voltItem; uid: root.bindPrefix + "/Dc/0/Voltage" }
    VeQuickItem { id: currentItem; uid: root.bindPrefix + "/Dc/0/Current" }
    VeQuickItem { id: powerItem; uid: root.bindPrefix + "/Dc/0/Power" }

    // GradientListView fournit les lignes, la navigation clavier et la barre
    // de défilement natives de Venus OS (contrairement à notre ancien Flickable).
    GradientListView {
        model: VisibleItemModel {
            // Lignes compactes natives Victron (sans ListItem.content).
            // La v3 ne s'ouvrait pas: "Cannot assign to non-existent property content".
            ListQuantityGroup {
                text: "Overview"
                model: QuantityObjectModel {
                    QuantityObject { object: socItem; unit: VenusOS.Units_Percentage }
                    QuantityObject { object: voltItem; unit: VenusOS.Units_Volt_DC }
                    QuantityObject { object: currentItem; unit: VenusOS.Units_Amp }
                    QuantityObject { object: powerItem; unit: VenusOS.Units_Watt }
                }
            }
            ListText {
                text: "Connexion D-Bus de la batterie"
                secondaryText: root.bindPrefix
            }
            ListText { text: "STATUT BMS / COMMUNICATION"; secondaryText: "" }
            ListText { text: "Module RS485 connecté"; dataItem.uid: root.bindPrefix + "/Connected"; secondaryText: root.valueText(dataItem, "connected") }
            ListText { text: "Batterie pleine"; dataItem.uid: root.bindPrefix + "/Diagnostics/BmsFullyCharged"; secondaryText: root.valueText(dataItem, "bool") }
            ListText { text: "Charge réellement autorisée"; dataItem.uid: root.bindPrefix + "/Diagnostics/BmsChargeAllowed"; secondaryText: root.valueText(dataItem, "bool") }
            ListText { text: "Décharge réellement autorisée"; dataItem.uid: root.bindPrefix + "/Diagnostics/BmsDischargeAllowed"; secondaryText: root.valueText(dataItem, "bool") }
            ListText { text: "LIMITES DU BMS — LECTURE SEULE"; secondaryText: "" }
            ListQuantity { text: "Courant de charge autorisé"; dataItem.uid: root.bindPrefix + "/Diagnostics/BmsChargeCurrentLimit"; unit: VenusOS.Units_Amp }
            ListQuantity { text: "Courant de décharge autorisé"; dataItem.uid: root.bindPrefix + "/Diagnostics/BmsDischargeCurrentLimit"; unit: VenusOS.Units_Amp }
            ListQuantity { text: "Tension limite de charge"; dataItem.uid: root.bindPrefix + "/Diagnostics/BmsChargeVoltageLimit"; unit: VenusOS.Units_Volt_DC }
            ListQuantity { text: "Tension limite de décharge"; dataItem.uid: root.bindPrefix + "/Diagnostics/BmsDischargeVoltageLimit"; unit: VenusOS.Units_Volt_DC }
            ListText { text: "ETATS MATÉRIELS — TRAME 0x44"; secondaryText: "" }
            ListText { text: "MOSFET de charge"; dataItem.uid: root.bindPrefix + "/Diagnostics/BmsChargeMosOn"; secondaryText: root.valueText(dataItem, "bool") }
            ListText { text: "MOSFET de décharge"; dataItem.uid: root.bindPrefix + "/Diagnostics/BmsDischargeMosOn"; secondaryText: root.valueText(dataItem, "bool") }
            ListText { text: "Charge en cours (statut BMS)"; dataItem.uid: root.bindPrefix + "/Diagnostics/BmsChargingActive"; secondaryText: root.valueText(dataItem, "bool") }
            ListText { text: "Décharge en cours (statut BMS)"; dataItem.uid: root.bindPrefix + "/Diagnostics/BmsDischargingActive"; secondaryText: root.valueText(dataItem, "bool") }
            ListText { text: "Module alimenté"; dataItem.uid: root.bindPrefix + "/Diagnostics/BmsModulePower"; secondaryText: root.valueText(dataItem, "bool") }
            ListText { text: "Chauffage interne"; dataItem.uid: root.bindPrefix + "/Diagnostics/BmsHeaterOn"; secondaryText: root.valueText(dataItem, "bool") }
            ListText { text: "Buzzer"; dataItem.uid: root.bindPrefix + "/Diagnostics/BmsBuzzerOn"; secondaryText: root.valueText(dataItem, "bool") }
            ListText { text: "INDICATEURS DE GESTION — TRAME 0x92"; secondaryText: "" }
            ListText { text: "Charge forcée niveau 1"; dataItem.uid: root.bindPrefix + "/Diagnostics/BmsForceCharge1"; secondaryText: root.valueText(dataItem, "bool") }
            ListText { text: "Charge forcée niveau 2"; dataItem.uid: root.bindPrefix + "/Diagnostics/BmsForceCharge2"; secondaryText: root.valueText(dataItem, "bool") }
            ListText { text: "Demande de charge complète"; dataItem.uid: root.bindPrefix + "/Diagnostics/BmsFullChargeRequested"; secondaryText: root.valueText(dataItem, "bool") }
            ListText { text: "Flags de gestion"; dataItem.uid: root.bindPrefix + "/Diagnostics/BmsManagementFlags"; secondaryText: root.valueText(dataItem, "hex") }
            ListText { text: "ALARMES ET PROTECTIONS"; secondaryText: "" }
            ListText { text: "Défaut câble BMS RS485"; dataItem.uid: root.bindPrefix + "/Alarms/BmsCable"; secondaryText: root.valueText(dataItem, "alarm") }
            ListText { text: "Flags de protection"; dataItem.uid: root.bindPrefix + "/Diagnostics/BmsProtectionFlags"; secondaryText: root.valueText(dataItem, "hex") }
            ListText { text: "Masque de défauts cellules"; dataItem.uid: root.bindPrefix + "/Diagnostics/BmsCellFaultMask"; secondaryText: root.valueText(dataItem, "hex") }
            ListText { text: "Nombre de cellules en alarme"; dataItem.uid: root.bindPrefix + "/Diagnostics/BmsCellAlarmCount"; secondaryText: root.valueText(dataItem, "int") }
            ListText { text: "Nombre de sondes en alarme"; dataItem.uid: root.bindPrefix + "/Diagnostics/BmsTemperatureAlarmCount"; secondaryText: root.valueText(dataItem, "int") }
            ListText { text: "Alarme courant de charge"; dataItem.uid: root.bindPrefix + "/Diagnostics/BmsChargeCurrentAlarmCode"; secondaryText: root.valueText(dataItem, "hex") }
            ListText { text: "Alarme tension batterie"; dataItem.uid: root.bindPrefix + "/Diagnostics/BmsPackVoltageAlarmCode"; secondaryText: root.valueText(dataItem, "hex") }
            ListText { text: "Alarme courant de décharge"; dataItem.uid: root.bindPrefix + "/Diagnostics/BmsDischargeCurrentAlarmCode"; secondaryText: root.valueText(dataItem, "hex") }
            ListText { text: "CODES BRUTS — TRAME 0x44"; secondaryText: "" }
            ListText { text: "Status 1"; dataItem.uid: root.bindPrefix + "/Diagnostics/BmsStatus1"; secondaryText: root.valueText(dataItem, "hex") }
            ListText { text: "Status 2"; dataItem.uid: root.bindPrefix + "/Diagnostics/BmsStatus2"; secondaryText: root.valueText(dataItem, "hex") }
            ListText { text: "Status 3"; dataItem.uid: root.bindPrefix + "/Diagnostics/BmsStatus3"; secondaryText: root.valueText(dataItem, "hex") }
            ListText { text: "Status 4"; dataItem.uid: root.bindPrefix + "/Diagnostics/BmsStatus4"; secondaryText: root.valueText(dataItem, "hex") }
            ListText { text: "Status 5"; dataItem.uid: root.bindPrefix + "/Diagnostics/BmsStatus5"; secondaryText: root.valueText(dataItem, "hex") }
            ListText { text: "Trame d’alarme 0x44"; dataItem.uid: root.bindPrefix + "/Diagnostics/BmsAlarmFrameHex"; secondaryText: root.valueText(dataItem, "raw") }
            ListText { text: "ÉQUILIBRAGE"; secondaryText: "" }
            ListText { text: "Balancing"; secondaryText: "Non décodé" }
            ListText { text: "Commande Victron"; secondaryText: "CAN can8 (RS485 en lecture seule)" }
        }
    }
}
