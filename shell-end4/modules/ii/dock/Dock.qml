import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// ASURA overlay (shell-end4/asura/vendor.sh OVERLAYS): end-4's dock as an
// island. It holds only the apps (end-4's DockApps: pinned apps and running
// windows, with their previews), in a compact pill that floats above the
// bottom edge and is always there; windows tile above it.
//
// Removed from end-4's dock: the pin button, the overview (apps grid) button
// and their separators, and the hover-to-reveal and pin-on-startup behaviour
// behind them (their settings switches too, in
// modules/settings/InterfaceConfig.qml).
//
// The geometry and the ids dockVisualBackground (with its margin) and dockRow
// (with its padding) are end-4's: DockAppButton.qml reaches them by id.
Scope {
    id: root

    // The island: lifted this far off the edge, with these rounded ends (the
    // rest of ASURA's desktop is square; the island is the exception).
    readonly property int islandLift: 10
    readonly property int islandRadius: 18
    readonly property int islandPadding: 6

    Variants {
        // For each monitor
        model: Quickshell.screens

        PanelWindow {
            id: dockRoot
            required property var modelData
            screen: modelData
            visible: !GlobalStates.screenLocked

            anchors {
                bottom: true
                left: true
                right: true
            }

            // Always shown: windows stop above the island.
            exclusiveZone: implicitHeight - (Appearance.sizes.hyprlandGapsOut) - (Appearance.sizes.elevationMargin - Appearance.sizes.hyprlandGapsOut)

            implicitWidth: dockBackground.implicitWidth
            WlrLayershell.namespace: "quickshell:dock"
            color: "transparent"

            implicitHeight: (Config.options?.dock.height ?? 70) + Appearance.sizes.elevationMargin + Appearance.sizes.hyprlandGapsOut + root.islandLift

            // Only the island takes input; the rest of the strip is click-through.
            mask: Region {
                item: dockBackground
            }

            Item { // The island
                id: dockBackground
                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    horizontalCenter: parent.horizontalCenter
                }

                implicitWidth: dockRow.implicitWidth + root.islandPadding * 2

                StyledRectangularShadow {
                    target: dockVisualBackground
                }
                Rectangle { // The real rectangle that is visible
                    id: dockVisualBackground
                    property real margin: Appearance.sizes.elevationMargin
                    anchors.fill: parent
                    anchors.topMargin: Appearance.sizes.elevationMargin
                    anchors.bottomMargin: Appearance.sizes.hyprlandGapsOut + root.islandLift
                    color: Appearance.colors.colLayer0
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border
                    radius: root.islandRadius
                }

                RowLayout {
                    id: dockRow
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: root.islandLift
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 3
                    property real padding: 5

                    DockApps {
                        buttonPadding: dockRow.padding
                    }
                }
            }
        }
    }
}
