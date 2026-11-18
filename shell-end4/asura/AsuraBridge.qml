import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs
import qs.modules.common
import qs.modules.common.functions

// The ASURA bridge. ASURA's keybindings (session/hyprland/binds.conf) do not
// talk to a shell directly: they run `asura ipc call asura <function>`, and
// `asura ipc` delivers that to whichever desktop shell is running. In ASURA's
// own shell the `asura` target is in shell.qml; when the end-4 desktop runs,
// this file answers the same twelve functions by driving end-4's own
// surfaces, so every shortcut keeps working without one binding changing.
//
// end-4 opens most surfaces through GlobalStates flags, which are set here
// directly. The cheatsheet, the region selector's actions and the clipboard
// search live inside their modules and are reachable only through end-4's
// own IPC targets, so those are called through `quickshell ipc` on this same
// config.
Item {
    id: bridge

    readonly property string configPath: FileUtils.trimFileProtocol(Quickshell.shellPath(""))

    function callSelf(target: string, fn: string): void {
        Quickshell.execDetached(["quickshell", "ipc", "--path", bridge.configPath, "call", target, fn]);
    }

    // ── First login on this desktop ─────────────────────────────────────────
    // Once end-4's config has loaded: seed matugen and a palette from the
    // user's ASURA wallpaper (asura/first-run.sh, which never overwrites), and
    // keep the bar on top and pin the dock with ASURA's apps (end-4 ships it off and
    // hidden). The dock is set once per user,
    // remembered by a marker, so a user who turns it off keeps it off.
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/asura"
    property bool firstRunDone: false
    function firstRun(): void {
        if (bridge.firstRunDone || !Config.ready)
            return;
        bridge.firstRunDone = true;
        Quickshell.execDetached(["sh", bridge.configPath + "/asura/first-run.sh"]);
        dockMarker.running = true;
    }
    Connections {
        target: Config
        function onReadyChanged(): void { bridge.firstRun(); }
    }
    Component.onCompleted: {
        bridge.squareCorners();
        bridge.firstRun();
    }

    // ASURA's look is square, like Omarchy's: every radius end-4 draws comes
    // from Appearance.rounding, so zeroing it here squares the bar, panels,
    // buttons and popups without editing a vendored file. Windows are squared
    // in asura/hyprland.conf.
    function squareCorners(): void {
        const r = Appearance.rounding;
        r.unsharpen = 0;
        r.unsharpenmore = 0;
        r.verysmall = 0;
        r.small = 0;
        r.normal = 0;
        r.large = 0;
        r.verylarge = 0;
        r.full = 0;
        r.screenRounding = 0;
        r.windowRounding = 0;
    }
    Process {
        id: dockMarker
        command: ["sh", "-c", "m=\"$1/end4-layout-3\"; [ -e \"$m\" ] && exit 1; mkdir -p \"$1\" && touch \"$m\"", "sh", bridge.stateDir]
        onExited: (code) => {
            if (code !== 0)
                return;
            // end-4 pins KDE's Dolphin and kitty, which ASURA does not ship,
            // and hides the dock until the pointer reaches the bottom edge.
            // The bar stays on top. Undoes the vertical bar an earlier
            // build set (end4-layout-1); a user's own choice comes later.
            Config.options.bar.vertical = false;
            // ASURA's square look (as Omarchy): a plain rectangular bar, no
            // rounded screen corners, the digital desktop clock.
            Config.options.bar.cornerStyle = 2;
            Config.options.appearance.fakeScreenRounding = 0;
            Config.options.background.widgets.clock.style = "digital";
            Config.options.background.widgets.clock.styleLocked = "digital";
            Config.options.dock.enable = true;
            Config.options.dock.pinnedOnStartup = true;
            Config.options.dock.pinnedApps = ["com.mitchellh.ghostty", "thunar", "firefox", "asura-store"];
        }
    }

    IpcHandler {
        target: "asura"

        // Super+Space (launcher), Super+Alt+Space (menu): end-4's search is
        // its overview. Super+Escape (quick) and Super+N (sidebar): end-4's
        // quick settings and notifications are its right sidebar.
        function togglePopover(name: string): void {
            switch (name) {
            case "quick":
            case "sidebar":
                GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
                break;
            default:
                GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
            }
        }

        function toggleOverview(): void {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }

        // ASURA's desktops are blocks of workspaces; end-4 has none, so a
        // desktop step is a workspace step, the way end-4's own bar scrolls.
        function overviewDesktop(delta: int): void {
            Hyprland.dispatch(delta >= 0 ? "workspace r+1" : "workspace r-1");
        }

        // Alt+Tab. end-4 has no window switcher, so the compositor cycles.
        function advanceSwitcher(): void {
            Hyprland.dispatch("cyclenext");
            Hyprland.dispatch("bringactivetotop");
        }
        function reverseSwitcher(): void {
            Hyprland.dispatch("cyclenext prev");
            Hyprland.dispatch("bringactivetotop");
        }
        function closeSwitcher(): void {
        }

        function toggleCheatsheet(): void {
            bridge.callSelf("cheatsheet", "toggle");
        }

        function session(): void {
            GlobalStates.sessionOpen = !GlobalStates.sessionOpen;
        }

        function ocr(): void {
            bridge.callSelf("region", "ocr");
        }

        function toggleScreenshot(): void {
            bridge.callSelf("region", "screenshot");
        }

        // ASURA surfaces with an end-4 counterpart open it; the rest (stash,
        // the visualizer) have none and do nothing in this desktop.
        function toggleSurface(name: string): void {
            switch (name) {
            case "overview":
                GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
                break;
            case "clipboard":
                bridge.callSelf("search", "clipboardToggle");
                break;
            case "screenshot":
                bridge.callSelf("region", "screenshot");
                break;
            case "cheatsheet":
                bridge.callSelf("cheatsheet", "toggle");
                break;
            }
        }

        // ASURA's settings live in GSettings; end-4 reads its own config
        // file and watches it, so there is nothing to reload here.
        function reloadSettings(): void {
        }
    }
}
