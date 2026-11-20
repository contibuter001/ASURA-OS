pragma ComponentBehavior: Bound

// The battery widget for the desktop.
// Shows battery percentage and state (charging/discharging)
// Read from /sys/class/power_supply or /proc/acpi/battery.

import QtQuick
import Quickshell.Io
import Quickshell.Widgets

Item {
    id: root

    property int refreshSeconds: 5

    // Read from sysfs power supply
    FileView {
        id: capacityFile
        path: "/sys/class/power_supply/BAT0/capacity"
        watchChanges: false
    }

    FileView {
        id: statusFile
        path: "/sys/class/power_supply/BAT0/status"
        watchChanges: false
    }

    FileView {
        id: presentFile
        path: "/sys/class/power_supply/BAT0/present"
        watchChanges: false
    }

    Timer {
        interval: root.refreshSeconds * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            capacityFile.reload();
            statusFile.reload();
            presentFile.reload();
        }
    }

    readonly property int percent: {
        var cap = capacityFile.text().trim();
        if (/^\d+$/.test(cap)) {
            return parseInt(cap, 10);
        }
        return 0;
    }

    readonly property string state: {
        var status = statusFile.text().trim().toLowerCase();
        if (status === "charging" || status === "full") {
            return status;
        }
        return "discharging";
    }

    readonly property bool isCharging: state === "charging" || state === "full"

    Text {
        id: label
        anchors.fill: parent
        text: percent + "%"
        color: isCharging ? Theme.inkPrimary : (Config.dark ? Theme.inkPrimary : Theme.inkSecondary)
        font.pixelSize: 13
        font.weight: Font.DemiBold
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    GlyphIcon {
        anchors { verticalCenter: label.verticalCenter; horizontalCenter: label.horizontalCenter }
        systemFont: "font-awesome"
        color: isCharging ? Theme.inkPrimary : (Config.dark ? Theme.inkPrimary : Theme.inkSecondary)
        visible: isCharging
        name: "\uf240"  // fa-bolt
    }

    GlyphIcon {
        anchors { verticalCenter: label.verticalCenter; horizontalCenter: label.horizontalCenter }
        systemFont: "font-awesome"
        color: !isCharging && percent < 20 ? Theme.colorError : (Config.dark ? Theme.inkPrimary : Theme.inkSecondary)
        visible: !isCharging && percent < 20
        name: "\uf244"  // fa-battery-quarter
    }

    GlyphIcon {
        anchors { verticalCenter: label.verticalCenter; horizontalCenter: label.horizontalCenter }
        systemFont: "font-awesome"
        color: !isCharging
        visible: !isCharging && percent >= 20 && percent < 40
        name: "\uf243"  // fa-battery-half
    }

    GlyphIcon {
        anchors { verticalCenter: label.verticalCenter; horizontalCenter: label.horizontalCenter }
        systemFont: "font-awesome"
        color: !isCharging
        visible: !isCharging && percent >= 40 && percent < 60
        name: "\uf242"  // fa-battery-third
    }

    GlyphIcon {
        anchors { verticalCenter: label.verticalCenter; horizontalCenter: label.horizontalCenter }
        systemFont: "font-awesome"
        color: !isCharging
        visible: !isCharging && percent >= 60 && percent < 80
        name: "\uf241"  // fa-battery-quarter
    }

    GlyphIcon {
        anchors { verticalCenter: label.verticalCenter; horizontalCenter: label.horizontalCenter }
        systemFont: "font-awesome"
        color: !isCharging
        visible: !isCharging && percent >= 80
        name: "\uf240"  // fa-battery-full
    }
}
