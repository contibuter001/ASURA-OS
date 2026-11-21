//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QT_SCALE_FACTOR=1

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ApplicationWindow {
    id: root

    property string firstRunFilePath: FileUtils.trimFileProtocol(`${Directories.state}/user/first_run.txt`)
    property string firstRunFileContent: "This file is just here to confirm you've been greeted :>"
    property real contentPadding: 12
    property bool showNextTime: false
    property int currentStep: 0

    readonly property var stepList: [
        { label: Translation.tr("Hello"), icon: "waving_hand" },
        { label: Translation.tr("Your Bar"), icon: "dock_to_bottom" },
        { label: Translation.tr("Make It Yours"), icon: "palette" },
        { label: Translation.tr("Essentials"), icon: "keyboard" },
        { label: Translation.tr("Done"), icon: "check_circle" }
    ]
    readonly property int totalSteps: stepList.length

    visible: true
    title: Translation.tr("ASURA OS Welcome")

    minimumWidth: 840
    minimumHeight: 580
    width: 980
    height: 660
    color: Appearance.m3colors.m3background

    Component.onCompleted: {
        MaterialThemeLoader.reapplyTheme();
        Config.readWriteDelay = 0;
    }

    onClosing: {
        Quickshell.execDetached([
            "notify-send",
            Translation.tr("Welcome to Asura OS"),
            Translation.tr("Enjoy! Reopen the welcome guide any time with <tt>Super+Shift+Alt+/</tt>. Open Settings with <tt>Super+I</tt>"),
            "-a", "Shell"
        ]);
        Qt.quit();
    }

    function advance() {
        if (currentStep < totalSteps - 1) {
            currentStep++;
        } else {
            finish();
        }
    }

    function back() {
        if (currentStep > 0) {
            currentStep--;
        }
    }

    function finish() {
        if (!showNextTime) {
            Quickshell.execDetached(["bash", "-c", `echo '${StringUtils.shellSingleQuoteEscape(root.firstRunFileContent)}' > '${StringUtils.shellSingleQuoteEscape(root.firstRunFilePath)}'`]);
        }
        root.close();
    }

    function runCmd(argv) {
        if (!argv || argv.length === 0) return;
        Quickshell.execDetached(argv);
    }

    // Keyboard shortcuts to navigate
    Shortcut { sequence: "Right"; onActivated: root.advance() }
    Shortcut { sequence: "Left"; onActivated: root.back() }
    Shortcut { sequence: "Return"; onActivated: root.advance() }
    Shortcut { sequence: "Escape"; onActivated: root.close() }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: contentPadding
        spacing: 10

        // ==========================================
        // 1. TOP HEADER & STEP INDICATORS
        // ==========================================
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 52
            color: Appearance.m3colors.m3surfaceContainerLow
            radius: Appearance.rounding.windowRounding - 2

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12

                // Brand Mark
                RowLayout {
                    spacing: 6
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        text: "//"
                        color: "#e2342a"
                        font.family: Appearance.font.family.title
                        font.pixelSize: 18
                        font.weight: Font.Black
                    }

                    StyledText {
                        text: "ASURA"
                        font.pixelSize: Appearance.font.pixelSize.medium
                        font.weight: Font.Bold
                        color: Appearance.colors.colOnLayer0
                    }

                    Rectangle {
                        width: 1
                        height: 14
                        color: Appearance.colors.colOutline
                        Layout.margins: 4
                    }

                    StyledText {
                        text: Translation.tr("FIRST RUN")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.letterSpacing: 1.2
                        color: Appearance.colors.colSubtext
                    }
                }

                Item { Layout.fillWidth: true }

                // Step Progression Tabs
                RowLayout {
                    spacing: 6
                    Layout.alignment: Qt.AlignVCenter

                    Repeater {
                        model: root.stepList

                        Rectangle {
                            id: stepTab
                            required property var modelData
                            required property int index

                            implicitWidth: tabRow.implicitWidth + 18
                            implicitHeight: 32
                            radius: Appearance.rounding.full
                            color: root.currentStep === index 
                                   ? Appearance.m3colors.m3primary 
                                   : (stepMouse.containsMouse ? Appearance.m3colors.m3surfaceContainerHigh : "transparent")
                            border.width: root.currentStep === index ? 0 : 1
                            border.color: root.currentStep > index ? Appearance.m3colors.m3primary : Appearance.colors.colOutlineVariant

                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                id: tabRow
                                anchors.centerIn: parent
                                spacing: 6

                                StyledText {
                                    text: "0" + (index + 1)
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: Font.Bold
                                    color: root.currentStep === index 
                                           ? Appearance.m3colors.m3onPrimary 
                                           : (root.currentStep > index ? Appearance.m3colors.m3primary : Appearance.colors.colSubtext)
                                }

                                StyledText {
                                    text: modelData.label
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: root.currentStep === index ? Font.Bold : Font.Normal
                                    color: root.currentStep === index 
                                           ? Appearance.m3colors.m3onPrimary 
                                           : (root.currentStep > index ? Appearance.colors.colOnLayer0 : Appearance.colors.colSubtext)
                                }
                            }

                            MouseArea {
                                id: stepMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.currentStep = index
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Window Controls
                RowLayout {
                    spacing: 8
                    Layout.alignment: Qt.AlignVCenter

                    StyledText {
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        text: Translation.tr("Show next time")
                        color: Appearance.colors.colSubtext
                    }

                    StyledSwitch {
                        checked: root.showNextTime
                        scale: 0.65
                        Layout.alignment: Qt.AlignVCenter
                        onCheckedChanged: {
                            root.showNextTime = checked;
                            if (checked) {
                                Quickshell.execDetached(["rm", "-f", root.firstRunFilePath]);
                            } else {
                                Quickshell.execDetached(["bash", "-c", `echo '${StringUtils.shellSingleQuoteEscape(root.firstRunFileContent)}' > '${StringUtils.shellSingleQuoteEscape(root.firstRunFilePath)}'`]);
                            }
                        }
                    }

                    RippleButton {
                        buttonRadius: Appearance.rounding.full
                        implicitWidth: 32
                        implicitHeight: 32
                        onClicked: root.close()
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "close"
                            iconSize: 18
                            color: Appearance.colors.colOnLayer0
                        }
                    }
                }
            }
        }

        // ==========================================
        // 2. MAIN CONTENT STAGE
        // ==========================================
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Appearance.m3colors.m3surfaceContainerLow
            radius: Appearance.rounding.windowRounding - 2
            clip: true

            StackLayout {
                id: stackView
                anchors.fill: parent
                anchors.margins: 24
                currentIndex: root.currentStep

                // ------------------------------------------
                // PAGE 0: HELLO
                // ------------------------------------------
                Item {
                    id: pageHello

                    RowLayout {
                        anchors.fill: parent
                        spacing: 32

                        // Left Hero Panel
                        Rectangle {
                            Layout.fillHeight: true
                            Layout.preferredWidth: 320
                            radius: Appearance.rounding.cardRounding
                            color: Appearance.m3colors.m3surfaceContainerLowest
                            border.width: 1
                            border.color: Appearance.colors.colOutlineVariant
                            clip: true

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 24
                                spacing: 16

                                Item { Layout.fillHeight: true }

                                RowLayout {
                                    spacing: 8
                                    Text {
                                        text: "//"
                                        color: "#e2342a"
                                        font.family: Appearance.font.family.title
                                        font.pixelSize: 38
                                        font.weight: Font.Black
                                    }
                                    StyledText {
                                        text: "ASURA"
                                        font.pixelSize: 28
                                        font.weight: Font.Bold
                                        color: Appearance.colors.colOnLayer0
                                    }
                                }

                                StyledText {
                                    text: Translation.tr("PURE MONOCHROME DESKTOP")
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.letterSpacing: 2.0
                                    font.weight: Font.DemiBold
                                    color: "#e2342a"
                                }

                                StyledText {
                                    text: Translation.tr("Engineered for minimal friction, high efficiency, and clean ergonomics on Hyprland.")
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                    color: Appearance.colors.colSubtext
                                    lineHeight: 1.35
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 1
                                    color: Appearance.colors.colOutlineVariant
                                }

                                RowLayout {
                                    spacing: 6
                                    MaterialSymbol {
                                        text: "verified"
                                        iconSize: 16
                                        color: Appearance.m3colors.m3primary
                                    }
                                    StyledText {
                                        text: "v0.1-pre-alpha · Void Linux"
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: Appearance.colors.colSubtext
                                    }
                                }

                                Item { Layout.fillHeight: true }
                            }
                        }

                        // Right Intro Panel
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 18

                            Item { Layout.fillHeight: true }

                            StyledText {
                                text: Translation.tr("Welcome to Asura OS")
                                font.pixelSize: 32
                                font.weight: Font.Bold
                                color: Appearance.colors.colOnLayer0
                            }

                            StyledText {
                                text: Translation.tr("Your desktop is pre-configured and dressed. This guided tour sets up your bar position, appearance mode, and introduces essential shortcuts.")
                                font.pixelSize: Appearance.font.pixelSize.medium
                                color: Appearance.colors.colSubtext
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                                lineHeight: 1.4
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: Appearance.colors.colOutlineVariant
                            }

                            // Highlights
                            ColumnLayout {
                                spacing: 14
                                Layout.fillWidth: true

                                RowLayout {
                                    spacing: 12
                                    Rectangle {
                                        width: 36
                                        height: 36
                                        radius: 18
                                        color: Appearance.m3colors.m3surfaceContainerHigh
                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: "dock_to_bottom"
                                            iconSize: 20
                                            color: Appearance.m3colors.m3primary
                                        }
                                    }
                                    ColumnLayout {
                                        spacing: 2
                                        StyledText {
                                            text: Translation.tr("Status Bar & Edges")
                                            font.weight: Font.DemiBold
                                            color: Appearance.colors.colOnLayer0
                                        }
                                        StyledText {
                                            text: Translation.tr("Choose whether your bar sits at the top, bottom, or sides.")
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            color: Appearance.colors.colSubtext
                                        }
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Rectangle {
                                        width: 36
                                        height: 36
                                        radius: 18
                                        color: Appearance.m3colors.m3surfaceContainerHigh
                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: "palette"
                                            iconSize: 20
                                            color: Appearance.m3colors.m3primary
                                        }
                                    }
                                    ColumnLayout {
                                        spacing: 2
                                        StyledText {
                                            text: Translation.tr("Theme & Wallpapers")
                                            font.weight: Font.DemiBold
                                            color: Appearance.colors.colOnLayer0
                                        }
                                        StyledText {
                                            text: Translation.tr("Switch between dark and light themes with dynamic palette harmony.")
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            color: Appearance.colors.colSubtext
                                        }
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Rectangle {
                                        width: 36
                                        height: 36
                                        radius: 18
                                        color: Appearance.m3colors.m3surfaceContainerHigh
                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: "keyboard"
                                            iconSize: 20
                                            color: Appearance.m3colors.m3primary
                                        }
                                    }
                                    ColumnLayout {
                                        spacing: 2
                                        StyledText {
                                            text: Translation.tr("Essential Shortcuts")
                                            font.weight: Font.DemiBold
                                            color: Appearance.colors.colOnLayer0
                                        }
                                        StyledText {
                                            text: Translation.tr("Learn the 8 key combinations that run your entire workspace.")
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            color: Appearance.colors.colSubtext
                                        }
                                    }
                                }
                            }

                            Item { Layout.fillHeight: true }
                        }
                    }
                }

                // ------------------------------------------
                // PAGE 1: YOUR BAR
                // ------------------------------------------
                Item {
                    id: pageBar

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 20

                        ColumnLayout {
                            spacing: 4
                            StyledText {
                                text: Translation.tr("Choose your edge")
                                font.pixelSize: 24
                                font.weight: Font.Bold
                                color: Appearance.colors.colOnLayer0
                            }
                            StyledText {
                                text: Translation.tr("Select where your status bar sits and how its silhouette is shaped. Changes apply live.")
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colSubtext
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Appearance.colors.colOutlineVariant
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 24

                            // Left Controls
                            ColumnLayout {
                                Layout.preferredWidth: 380
                                spacing: 20

                                ContentSubsection {
                                    title: Translation.tr("Bar position")
                                    ConfigSelectionArray {
                                        currentValue: (Config.options.bar.bottom ? 1 : 0) | (Config.options.bar.vertical ? 2 : 0)
                                        onSelected: newValue => {
                                            Config.options.bar.bottom = (newValue & 1) !== 0;
                                            Config.options.bar.vertical = (newValue & 2) !== 0;
                                        }
                                        options: [
                                            { displayName: Translation.tr("Top"), icon: "arrow_upward", value: 0 },
                                            { displayName: Translation.tr("Left"), icon: "arrow_back", value: 2 },
                                            { displayName: Translation.tr("Bottom"), icon: "arrow_downward", value: 1 },
                                            { displayName: Translation.tr("Right"), icon: "arrow_forward", value: 3 }
                                        ]
                                    }
                                }

                                ContentSubsection {
                                    title: Translation.tr("Bar silhouette & corners")
                                    ConfigSelectionArray {
                                        currentValue: Config.options.bar.cornerStyle
                                        onSelected: newValue => {
                                            Config.options.bar.cornerStyle = newValue;
                                        }
                                        options: [
                                            { displayName: Translation.tr("Hug"), icon: "line_curve", value: 0 },
                                            { displayName: Translation.tr("Float"), icon: "page_header", value: 1 },
                                            { displayName: Translation.tr("Rect"), icon: "toolbar", value: 2 }
                                        ]
                                    }
                                }

                                NoticeBox {
                                    Layout.fillWidth: true
                                    text: Translation.tr("Tip: You can customize panel widgets, sound, and CPU monitors anytime in Asura Settings.")
                                }
                            }

                            // Right Visual Preview
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: Appearance.rounding.cardRounding
                                color: Appearance.m3colors.m3surfaceContainerLowest
                                border.width: 1
                                border.color: Appearance.colors.colOutlineVariant

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 12

                                    // Monitor Mockup
                                    Rectangle {
                                        width: 280
                                        height: 180
                                        radius: 8
                                        color: "#0a0a0e"
                                        border.width: 2
                                        border.color: Appearance.m3colors.m3primary

                                        // Mockup Bar
                                        Rectangle {
                                            id: previewBarMock
                                            color: Appearance.m3colors.m3primary
                                            radius: Config.options.bar.cornerStyle === 1 ? 6 : (Config.options.bar.cornerStyle === 0 ? 0 : 0)

                                            // Dynamic positioning based on user choice
                                            anchors.top: !Config.options.bar.bottom && !Config.options.bar.vertical ? parent.top : undefined
                                            anchors.bottom: Config.options.bar.bottom && !Config.options.bar.vertical ? parent.bottom : undefined
                                            anchors.left: Config.options.bar.vertical && !Config.options.bar.bottom ? parent.left : (Config.options.bar.vertical ? undefined : parent.left)
                                            anchors.right: Config.options.bar.vertical && Config.options.bar.bottom ? parent.right : (Config.options.bar.vertical ? undefined : parent.right)

                                            anchors.margins: Config.options.bar.cornerStyle === 1 ? 6 : 0

                                            width: Config.options.bar.vertical ? 24 : parent.width - (Config.options.bar.cornerStyle === 1 ? 12 : 0)
                                            height: Config.options.bar.vertical ? parent.height - (Config.options.bar.cornerStyle === 1 ? 12 : 0) : 22

                                            Row {
                                                anchors.centerIn: parent
                                                visible: !Config.options.bar.vertical
                                                spacing: 6
                                                Text { text: "//"; color: "#ffffff"; font.pixelSize: 8; font.weight: Font.Bold }
                                                Text { text: "ASURA OS"; color: "#ffffff"; font.pixelSize: 8; font.weight: Font.Bold }
                                            }
                                        }

                                        // Mockup Windows
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 140
                                            height: 90
                                            radius: 6
                                            color: "#181820"
                                            border.width: 1
                                            border.color: "#30303e"

                                            Row {
                                                anchors.top: parent.top
                                                anchors.left: parent.left
                                                anchors.margins: 6
                                                spacing: 3
                                                Rectangle { width: 4; height: 4; radius: 2; color: "#e2342a" }
                                                Rectangle { width: 4; height: 4; radius: 2; color: "#e5a50a" }
                                                Rectangle { width: 4; height: 4; radius: 2; color: "#57e389" }
                                            }
                                        }
                                    }

                                    StyledText {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: Translation.tr("Desktop Silhouette")
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: Appearance.colors.colSubtext
                                    }
                                }
                            }
                        }
                    }
                }

                // ------------------------------------------
                // PAGE 2: MAKE IT YOURS (THEME & WALLPAPER)
                // ------------------------------------------
                Item {
                    id: pageMake

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 16

                        ColumnLayout {
                            spacing: 4
                            StyledText {
                                text: Translation.tr("Make it yours")
                                font.pixelSize: 24
                                font.weight: Font.Bold
                                color: Appearance.colors.colOnLayer0
                            }
                            StyledText {
                                text: Translation.tr("Choose your appearance theme and system wallpaper. Colors update across apps and widgets.")
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colSubtext
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Appearance.colors.colOutlineVariant
                        }

                        // Light / Dark Theme Mode
                        ContentSubsection {
                            title: Translation.tr("Appearance theme")

                            ButtonGroup {
                                Layout.alignment: Qt.AlignHCenter
                                LightDarkPreferenceButton { dark: false }
                                LightDarkPreferenceButton { dark: true }
                            }
                        }

                        // Wallpaper & Language Row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16

                            // Wallpaper Picker Card
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 110
                                radius: Appearance.rounding.cardRounding
                                color: Appearance.m3colors.m3surfaceContainerLowest
                                border.width: 1
                                border.color: Appearance.colors.colOutlineVariant

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 16
                                    spacing: 16

                                    Rectangle {
                                        width: 44
                                        height: 44
                                        radius: 22
                                        color: Appearance.m3colors.m3surfaceContainerHigh
                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: "wallpaper"
                                            iconSize: 24
                                            color: Appearance.m3colors.m3primary
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        StyledText {
                                            text: Translation.tr("Wallpaper gallery")
                                            font.weight: Font.Bold
                                            color: Appearance.colors.colOnLayer0
                                        }
                                        StyledText {
                                            text: Translation.tr("Pick a wallpaper image from disk or browse presets.")
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            color: Appearance.colors.colSubtext
                                        }
                                    }

                                    RippleButtonWithIcon {
                                        materialIcon: "folder_open"
                                        mainText: Translation.tr("Choose Wallpaper")
                                        onClicked: {
                                            Quickshell.execDetached([`${Directories.wallpaperSwitchScriptPath}`]);
                                        }
                                    }
                                }
                            }

                            // Language Selector Card
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 110
                                radius: Appearance.rounding.cardRounding
                                color: Appearance.m3colors.m3surfaceContainerLowest
                                border.width: 1
                                border.color: Appearance.colors.colOutlineVariant

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 16
                                    spacing: 6

                                    StyledText {
                                        text: Translation.tr("Interface Language")
                                        font.weight: Font.Bold
                                        color: Appearance.colors.colOnLayer0
                                    }

                                    ConfigSelectionArray {
                                        currentValue: Config.options.language.ui
                                        onSelected: newValue => {
                                            Config.options.language.ui = newValue;
                                        }
                                        options: [
                                            { displayName: "Auto", value: "auto" },
                                            { displayName: "en_US", value: "en_US" },
                                            { displayName: "ja_JP", value: "ja_JP" },
                                            { displayName: "zh_CN", value: "zh_CN" },
                                            { displayName: "es_MX", value: "es_MX" },
                                            { displayName: "de_DE", value: "de_DE" }
                                        ]
                                    }
                                }
                            }
                        }

                        NoticeBox {
                            Layout.fillWidth: true
                            text: Translation.tr("Change themes anytime later with /dark, /light, or /wallpaper in the application launcher.")
                        }
                    }
                }

                // ------------------------------------------
                // PAGE 3: ESSENTIALS (KEYBINDINGS)
                // ------------------------------------------
                Item {
                    id: pageEssentials

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 16

                        ColumnLayout {
                            spacing: 4
                            StyledText {
                                text: Translation.tr("The keys that matter")
                                font.pixelSize: 24
                                font.weight: Font.Bold
                                color: Appearance.colors.colOnLayer0
                            }
                            StyledText {
                                text: Translation.tr("These core shortcuts drive everyday tasks. Click any card to launch the tool right now.")
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colSubtext
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Appearance.colors.colOutlineVariant
                        }

                        // Shortcuts Grid (2 cols x 4 rows)
                        GridLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            columns: 2
                            rowSpacing: 10
                            columnSpacing: 12

                            // 1. Launcher
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 52
                                radius: 8
                                color: k1Mouse.containsMouse ? Appearance.m3colors.m3surfaceContainerHigh : Appearance.m3colors.m3surfaceContainerLowest
                                border.width: 1
                                border.color: Appearance.colors.colOutlineVariant

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 10
                                    Rectangle {
                                        width: 90
                                        height: 26
                                        radius: 4
                                        color: Appearance.m3colors.m3surfaceContainerHigh
                                        StyledText { anchors.centerIn: parent; text: "Super + Space"; font.pixelSize: 11; font.weight: Font.Bold }
                                    }
                                    ColumnLayout {
                                        spacing: 1
                                        StyledText { text: Translation.tr("App Launcher"); font.weight: Font.DemiBold; color: Appearance.colors.colOnLayer0 }
                                        StyledText { text: Translation.tr("Search apps and commands"); font.pixelSize: 11; color: Appearance.colors.colSubtext }
                                    }
                                }
                                MouseArea { id: k1Mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.runCmd(["asura-shell", "launcher"]) }
                            }

                            // 2. Terminal
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 52
                                radius: 8
                                color: k2Mouse.containsMouse ? Appearance.m3colors.m3surfaceContainerHigh : Appearance.m3colors.m3surfaceContainerLowest
                                border.width: 1
                                border.color: Appearance.colors.colOutlineVariant

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 10
                                    Rectangle {
                                        width: 90
                                        height: 26
                                        radius: 4
                                        color: Appearance.m3colors.m3surfaceContainerHigh
                                        StyledText { anchors.centerIn: parent; text: "Super + Enter"; font.pixelSize: 11; font.weight: Font.Bold }
                                    }
                                    ColumnLayout {
                                        spacing: 1
                                        StyledText { text: Translation.tr("Terminal"); font.weight: Font.DemiBold; color: Appearance.colors.colOnLayer0 }
                                        StyledText { text: Translation.tr("Ghostty shell window"); font.pixelSize: 11; color: Appearance.colors.colSubtext }
                                    }
                                }
                                MouseArea { id: k2Mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.runCmd(["asura-app", "terminal"]) }
                            }

                            // 3. Browser
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 52
                                radius: 8
                                color: k3Mouse.containsMouse ? Appearance.m3colors.m3surfaceContainerHigh : Appearance.m3colors.m3surfaceContainerLowest
                                border.width: 1
                                border.color: Appearance.colors.colOutlineVariant

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 10
                                    Rectangle {
                                        width: 90
                                        height: 26
                                        radius: 4
                                        color: Appearance.m3colors.m3surfaceContainerHigh
                                        StyledText { anchors.centerIn: parent; text: "Super + B"; font.pixelSize: 11; font.weight: Font.Bold }
                                    }
                                    ColumnLayout {
                                        spacing: 1
                                        StyledText { text: Translation.tr("Browser"); font.weight: Font.DemiBold; color: Appearance.colors.colOnLayer0 }
                                        StyledText { text: Translation.tr("Default Chromium web browser"); font.pixelSize: 11; color: Appearance.colors.colSubtext }
                                    }
                                }
                                MouseArea { id: k3Mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.runCmd(["asura-app", "browser"]) }
                            }

                            // 4. Asura Settings
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 52
                                radius: 8
                                color: k4Mouse.containsMouse ? Appearance.m3colors.m3surfaceContainerHigh : Appearance.m3colors.m3surfaceContainerLowest
                                border.width: 1
                                border.color: Appearance.colors.colOutlineVariant

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 10
                                    Rectangle {
                                        width: 90
                                        height: 26
                                        radius: 4
                                        color: Appearance.m3colors.m3surfaceContainerHigh
                                        StyledText { anchors.centerIn: parent; text: "Super + I"; font.pixelSize: 11; font.weight: Font.Bold }
                                    }
                                    ColumnLayout {
                                        spacing: 1
                                        StyledText { text: Translation.tr("Asura Settings"); font.weight: Font.DemiBold; color: Appearance.colors.colOnLayer0 }
                                        StyledText { text: Translation.tr("System preferences & devices"); font.pixelSize: 11; color: Appearance.colors.colSubtext }
                                    }
                                }
                                MouseArea { id: k4Mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.runCmd(["asura-shell", "hub", "open"]) }
                            }

                            // 5. System Monitor
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 52
                                radius: 8
                                color: k5Mouse.containsMouse ? Appearance.m3colors.m3surfaceContainerHigh : Appearance.m3colors.m3surfaceContainerLowest
                                border.width: 1
                                border.color: Appearance.colors.colOutlineVariant

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 10
                                    Rectangle {
                                        width: 90
                                        height: 26
                                        radius: 4
                                        color: Appearance.m3colors.m3surfaceContainerHigh
                                        StyledText { anchors.centerIn: parent; text: "Ctrl+Shift+Esc"; font.pixelSize: 11; font.weight: Font.Bold }
                                    }
                                    ColumnLayout {
                                        spacing: 1
                                        StyledText { text: Translation.tr("System Monitor"); font.weight: Font.DemiBold; color: Appearance.colors.colOnLayer0 }
                                        StyledText { text: Translation.tr("btop task manager"); font.pixelSize: 11; color: Appearance.colors.colSubtext }
                                    }
                                }
                                MouseArea { id: k5Mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.runCmd(["asura-app", "terminal", "--", "btop"]) }
                            }

                            // 6. Quick Settings
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 52
                                radius: 8
                                color: k6Mouse.containsMouse ? Appearance.m3colors.m3surfaceContainerHigh : Appearance.m3colors.m3surfaceContainerLowest
                                border.width: 1
                                border.color: Appearance.colors.colOutlineVariant

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 10
                                    Rectangle {
                                        width: 90
                                        height: 26
                                        radius: 4
                                        color: Appearance.m3colors.m3surfaceContainerHigh
                                        StyledText { anchors.centerIn: parent; text: "Super + Esc"; font.pixelSize: 11; font.weight: Font.Bold }
                                    }
                                    ColumnLayout {
                                        spacing: 1
                                        StyledText { text: Translation.tr("Quick Controls"); font.weight: Font.DemiBold; color: Appearance.colors.colOnLayer0 }
                                        StyledText { text: Translation.tr("Audio, network, power menu"); font.pixelSize: 11; color: Appearance.colors.colSubtext }
                                    }
                                }
                                MouseArea { id: k6Mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.runCmd(["asura-shell", "quicksettings"]) }
                            }

                            // 7. Screen Snip
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 52
                                radius: 8
                                color: k7Mouse.containsMouse ? Appearance.m3colors.m3surfaceContainerHigh : Appearance.m3colors.m3surfaceContainerLowest
                                border.width: 1
                                border.color: Appearance.colors.colOutlineVariant

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 10
                                    Rectangle {
                                        width: 90
                                        height: 26
                                        radius: 4
                                        color: Appearance.m3colors.m3surfaceContainerHigh
                                        StyledText { anchors.centerIn: parent; text: "Super+Shift+S"; font.pixelSize: 11; font.weight: Font.Bold }
                                    }
                                    ColumnLayout {
                                        spacing: 1
                                        StyledText { text: Translation.tr("Screen Snip"); font.weight: Font.DemiBold; color: Appearance.colors.colOnLayer0 }
                                        StyledText { text: Translation.tr("Area screenshot to clipboard"); font.pixelSize: 11; color: Appearance.colors.colSubtext }
                                    }
                                }
                                MouseArea { id: k7Mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.runCmd(["asura-cmd-snip"]) }
                            }

                            // 8. Lock Screen
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 52
                                radius: 8
                                color: k8Mouse.containsMouse ? Appearance.m3colors.m3surfaceContainerHigh : Appearance.m3colors.m3surfaceContainerLowest
                                border.width: 1
                                border.color: Appearance.colors.colOutlineVariant

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 10
                                    Rectangle {
                                        width: 90
                                        height: 26
                                        radius: 4
                                        color: Appearance.m3colors.m3surfaceContainerHigh
                                        StyledText { anchors.centerIn: parent; text: "Super + L"; font.pixelSize: 11; font.weight: Font.Bold }
                                    }
                                    ColumnLayout {
                                        spacing: 1
                                        StyledText { text: Translation.tr("Lock Session"); font.weight: Font.DemiBold; color: Appearance.colors.colOnLayer0 }
                                        StyledText { text: Translation.tr("Lock the Wayland display"); font.pixelSize: 11; color: Appearance.colors.colSubtext }
                                    }
                                }
                                MouseArea { id: k8Mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.runCmd(["asura-shell", "lock"]) }
                            }
                        }
                    }
                }

                // ------------------------------------------
                // PAGE 4: DONE
                // ------------------------------------------
                Item {
                    id: pageDone

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, 680)
                        height: Math.min(parent.height, 420)
                        radius: Appearance.rounding.cardRounding
                        color: Appearance.m3colors.m3surfaceContainerLowest
                        border.width: 1
                        border.color: Appearance.colors.colOutlineVariant

                        ColumnLayout {
                            anchors.centerIn: parent
                            width: Math.min(parent.width - 64, 520)
                            spacing: 20

                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 8
                                Text {
                                    text: "//"
                                    color: "#e2342a"
                                    font.family: Appearance.font.family.title
                                    font.pixelSize: 42
                                    font.weight: Font.Black
                                }
                                StyledText {
                                    text: "ASURA OS"
                                    font.pixelSize: 32
                                    font.weight: Font.Bold
                                    color: Appearance.colors.colOnLayer0
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: Translation.tr("The desktop is yours")
                                font.pixelSize: 26
                                font.weight: Font.Bold
                                horizontalAlignment: Text.AlignHCenter
                                color: Appearance.colors.colOnLayer0
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: Translation.tr("You are all set! You can reopen this guide anytime with <tt>Super+Shift+Alt+/</tt>, or customize displays, power profiles, and keybinds in Asura Settings (<tt>Super+I</tt>).")
                                font.pixelSize: Appearance.font.pixelSize.medium
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                color: Appearance.colors.colSubtext
                                lineHeight: 1.4
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: Appearance.colors.colOutlineVariant
                            }

                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 14

                                RippleButtonWithIcon {
                                    materialIcon: "settings"
                                    mainText: Translation.tr("Open Settings")
                                    onClicked: root.runCmd(["asura-shell", "hub", "open"])
                                }

                                RippleButtonWithIcon {
                                    materialIcon: "terminal"
                                    mainText: Translation.tr("Open Terminal")
                                    onClicked: root.runCmd(["asura-app", "terminal"])
                                }

                                RippleButtonWithIcon {
                                    materialIcon: "check"
                                    mainText: Translation.tr("Finish")
                                    colBackground: Appearance.m3colors.m3primary
                                    onClicked: root.finish()
                                }
                            }
                        }
                    }
                }
            }
        }

        // ==========================================
        // 3. BOTTOM NAVIGATION BAR
        // ==========================================
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 52
            color: Appearance.m3colors.m3surfaceContainerLow
            radius: Appearance.rounding.windowRounding - 2

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20

                // Back / Skip Button
                RippleButtonWithIcon {
                    materialIcon: root.currentStep === 0 ? "close" : "arrow_back"
                    mainText: root.currentStep === 0 ? Translation.tr("Skip Tour") : Translation.tr("Back")
                    onClicked: {
                        if (root.currentStep === 0) {
                            root.finish();
                        } else {
                            root.back();
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Step count indicator
                StyledText {
                    text: Translation.tr("Step 0%1 of 0%2").arg(root.currentStep + 1).arg(root.totalSteps)
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colSubtext
                }

                Item { Layout.fillWidth: true }

                // Next / Finish Button
                RippleButtonWithIcon {
                    materialIcon: root.currentStep === root.totalSteps - 1 ? "check" : "arrow_forward"
                    mainText: root.currentStep === root.totalSteps - 1 ? Translation.tr("Finish") : Translation.tr("Next")
                    colBackground: root.currentStep === root.totalSteps - 1 ? Appearance.m3colors.m3primary : Appearance.m3colors.m3surfaceContainerHigh
                    onClicked: root.advance()
                }
            }
        }
    }
}
