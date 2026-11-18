import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Io
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland

// ASURA overlay (shell-end4/asura/vendor.sh OVERLAYS): end-4's dock as an
// island. Only the apps, in a compact pill that floats above the bottom edge;
// end-4's pin and overview buttons are gone. Whether it stays shown is
// end-4's dock.pinnedOnStartup setting (ASURA turns it on); otherwise it
// shows on hover at the bottom edge and on an empty workspace.
Scope { // Scope
    id: root
    property bool pinned: Config.options?.dock.pinnedOnStartup ?? false
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
            // Window
            required property var modelData
            screen: modelData
            visible: !GlobalStates.screenLocked

            property bool reveal: root.pinned || (Config.options?.dock.hoverToReveal && dockMouseArea.containsMouse) || dockApps.requestDockShow || (!ToplevelManager.activeToplevel?.activated)

            anchors {
                bottom: true
                left: true
                right: true
            }

            exclusiveZone: root.pinned ? implicitHeight - (Appearance.sizes.hyprlandGapsOut) - (Appearance.sizes.elevationMargin - Appearance.sizes.hyprlandGapsOut) : 0

            implicitWidth: dockBackground.implicitWidth
            WlrLayershell.namespace: "quickshell:dock"
            color: "transparent"

            implicitHeight: (Config.options?.dock.height ?? 70) + Appearance.sizes.elevationMargin + Appearance.sizes.hyprlandGapsOut + root.islandLift

            mask: Region {
                item: dockMouseArea
            }

            MouseArea {
                id: dockMouseArea
                height: parent.height
                anchors {
                    top: parent.top
                    topMargin: dockRoot.reveal ? 0 : Config.options?.dock.hoverToReveal ? (dockRoot.implicitHeight - Config.options.dock.hoverRegionHeight) : (dockRoot.implicitHeight + 1)
                    horizontalCenter: parent.horizontalCenter
                }
                implicitWidth: dockHoverRegion.implicitWidth + Appearance.sizes.elevationMargin * 2
                hoverEnabled: true

                Behavior on anchors.topMargin {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }

                Item {
                    id: dockHoverRegion
                    anchors.fill: parent
                    implicitWidth: dockBackground.implicitWidth

                    Item { // Wrapper for the dock background
                        id: dockBackground
                        anchors {
                            top: parent.top
                            bottom: parent.bottom
                            horizontalCenter: parent.horizontalCenter
                        }

                        implicitWidth: dockRow.implicitWidth + root.islandPadding * 2
                        height: parent.height - Appearance.sizes.elevationMargin - Appearance.sizes.hyprlandGapsOut

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
                                id: dockApps
                                buttonPadding: dockRow.padding
                            }
                        }
                    }
                }
            }
        }
    }
}
