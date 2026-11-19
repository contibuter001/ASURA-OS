// ASURA overlay (shell-end4/asura/vendor.sh OVERLAYS): end-4's dock button
// without the window-count marks under a running app's icon.
import qs.services
import qs.modules.common
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets

DockButton {
    id: root
    property var appToplevel
    property var appListRoot
    property int lastFocused: -1
    property real iconSize: 35
    property real countDotWidth: 10
    property real countDotHeight: 4
    property bool appIsActive: appToplevel?.toplevels ? (appToplevel.toplevels.find(t => (t.activated == true)) !== undefined) : false

    readonly property bool isSeparator: appToplevel?.appId === "SEPARATOR"
    property var desktopEntry: resolveDesktopEntry()

    function resolveDesktopEntry() {
        if (root.isSeparator || !appToplevel?.appId) return null;
        let id = appToplevel.appId;
        let entry = DesktopEntries.byId(id) || DesktopEntries.heuristicLookup(id);
        if (entry) return entry;

        let idLower = id.toLowerCase();
        // File manager fallback (e.g. thunar on systems with nautilus/dolphin/pcmanfm)
        if (idLower.includes("thunar") || idLower.includes("file") || idLower.includes("fm") || idLower.includes("nautilus")) {
            for (let name of ["thunar", "org.gnome.Nautilus", "nautilus", "org.kde.dolphin", "pcmanfm"]) {
                let e = DesktopEntries.byId(name) || DesktopEntries.heuristicLookup(name);
                if (e) return e;
            }
        }
        // Browser fallback (e.g. firefox on systems with brave/chrome)
        if (idLower.includes("firefox") || idLower.includes("browser") || idLower.includes("web")) {
            for (let name of ["firefox", "brave-browser", "google-chrome", "chromium", "com.brave.Browser", "com.google.Chrome"]) {
                let e = DesktopEntries.byId(name) || DesktopEntries.heuristicLookup(name);
                if (e) return e;
            }
        }
        // Terminal fallback
        if (idLower.includes("ghostty") || idLower.includes("term") || idLower.includes("terminal")) {
            for (let name of ["com.mitchellh.ghostty", "ghostty", "kitty", "foot", "org.gnome.Ptyxis", "alacritty"]) {
                let e = DesktopEntries.byId(name) || DesktopEntries.heuristicLookup(name);
                if (e) return e;
            }
        }

        // Search by substring in DesktopEntries
        if (DesktopEntries?.applications?.values) {
            for (let app of DesktopEntries.applications.values) {
                let appIdLower = (app.id ?? "").toLowerCase();
                let appNameLower = (app.name ?? "").toLowerCase();
                if (appIdLower === idLower || appIdLower.includes(idLower) || appNameLower.includes(idLower)) {
                    return app;
                }
            }
        }
        return null;
    }

    // Apps start through Hyprland's exec, so they get the compositor's full
    // session environment (Wayland display, D-Bus, XDG_*): the shell itself
    // runs under a runit supervisor started before the compositor, and an app
    // it spawned directly could miss what a Wayland client needs.
    function shellQuote(arg) {
        return "'" + String(arg).replace(/'/g, "'\\''") + "'";
    }
    function hyprExec(argv) {
        const line = argv.map(root.shellQuote).join(" ");
        console.log("[dock] launching:", line);
        Hyprland.dispatch("exec " + line);
    }

    function launchApp() {
        const entry = root.desktopEntry;
        const command = entry && entry.command ? Array.from(entry.command) : [];
        if (command.length > 0) {
            root.hyprExec(entry.runInTerminal ? ["ghostty", "-e"].concat(command) : command);
            return;
        }
        if (entry) {
            console.log("[dock] launching", entry.id, "with execute(): it has no parsed command");
            entry.execute();
            return;
        }

        // No desktop entry: what the pinned id plainly names.
        const idLower = (appToplevel?.appId ?? "").toLowerCase();
        if (idLower === "asura-store") {
            root.hyprExec(["asura-store", "open", "discover"]);
        } else if (idLower.includes("thunar") || idLower.includes("nautilus")) {
            root.hyprExec(["xdg-open", Directories.home]);
        } else if (idLower.includes("ghostty") || idLower.includes("term")) {
            root.hyprExec(["ghostty"]);
        } else if (appToplevel?.appId) {
            root.hyprExec([appToplevel.appId]);
        } else {
            console.warn("[dock] nothing to launch: the button has no app id");
        }
    }

    enabled: !isSeparator
    implicitWidth: isSeparator ? 1 : implicitHeight - topInset - bottomInset

    Connections {
        target: DesktopEntries

        function onApplicationsChanged() {
            root.desktopEntry = root.resolveDesktopEntry();
        }
    }

    Loader {
        active: isSeparator
        anchors {
            fill: parent
            topMargin: dockVisualBackground.margin + dockRow.padding + Appearance.rounding.normal
            bottomMargin: dockVisualBackground.margin + dockRow.padding + Appearance.rounding.normal
        }
        sourceComponent: DockSeparator {}
    }

    Loader {
        anchors.fill: parent
        active: appToplevel?.toplevels ? appToplevel.toplevels.length > 0 : false
        sourceComponent: MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onEntered: {
                appListRoot.lastHoveredButton = root
                appListRoot.buttonHovered = true
                lastFocused = appToplevel.toplevels.length - 1
            }
            onExited: {
                if (appListRoot.lastHoveredButton === root) {
                    appListRoot.buttonHovered = false
                }
            }
        }
    }

    onClicked: {
        if (!appToplevel?.toplevels || appToplevel.toplevels.length === 0) {
            root.launchApp();
            return;
        }
        lastFocused = (lastFocused + 1) % appToplevel.toplevels.length
        appToplevel.toplevels[lastFocused].activate()
    }

    middleClickAction: () => {
        root.launchApp();
    }

    altAction: () => {
        if (appToplevel?.appId) {
            TaskbarApps.togglePin(appToplevel.appId);
        }
    }

    contentItem: Loader {
        active: !isSeparator
        sourceComponent: Item {
            anchors.centerIn: parent

            Loader {
                id: iconImageLoader
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                active: !root.isSeparator
                sourceComponent: IconImage {
                    source: {
                        if (root.desktopEntry && root.desktopEntry.icon) {
                            return Quickshell.iconPath(root.desktopEntry.icon, "image-missing");
                        }
                        return Quickshell.iconPath(AppSearch.guessIcon(appToplevel?.appId ?? ""), "image-missing");
                    }
                    implicitSize: root.iconSize
                }
            }

            Loader {
                active: Config.options.dock.monochromeIcons
                anchors.fill: iconImageLoader
                sourceComponent: Item {
                    Desaturate {
                        id: desaturatedIcon
                        visible: false // There's already color overlay
                        anchors.fill: parent
                        source: iconImageLoader
                        desaturation: 0.8
                    }
                    ColorOverlay {
                        anchors.fill: desaturatedIcon
                        source: desaturatedIcon
                        color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.9)
                    }
                }
            }
        }
    }
}
