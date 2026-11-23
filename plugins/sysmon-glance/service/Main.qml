pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: svc

    property var pluginApi
    readonly property var settings: pluginApi ? pluginApi.pluginSettings : null

    property int cpuPercent: 0
    property int memPercent: 0
    property int cpuTemp: 0
    property int gpuPercent: 0

    property string _buffer: ""

    Process {
        id: statsProc
        command: ["asura-sysmon", "stats", "--interval", "100"]
        stdout: SplitParser {
            onRead: (line) => {
                svc._buffer += line;
            }
        }
        onExited: (code) => {
            if (code === 0 && svc._buffer.length > 0) {
                try {
                    const data = JSON.parse(svc._buffer);
                    if (data.cpu) {
                        svc.cpuPercent = Math.round(data.cpu.usagePercent || 0);
                        svc.cpuTemp = Math.round(data.cpu.tempC || 0);
                    }
                    if (data.memory) {
                        svc.memPercent = Math.round(data.memory.usedPercent || 0);
                    }
                    if (data.gpus && data.gpus.length > 0) {
                        svc.gpuPercent = Math.round(data.gpus[0].utilizationPct || 0);
                    }
                } catch (e) {
                }
            }
            svc._buffer = "";
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!statsProc.running) {
                svc._buffer = "";
                statsProc.running = true;
            }
        }
    }
}
