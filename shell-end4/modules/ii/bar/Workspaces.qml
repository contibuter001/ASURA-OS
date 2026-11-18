pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets

// ASURA overlay (shell-end4/asura/vendor.sh OVERLAYS): the bar's workspaces,
// showing only the workspaces that exist, the active one and those with
// windows, in order. end-4's widget draws a fixed row of slots
// (bar.workspaces.shown, 10) and marks the empty ones with dots; Hyprland
// itself keeps no empty workspace but the active one, so its list is exactly
// what to show. Each workspace shows its main window's icon, or its number
// when it has none; the active one is filled. Left click switches, the wheel
// steps through workspaces, right click opens the overview (BarContent).
ButtonMouseArea {
    id: root

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.QsWindow.window?.screen)
    readonly property int activeId: root.monitor?.activeWorkspace?.id ?? 1
    property bool vertical: Config.options.bar.vertical
    readonly property real barThickness: vertical ? Appearance.sizes.verticalBarWidth : Appearance.sizes.barHeight
    // BarContent pads its group with this (end-4 reads it but never defined it).
    property real widgetPadding: 4
    property real workspaceButtonWidth: 26
    property real iconSize: workspaceButtonWidth * 0.69

    // The workspaces on this monitor: every regular one Hyprland has, plus the
    // active one, by id.
    readonly property var shownIds: {
        const monitorId = root.monitor?.id;
        const ids = HyprlandData.workspaces
            .filter(ws => ws.id > 0 && (monitorId === undefined || ws.monitorID === monitorId))
            .map(ws => ws.id);
        if (root.activeId > 0 && !ids.includes(root.activeId))
            ids.push(root.activeId);
        return ids.sort((a, b) => a - b);
    }

    Layout.alignment: vertical ? Qt.AlignHCenter : Qt.AlignVCenter
    Layout.fillWidth: vertical
    Layout.fillHeight: !vertical
    implicitWidth: vertical ? barThickness : row.implicitWidth
    implicitHeight: vertical ? row.implicitHeight : barThickness

    // Clicks belong to each workspace's own MouseArea; this one takes the wheel.
    acceptedButtons: Qt.NoButton
    hoverEnabled: true
    onWheel: event => {
        if (event.angleDelta.y < 0)
            Hyprland.dispatch("workspace r+1");
        else if (event.angleDelta.y > 0)
            Hyprland.dispatch("workspace r-1");
    }

    GridLayout {
        id: row
        anchors.centerIn: parent
        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: 2
        columnSpacing: 2

        Repeater {
            model: root.shownIds

            delegate: Rectangle {
                id: ws
                required property int modelData
                readonly property bool active: modelData === root.activeId
                readonly property var mainWindow: HyprlandData.biggestWindowForWorkspace(modelData)
                readonly property bool hovered: wsMouse.containsMouse

                implicitWidth: root.workspaceButtonWidth
                implicitHeight: root.workspaceButtonWidth
                radius: Appearance.rounding.small
                color: ws.active ? Appearance.colors.colPrimary
                    : ws.hovered ? Appearance.colors.colLayer1Hover
                    : "transparent"
                Behavior on color {
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }

                IconImage {
                    anchors.centerIn: parent
                    visible: !!ws.mainWindow && (Config.options?.bar.workspaces.showAppIcons ?? true)
                    implicitSize: root.iconSize
                    source: Quickshell.iconPath(AppSearch.guessIcon(ws.mainWindow?.class), "image-missing")
                }
                StyledText {
                    anchors.centerIn: parent
                    visible: !ws.mainWindow || !(Config.options?.bar.workspaces.showAppIcons ?? true)
                    text: Config.options?.bar.workspaces.numberMap[ws.modelData - 1] || ws.modelData
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: ws.active ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                }

                MouseArea {
                    id: wsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch(`workspace ${ws.modelData}`)
                }
            }
        }
    }
}
