import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root

    ColumnLayout {
        id: columnLayout
        anchors.centerIn: parent
        spacing: 6
        Layout.minimumWidth: 210

        // Header with battery icon, title, and current percentage badge
        StyledPopupHeaderRow {
            id: headerRow
            icon: Battery.isCharging ? "battery_charging_full" : (Battery.percentage > 0.8 ? "battery_android_full" : (Battery.percentage > 0.2 ? "battery_android_medium" : "battery_android_low"))
            label: Translation.tr("Battery")
            badge: `${Math.round(Battery.percentage * 100)}%`
            badgeColor: (Battery.percentage <= 0.2 && !Battery.isCharging) ? Appearance.colors.colError : Appearance.colors.colPrimary
        }

        // Modern horizontal progress bar
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 6
            radius: 3
            color: Appearance.colors.colLayer1

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * Math.max(0, Math.min(1, Battery.percentage))
                radius: 3
                color: (Battery.percentage <= 0.2 && !Battery.isCharging) ? Appearance.colors.colError : Appearance.colors.colPrimary
            }
        }

        // Divider
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Appearance.colors.colLayer0Border
            Layout.topMargin: 2
            Layout.bottomMargin: 2
        }

        // Time to full / empty
        StyledPopupValueRow {
            visible: {
                let timeValue = Battery.isCharging ? Battery.timeToFull : Battery.timeToEmpty;
                let power = Battery.energyRate;
                return !(Battery.chargeState == 4 || timeValue <= 0 || power <= 0.01);
            }
            icon: "schedule"
            label: Battery.isCharging ? Translation.tr("Time to full:") : Translation.tr("Time to empty:")
            value: {
                function formatTime(seconds) {
                    var h = Math.floor(seconds / 3600);
                    var m = Math.floor((seconds % 3600) / 60);
                    if (h > 0)
                        return `${h}h, ${m}m`;
                    else
                        return `${m}m`;
                }
                if (Battery.isCharging)
                    return formatTime(Battery.timeToFull);
                else
                    return formatTime(Battery.timeToEmpty);
            }
        }

        // State / Power consumption
        StyledPopupValueRow {
            visible: !(Battery.chargeState != 4 && Battery.energyRate == 0)
            icon: "bolt"
            label: {
                if (Battery.chargeState == 4) {
                    return Translation.tr("Fully charged");
                } else if (Battery.chargeState == 1) {
                    return Translation.tr("Charging:");
                } else {
                    return Translation.tr("Discharging:");
                }
            }
            value: {
                if (Battery.chargeState == 4) {
                    return "";
                } else {
                    return `${Battery.energyRate.toFixed(2)}W`;
                }
            }
        }

        // Health
        StyledPopupValueRow {
            icon: "heart_check"
            label: Translation.tr("Health:")
            value: `${(Battery.health).toFixed(1)}%`
        }
    }
}
