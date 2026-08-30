import "BluetoothModel.js" as Model
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var liveDevices: Bluetooth.devices ? Bluetooth.devices.values : []
    readonly property var deviceRows: Model.rows(liveDevices)
    readonly property int connectedCount: deviceRows.filter(function(row) {
        return row.connected;
    }).length
    readonly property bool autoScan: setting("autoScan", true) !== false
    readonly property bool showAddress: setting("showAddress", false) === true
    readonly property bool reducedMotion: setting("reducedMotion", false) === true
    readonly property color foreground: bar ? bar.foreground : Color.foreground
    readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
    readonly property string icon: !adapter || !adapter.enabled ? "󰂲" : connectedCount > 0 ? "󰂱" : "󰂯"
    // This is a cleanup debt, not merely a snapshot of adapter.discovering.
    // It remains true while BlueZ is confirming a start requested by this panel.
    property bool owesDiscoveryStop: false
    property string pendingAddress: ""
    property string pendingKind: ""
    property string errorMessage: ""
    property int selectedIndex: 0
    property int requestedPower: -1

    function liveDevice(address) {
        for (var index = 0; index < liveDevices.length; index++) if (liveDevices[index] && liveDevices[index].address === address) {
            return liveDevices[index];
        }
        return null;
    }

    function clearPendingIfSettled() {
        if (pendingAddress === "")
            return ;

        var device = liveDevice(pendingAddress);
        if (!device) {
            errorMessage = "The Bluetooth device is no longer available.";
            pendingAddress = "";
            pendingKind = "";
            actionTimeout.stop();
            return ;
        }
        if ((pendingKind === "connecting" && device.connected) || (pendingKind === "disconnecting" && !device.connected)) {
            pendingAddress = "";
            pendingKind = "";
            actionTimeout.stop();
        }
    }

    function act(row) {
        var device = row ? liveDevice(row.address) : null;
        if (!device || pendingAddress !== "")
            return ;

        errorMessage = "";
        pendingAddress = row.address;
        if (row.connected) {
            pendingKind = "disconnecting";
            device.disconnect();
        } else {
            pendingKind = "connecting";
            if (row.remembered)
                device.connect();
            else
                device.pair();
        }
        actionTimeout.restart();
    }

    function togglePower() {
        if (!adapter || requestedPower !== -1)
            return ;

        errorMessage = "";
        requestedPower = adapter.enabled ? 0 : 1;
        powerTimeout.restart();
        adapter.enabled = requestedPower === 1;
    }

    function beginDiscovery() {
        if (!opened || !autoScan || !adapter || !adapter.enabled || adapter.discovering)
            return ;

        owesDiscoveryStop = true;
        adapter.discovering = true;
    }

    function openSibling() {
        if (!bar || typeof bar.moduleWidgets !== "function")
            return null;

        var widgets = bar.moduleWidgets(moduleName);
        for (var index = 0; index < widgets.length; index++) if (widgets[index] && widgets[index] !== root && widgets[index].opened) {
            return widgets[index];
        }
        return null;
    }

    function open() {
        controller.show();
        errorMessage = "";
        selectedIndex = 0;
        discoveryStart.restart();
        entrance.restart();
    }

    function close() {
        controller.hide();
        discoveryStart.stop();
    }

    function toggle() {
        opened ? close() : open();
    }

    function moveSelection(delta) {
        if (deviceRows.length === 0)
            return ;

        selectedIndex = Math.max(0, Math.min(deviceRows.length - 1, selectedIndex + delta));
        if (deviceList.itemAtIndex(selectedIndex))
            deviceList.positionViewAtIndex(selectedIndex, ListView.Contain);

    }

    function selectedRow() {
        return selectedIndex >= 0 && selectedIndex < deviceRows.length ? deviceRows[selectedIndex] : null;
    }

    moduleName: "somnius.serpantinum-bluetooth"
    ipcTarget: moduleName
    manageIpc: false
    onDeviceRowsChanged: {
        selectedIndex = Math.max(0, Math.min(selectedIndex, deviceRows.length - 1));
        clearPendingIfSettled();
    }
    Component.onDestruction: {
        if (!owesDiscoveryStop)
            return ;

        var widgets = bar && typeof bar.moduleWidgets === "function" ? bar.moduleWidgets(moduleName) : [];
        for (var index = 0; index < widgets.length; index++) {
            if (widgets[index] && widgets[index] !== root) {
                widgets[index].owesDiscoveryStop = true;
                return ;
            }
        }
        if (adapter && adapter.discovering)
            adapter.discovering = false;

    }
    visible: true
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    Timer {
        id: discoveryStart

        interval: 350
        repeat: false
        onTriggered: root.beginDiscovery()
    }

    Timer {
        id: discoveryStop

        property int attempts: 0

        interval: 1000
        repeat: true
        running: !root.opened && root.owesDiscoveryStop && root.adapter && root.adapter.discovering === true
        onRunningChanged: {
            if (running) {
                attempts = 0;
            }
        }
        onTriggered: {
            var sibling = root.openSibling();
            if (sibling) {
                sibling.owesDiscoveryStop = true;
                root.owesDiscoveryStop = false;
                return ;
            }
            attempts += 1;
            if (attempts > 3) {
                root.owesDiscoveryStop = false;
                return ;
            }
            root.adapter.discovering = false;
        }
    }

    Timer {
        id: actionTimeout

        interval: 20000
        repeat: false
        onTriggered: {
            root.errorMessage = root.pendingKind === "connecting" ? "Could not connect. Check the device and try again." : "Could not disconnect. Try again.";
            root.pendingAddress = "";
            root.pendingKind = "";
        }
    }

    Timer {
        id: powerTimeout

        interval: 5000
        repeat: false
        onTriggered: {
            if (root.adapter && root.adapter.enabled !== (root.requestedPower === 1))
                root.errorMessage = "Could not change Bluetooth power. Check BlueZ permissions.";

            root.requestedPower = -1;
        }
    }

    Connections {
        function onEnabledChanged() {
            if (root.requestedPower !== -1 && root.adapter.enabled === (root.requestedPower === 1)) {
                root.requestedPower = -1;
                powerTimeout.stop();
            }
            if (!root.adapter.enabled)
                root.owesDiscoveryStop = false;
            else if (root.opened)
                discoveryStart.restart();
        }

        function onDiscoveringChanged() {
            if (!root.adapter.discovering && root.opened && root.autoScan)
                discoveryStart.restart();

            if (!root.adapter.discovering)
                root.owesDiscoveryStop = false;

        }

        target: root.adapter
    }

    SequentialAnimation {
        id: entrance

        PropertyAction {
            target: panelContent
            property: "opacity"
            value: root.reducedMotion ? 1 : 0
        }

        PropertyAction {
            target: panelContent
            property: "scale"
            value: root.reducedMotion ? 1 : 0.94
        }

        ParallelAnimation {
            NumberAnimation {
                target: panelContent
                property: "opacity"
                to: 1
                duration: root.reducedMotion ? 0 : 180
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: panelContent
                property: "scale"
                to: 1
                duration: root.reducedMotion ? 0 : 260
                easing.type: Easing.OutBack
                easing.overshoot: 0.55
            }

        }

    }

    IpcHandler {
        function open() {
            root.open();
        }

        function close() {
            root.close();
        }

        function show() {
            root.open();
        }

        function hide() {
            root.close();
        }

        function toggle() {
            root.toggle();
        }

        function toggleBluetooth() {
            root.togglePower();
        }

        target: root.moduleName
    }

    BarIconButton {
        id: button

        anchors.fill: parent
        bar: root.bar
        text: root.icon
        tooltipText: !root.adapter ? "Bluetooth unavailable" : root.connectedCount > 0 ? root.connectedCount + " Bluetooth device" + (root.connectedCount === 1 ? "" : "s") : root.adapter.enabled ? "Bluetooth on" : "Bluetooth off"
        onPressed: function(mouseButton) {
            if (mouseButton === Qt.RightButton)
                root.togglePower();
            else
                root.toggle();
        }
    }

    KeyboardPanel {
        id: popup

        anchorItem: button
        owner: root
        bar: root.bar
        open: root.opened
        focusTarget: keys
        contentWidth: fittedContentWidth(Style.space(390))
        contentHeight: fittedContentHeight(panelContent.implicitHeight, Style.space(620))

        PanelKeyCatcher {
            id: keys

            anchors.fill: parent
            onMoveRequested: function(dx, dy) {
                if (dy !== 0)
                    root.moveSelection(dy);

            }
            onActivateRequested: root.act(root.selectedRow())
            onCloseRequested: root.close()
            onTabRequested: function(direction) {
                root.switchPanel(direction);
            }
            onTextKey: function(text) {
                if (text === "b" || text === "B")
                    root.togglePower();

            }

            Column {
                id: panelContent

                width: parent.width
                spacing: Style.space(14)
                transformOrigin: Item.Center

                Item {
                    width: parent.width
                    height: Style.space(58)

                    Rectangle {
                        id: orbit

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: Style.space(50)
                        height: width
                        radius: width / 2
                        color: Style.selectedFillFor(root.foreground, Color.accent)
                        rotation: 0

                        Rectangle {
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Style.space(6)
                            height: width
                            radius: width / 2
                            color: Color.accent
                        }

                        Text {
                            anchors.centerIn: parent
                            text: root.icon
                            color: root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.title
                        }

                        NumberAnimation on rotation {
                            running: root.opened && root.adapter && root.adapter.discovering && !root.reducedMotion
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 3200
                        }

                    }

                    Column {
                        anchors.left: orbit.right
                        anchors.leftMargin: Style.space(14)
                        anchors.right: power.right
                        anchors.rightMargin: power.width + Style.space(12)
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            width: parent.width
                            text: "Bluetooth"
                            color: root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.title
                            font.bold: true
                        }

                        Text {
                            width: parent.width
                            text: !root.adapter ? "BLUEZ OR ADAPTER UNAVAILABLE" : !root.adapter.enabled ? "POWERED OFF" : root.adapter.discovering ? "SCANNING · " + root.connectedCount + " CONNECTED" : root.connectedCount + " CONNECTED"
                            color: root.foreground
                            opacity: 0.58
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            font.bold: true
                            elide: Text.ElideRight
                        }

                    }

                    ToggleSwitch {
                        id: power

                        visible: !!root.adapter
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        checked: !!root.adapter && root.adapter.enabled
                        foreground: root.foreground
                        onToggled: root.togglePower()
                    }

                }

                PanelSeparator {
                    foreground: root.foreground
                }

                Text {
                    visible: root.errorMessage !== ""
                    width: parent.width
                    text: root.errorMessage
                    color: Color.urgent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    wrapMode: Text.WordWrap
                }

                ListView {
                    id: deviceList

                    width: parent.width
                    height: Math.min(contentHeight, Style.space(400))
                    model: root.deviceRows
                    spacing: Style.space(7)
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height
                    currentIndex: root.selectedIndex

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }

                    delegate: CursorSurface {
                        required property var modelData
                        required property int index

                        width: ListView.view.width
                        height: Style.space(root.showAddress ? 64 : 52)
                        hasCursor: index === root.selectedIndex
                        current: modelData.connected
                        foreground: root.foreground
                        fill: Style.hoverFillFor(root.foreground, Color.accent)
                        currentFill: Style.selectedFillFor(root.foreground, Color.accent)

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.selectedIndex = index
                            onClicked: root.act(modelData)
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.right: actionText.left
                            anchors.leftMargin: Style.space(12)
                            anchors.rightMargin: Style.space(10)
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                width: parent.width
                                text: modelData.name
                                color: root.foreground
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.body
                                font.bold: modelData.connected
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: root.showAddress ? modelData.address : Model.status(modelData, root.pendingAddress === modelData.address ? root.pendingKind : "")
                                color: root.foreground
                                opacity: 0.58
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.caption
                                elide: Text.ElideRight
                            }

                        }

                        Text {
                            id: actionText

                            anchors.right: parent.right
                            anchors.rightMargin: Style.space(12)
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.pendingAddress === modelData.address ? "…" : modelData.connected ? "Disconnect" : modelData.remembered ? "Connect" : "Pair"
                            color: root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            font.bold: true
                        }

                    }

                }

                Text {
                    visible: root.deviceRows.length === 0
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: !root.adapter ? "No Bluetooth adapter was found." : !root.adapter.enabled ? "Turn Bluetooth on to discover devices." : root.autoScan ? "Scanning for nearby devices…" : "No known devices. Automatic scanning is disabled."
                    color: root.foreground
                    opacity: 0.62
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    wrapMode: Text.WordWrap
                }

            }

        }

    }

}
