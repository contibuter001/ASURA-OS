pragma Singleton
// ASURA overlay (shell-end4/asura/vendor.sh OVERLAYS): the bar always stays in
// the focus grab, so opening a sidebar from it does not close it again.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland

/**
 * Manages a HyprlandFocusGrab that's to be shared by all windows.
 * "Persistent" is for windows that should always be included but not closed on dismiss, like bar and onscreen keyboard.
 * "Dismissable" is for stuff like sidebars
 */ 
Singleton {
    id: root

    signal dismissed()

    property list<var> persistent: []
    property list<var> dismissable: []

    function dismiss() {
        root.dismissable = [];
        root.dismissed();
    }

    Component.onCompleted: {
        console.log("[GlobalFocusGrab] Initialized");
    }

    function addPersistent(window) {
        if (root.persistent.indexOf(window) === -1) {
            root.persistent.push(window);
        }
    }

    function removePersistent(window) {
        var index = root.persistent.indexOf(window);
        if (index !== -1) {
            root.persistent.splice(index, 1);
        }
    }

    function addDismissable(window) {
        if (root.dismissable.indexOf(window) === -1) {
            root.dismissable.push(window);
        }
    }

    function removeDismissable(window) {
        var index = root.dismissable.indexOf(window);
        if (index !== -1) {
            root.dismissable.splice(index, 1);
        }
    }

    function hasActive(element) {
        return element?.activeFocus || Array.from(
            element?.children
        ).some(
            (child) => hasActive(child)
        );
    }

    HyprlandFocusGrab {
        id: grab
        // ASURA: the persistent windows (the bar, the on-screen keyboard) are
        // always in the grab. end-4 left them out until the opened sidebar had
        // keyboard focus, so in that moment a click or pointer event on the
        // bar counted as outside the grab and closed the sidebar it had just
        // opened (on ASURA's Hyprland 0.49, every time).
        windows: [...root.dismissable, ...root.persistent]
        active: root.dismissable.length > 0
        onCleared: () => {
            root.dismiss();
        }
    }

}
