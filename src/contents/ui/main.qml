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

    Plasmoid.status: listModelFindIndex(outputs, ({ controlled }) => controlled) !== -1
        ? PlasmaCore.Types.ActiveStatus
        : PlasmaCore.Types.PassiveStatus

    readonly property string verboseXrandrCommand: "xrandr --verbose"

    property ListModel outputs: ListModel {}

    function listModelFindIndex(listModel, pred) {
        for (let i = 0; i < listModel.count; i++) {
            if (pred(listModel.get(i))) {
                return i;
            }
        }
        return -1;
    }

    Plasmoid.preferredRepresentation: Plasmoid.compactRepresentation
    Plasmoid.compactRepresentation: CompactRepresentation { }
    Plasmoid.fullRepresentation: FullRepresentation {}

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

        onNewData: {
            connectedSources.length = 0
            if (sourceName == verboseXrandrCommand) {
                const parsedData = parseVerboseXrandr(data.stdout);

                // Update list of monitors: set brightness or remove if they are not in xrandr output anymore
                for (let i = 0; i < outputs.count; ) {
                    const { name } = outputs.get(i);
                    if (name in parsedData) {
                        const { brightness } = parsedData[name];
                        outputs.set(i, { brightness })
                        delete parsedData[name];
                        ++i;
                    } else {
                        outputs.remove(i, 1)
                    }
                }

                // Append new monitors to list
                for (const [name, screen] of Object.entries(parsedData)) {
                    outputs.append(Object.assign({ name, outputName: outputName(name, screen), controlled: !screen.isLaptopScreen }, screen))
                }
            }
        }
    }

    Plasmoid.toolTipMainText: i18n('External Monitor Brightness Control')
    Plasmoid.toolTipSubText: i18n('Control External Monitor Brightness')
    Plasmoid.toolTipTextFormat: Text.RichText
    Plasmoid.icon: 'video-display-brightness'

    Component.onCompleted: {
        brightyDS.connectedSources.push(verboseXrandrCommand)
    }

    property double brightnessStep: plasmoid.configuration.stepBrightnessPercent / 100
    property double brightnessMin: plasmoid.configuration.minBrightnessPercent / 100
    property double brightnessMax: plasmoid.configuration.maxBrightnessPercent / 100

    function clipBrightness(val) {
        if (val < brightnessMin) {
            return brightnessMin
        }
        if (val > brightnessMax) {
            return brightnessMax
        }
        return val
    }
}
