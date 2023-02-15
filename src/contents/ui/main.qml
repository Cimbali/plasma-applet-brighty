/*
 * Copyright 2018  Misagh Lotfi Bafandeh <misaghlb@live.com>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http: //www.gnu.org/licenses/>.
 */
import QtQuick 2.2
import QtQuick.Layouts 1.1
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore

import "edid.js" as EDID

Item {
    id: main

    anchors.fill: parent

    property ListModel outputs: ListModel {}

    property double brightnessStep: plasmoid.configuration.stepBrightnessPercent / 100
    property double brightnessMin: plasmoid.configuration.minBrightnessPercent / 100
    property double brightnessMax: plasmoid.configuration.maxBrightnessPercent / 100

    function listModelFindIndex(listModel, pred) {
        for (let i = 0; i < listModel.count; i++) {
            if (pred(listModel.get(i))) {
                return i;
            }
        }
        return -1;
    }

    function clipBrightness(val) {
        if (val < brightnessMin) {
            return brightnessMin
        }
        if (val > brightnessMax) {
            return brightnessMax
        }
        return val
    }

    Plasmoid.preferredRepresentation: Plasmoid.compactRepresentation
    Plasmoid.compactRepresentation: CompactRepresentation { }
    Plasmoid.fullRepresentation: FullRepresentation {}

    Plasmoid.status: listModelFindIndex(outputs, ({ controlled }) => controlled) !== -1
        ? PlasmaCore.Types.ActiveStatus
        : PlasmaCore.Types.PassiveStatus

    Plasmoid.toolTipMainText: i18n('Monitor Brightness')
    Plasmoid.toolTipSubText: i18n('Control brightness of built-in and external monitors')
    Plasmoid.toolTipTextFormat: Text.RichText
    Plasmoid.icon: 'video-display-brightness'


    PlasmaCore.DataSource {
        id: xrandr
        engine: 'executable'

        readonly property string verboseXrandrCommand: "xrandr --verbose"

        function outputName(name, { isLaptopScreen, edid }) {
            if (isLaptopScreen) {
                return i18nd('kscreen_common', 'Built-in Screen')
            }
            if (edid) {
                try {
                    const { vendor, model } = EDID.parseHex(edid);
                    const screenType = name.replace(/(-[0-9]+)*$/, '').replace(/^DP$/, 'DisplayPort');
                    const typeSuffix = screenType ?  (' (' + screenType + ')') : '';
                    if (vendor && model) {
                        return vendor + ' ' + model + typeSuffix
                    } else if (vendor) {
                        return vendor + typeSuffix
                    } else if (model) {
                        return model + typeSuffix
                    }
                } catch (error) {
                    console.error(`Error while parsing EDID for screen ${name}: ${error}`)
                }
            }
            return name
        }

        function parseVerboseXrandr(output) {
            const data = {}
            let name, isConnected = false, readingEdid = false;
            for (const line of output.split('\n')) {
                // Continuing EDID
                if (readingEdid) {
                    if (line.startsWith('\t\t')) {
                        data[name]['edid'] += line.slice(2);
                        continue;
                    } else {
                        readingEdid = false;
                    }
                }
                // New screen start
                if (!line.startsWith(' ') && !line.startsWith('\t')) {
                    [name, isConnected] = line.split(' ', 3)
                    isConnected = (isConnected === 'connected')
                    readingEdid = false;
                    if (isConnected) {
                        data[name] = {
                            brightness: 1.,
                            // libkscreen logic to identify embedded screens
                            isLaptopScreen: name.match(/^(LVDS|IDP|EDP|LCD|DSI)/i) !== null
                        };
                    }
                }
                // After a connected screen start, search for brightness value
                else if (isConnected) {
                    const [key, ...value] = line.split(':', 2)
                    if (key.trim() === 'Brightness') {
                        data[name]['brightness'] = parseFloat(value[0].trim())
                    }
                    else if (key.trim() === 'EDID') {
                        data[name]['edid'] = '';
                        readingEdid = true;
                    }
                }
            }
            return data
        }

        function updateOutputs(parsedData) {
            // Update list of monitors: set brightness or remove if they are not in xrandr output anymore
            for (let i = 0; i < outputs.count; ) {
                const { name } = outputs.get(i);
                if (name in parsedData) {
                    const { brightness, isLaptopScreen } = parsedData[name];
                    const update = { brightness };
                    if (isLaptopScreen) {
                        update.brightness *= pmSource.getBacklight();
                    }
                    outputs.set(i, update)
                    delete parsedData[name];
                    ++i;
                } else {
                    outputs.remove(i, 1)
                }
            }

            // Append new monitors to list
            for (const [name, screen] of Object.entries(parsedData)) {
                const newScreen = Object.assign({ name, outputName: outputName(name, screen), controlled: true }, screen);
                if (screen.isLaptopScreen) {
                    newScreen.brightness *= pmSource.getBacklight();
                    pmSource.screenName = name;
                }
                outputs.append(newScreen)
            }
        }

        function refresh() {
            connectedSources.push(verboseXrandrCommand)
        }

        onNewData: {
            connectedSources.length = 0
            if (sourceName == verboseXrandrCommand) {
                const parsedData = parseVerboseXrandr(data.stdout);
                updateOutputs(parsedData);
            }
        }

        function stillUpdating() {
            return connectedSources.indexOf(/^xrandr --output/) !== -1;
        }

        function setBrightness(levels) {
            // No spamming
            if (stillUpdating()) {
                return
            }

            if (pmSource.screenName in levels) {
                // Do the backlight screen all in HW or compensate
                levels[pmSource.screenName] = pmSource.setBacklight(levels[pmSource.screenName]);
            }

            const cmd = Object.entries(levels).map(
                ([name, brightness]) => `--output ${name} --brightness ${brightness.toFixed(2)}`
            );

            if (cmd.length) {
                connectedSources.push(`xrandr ${cmd.join(' ')}`)
            }
        }
    }

    Timer {
        id: delayedAllowRefresh
        interval: 200
        onTriggered: {
            pmSource.triggerRefresh = true;
        }
    }

    PlasmaCore.DataSource {
        id: pmSource
        engine: 'powermanagement'
        connectedSources: ['PowerDevil']

        onSourceAdded: {
            disconnectSource(source);
            connectSource(source);
        }

        onSourceRemoved: {
            disconnectSource(source);
        }

        property bool triggerRefresh: false;

        onDataChanged: {
            if (triggerRefresh) {
                xrandr.refresh()
            }
        }

        /* Name of the controlled screen, if any */
        property string screenName: ''

        /* Some getters/setters for readability */
        function hasBrightness() {
            if (!data['PowerDevil']) {
                return false;
            }
            if (!data['PowerDevil']['Screen Brightness Available']) {
                return false;
            }
            return true;
        }

        function getMaxBrightness() {
            return data['PowerDevil']['Maximum Screen Brightness'];
        }

        function getBrightness() {
            return data['PowerDevil']['Screen Brightness'];
        }

        function setBrightness(level) {
            // Stolen from org.kde.plasma.battery plasmoid
            const service = this.serviceForSource('PowerDevil');
            const operation = service.operationDescription('setBrightness');
            operation.brightness = level;
            // show OSD only when the plasmoid isn't expanded since the moving slider is feedback enough
            operation.silent = Plasmoid.expanded;
            // Don’t call and parse a full xrandr --verbose when we are the ones causing onDataChange
            triggerRefresh = false;
            service.startOperationCall(operation).finished.connect(job => {
                delayedAllowRefresh.start();
            });
        }

        /* Actual interface */
        function getBacklight() {
            if (hasBrightness()) {
                return getBrightness() / getMaxBrightness();
            }
            return 1.;
        }

        function setBacklight(value) {
            // Return the value to set in a SW filter so that we achieve requested backlight
            // multiplicatively, i.e.: <requested value> = <set value> * <returned value>
            if (!hasBrightness()) {
                return value;
            }

            const max = getMaxBrightness();
            const level = Math.round(value * max);

            // If instead of value we set 1/max (which only happens when value * max < 0.5), return (value) / (1. / max)
            setBrightness(Math.max(level, 1));
            return Math.min(value * max, 1.);
        }
    }

    Timer {
        id: delayedStartWatching
        interval: 200
        onTriggered: {
            dbusWatcher.start()
        }
    }

    PlasmaCore.DataSource {
        id: dbusWatcher
        engine: 'executable'
        readonly property var dbusWatchExpressions: [
            "type='signal',sender='org.kde.KScreen',path='/backend',interface='org.kde.kscreen.Backend',member='configChanged'",
            "type='signal',sender='org.kde.KScreen',path='/modules/kscreen',interface='org.kde.KScreen',member='outputConnected'",
        ]
        readonly property string sedStopAtFirstMessage:  '/interface=org.freedesktop.DBus; member=Name(Lost|Acquired)>/,+1d;q'

        function start() {
            connectedSources.push(`dbus-monitor ${dbusWatchExpressions.join(' ')} | stdbuf -i0 sed -r '${sedStopAtFirstMessage}'`)
        }

        onNewData: {
            connectedSources.length = 0;
            xrandr.refresh();
            // Need this delay to avoid call stack overflow
            delayedStartWatching.start()
        }
    }

    Component.onCompleted: {
        xrandr.refresh()
        dbusWatcher.start()
    }
}
