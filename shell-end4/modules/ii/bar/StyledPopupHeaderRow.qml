import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Row {
    id: root
    required property var icon
    required property var label
    property string badge: ""
    property color badgeColor: Appearance.colors.colPrimary
    spacing: 8

    Item {
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: 26
        implicitHeight: 26

        Rectangle {
            anchors.fill: parent
            radius: Appearance.rounding.verysmall
            color: Appearance.colors.colPrimaryContainerActive
            opacity: 0.7
        }

        MaterialSymbol {
            anchors.centerIn: parent
            fill: 0
            font.weight: Font.DemiBold
            text: root.icon
            iconSize: 18
            color: Appearance.colors.colPrimary
        }
    }

    StyledText {
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        font {
            weight: Font.DemiBold
            pixelSize: Appearance.font.pixelSize.normal
        }
        color: Appearance.colors.colOnLayer0
    }

    Rectangle {
        visible: root.badge !== ""
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: badgeText.implicitWidth + 10
        implicitHeight: 20
        radius: Appearance.rounding.verysmall
        color: Appearance.colors.colLayer1
        border.width: 1
        border.color: Appearance.colors.colLayer0Border

        StyledText {
            id: badgeText
            anchors.centerIn: parent
            text: root.badge
            font {
                pixelSize: Appearance.font.pixelSize.smallest
                weight: Font.DemiBold
            }
            color: root.badgeColor
        }
    }
}
