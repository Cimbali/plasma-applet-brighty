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

    readonly property string verboseXrandrCommand: "xrandr --verbose"
    /* NB. order of find args is important: only print/quit if cat was successful */
    readonly property string findBacklightDevices: "find /sys/class/backlight -mindepth 1 -maxdepth 1 -type l -exec cat {}/brightness {}/max_brightness ';' -print -quit"
    readonly property string setBacklightOnDbus: "`which qdbus6 || which qdbus-qt5` --system org.freedesktop.login1 /org/freedesktop/login1/session/auto org.freedesktop.login1.Session.SetBrightness backlight"

    property ListModel outputs: ListModel {}
    property var backlightScreen: Object({})

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

    function cmdBacklightBrightness(value) {
        const { device } = backlightScreen;
        Object.assign(backlightScreen, { value })
        return `${setBacklightOnDbus} ${device} ${value}`;
    }

    function setBrightness(levels) {
        // No spamming
        if (brightyDS.connectedSources.length !== 0) {
            return
        }

        let cmd = [];

        const { allowed, max, value, name: backlightName } = backlightScreen;
        if (backlightName in levels) {
            // Do the backlight screen all in HW or compensate
            if (allowed) {
                cmd.push(cmdBacklightBrightness(Math.round(levels[backlightName] * max)))
                levels[backlightName] = 1.;
            } else {
                levels[backlightName] = clipBrightness(levels[backlightName] * max / value);
            }
        }

        cmd.push(...Object.entries(levels).map(
            ([name, brightness]) => `xrandr --output ${name} --brightness ${brightness.toFixed(2)}`
        ));

        if (cmd.length > 1) {
            brightyDS.connectedSources.push(cmd.join(' ; '))
        }
    }

    Plasmoid.preferredRepresentation: Plasmoid.compactRepresentation
    Plasmoid.compactRepresentation: CompactRepresentation { }
    Plasmoid.fullRepresentation: FullRepresentation {}

    Plasmoid.status: listModelFindIndex(outputs, ({ controlled }) => controlled) !== -1
        ? PlasmaCore.Types.ActiveStatus
        : PlasmaCore.Types.PassiveStatus

    Plasmoid.toolTipMainText: i18n('External Monitor Brightness Control')
    Plasmoid.toolTipSubText: i18n('Control External Monitor Brightness')
    Plasmoid.toolTipTextFormat: Text.RichText
    Plasmoid.icon: 'video-display-brightness'


    PlasmaCore.DataSource {
        id: brightyDS
        engine: 'executable'

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
                    const { brightness } = parsedData[name];
                    outputs.set(i, { brightness })
                    delete parsedData[name];
                    ++i;
                    if (name === backlightScreen.name) {
                        brightyDS.connectedSources.push(findBacklightDevices)
                    }
                } else {
                    outputs.remove(i, 1)
                }
            }

            // Append new monitors to list
            for (const [name, screen] of Object.entries(parsedData)) {
                outputs.append(Object.assign({ name, outputName: outputName(name, screen), controlled: true }, screen))
                if (screen.isLaptopScreen && !('name' in backlightScreen)) {
                    Object.assign(backlightScreen, { name })
                    brightyDS.connectedSources.push(findBacklightDevices)
                }
            }
        }

        function updateBacklight({ current, max, device }) {
            const { allowed, name } = backlightScreen;

            // Try setting it to its current value to check permissions
            if (!allowed) {
                Object.assign(backlightScreen, { device, max });
                brightyDS.connectedSources.push(cmdBacklightBrightness(current))
            }

            // Update xrandr brightness with backlight brightness info
            const screen = listModelFindIndex(outputs, ({name: xrandrName}) => xrandrName === name);
            let { brightness } = outputs.get(screen);
            brightness *= current / max;
            outputs.set(screen, { brightness })
        }

        onNewData: {
            connectedSources.length = 0
            if (sourceName == verboseXrandrCommand) {
                const parsedData = parseVerboseXrandr(data.stdout);
                updateOutputs(parsedData);
            }
            else if (sourceName == findBacklightDevices) {
                try {
                    let [current, max, device] = data.stdout.trim().split('\n').slice(-3);
                    updateBacklight({
                        device: device.slice(device.lastIndexOf('/') + 1),
                        current: parseInt(current),
                        max: parseInt(max),
                    })
                } catch (err) {
                    console.error(`Error parsing results of backlight device search for built-in screen`, err)
                }
            }
            else if (sourceName.startsWith(setBacklightOnDbus)) {
                const allowed = data['exit code'] === 0;
                Object.assign(backlightScreen, { allowed });

                if (!allowed) {
                    console.warn(`Not allowed to set backlight hardware device brightness for built-in screen, only software filter`)
                }
            }
        }
    }

    Component.onCompleted: {
        brightyDS.connectedSources.push(verboseXrandrCommand)
    }
}
