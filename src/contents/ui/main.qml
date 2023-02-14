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

Item {
    id: main

    anchors.fill: parent

    Plasmoid.status: listModelFindIndex(outputs, ({ controlled }) => controlled) !== -1
        ? PlasmaCore.Types.ActiveStatus
        : PlasmaCore.Types.PassiveStatus

    readonly property string kscreenConsoleCommand: "kscreen-console outputs"
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

        function outputName({ Name: name, Type: screenType, 'EDID Info': edidInfo }) {
            if (screenType === 'Panel (Laptop)') {
                return i18nd('kscreen_common', 'Built-in Screen')
            }
            if (edidInfo) {
                const { Vendor: vendor, Name: model } = edidInfo;
                const typeSuffix = screenType ?  (' (' + screenType + ')') : ''
                if (vendor && model) {
                    return vendor + ' ' + model + typeSuffix
                } else if (vendor) {
                    return vendor + typeSuffix
                } else if (model) {
                    return model + typeSuffix
                }
            }
            return name
        }

        function parseValue(str) {
            if (str.startsWith('"') && str.endsWith('"')) {
                // A string literal
                return str.slice(1, str.length - 1)
            } else if (str === "true") {
                return true;
            } else if (str === "false") {
                return false;
            } else if (!isNaN(str)) {
                return parseFloat(str)
            } else {
                // Usually an object
                return str;
            }
        }

        function parseKScreenConsole(output) {
            const outputs = []
            let screen = {}, nestKey = null;
            for (const line of output.split('\n')) {
                if (!line.trim()) {
                    continue;
                }
                // Hit a separator
                if (line === '-'.repeat(line.length)) {
                    const { Name: name, Connected: connected, Type: screenType } = screen;
                    if (name && connected) {
                        outputs.push([name, outputName(screen), screenType !== 'Panel (Laptop)'])
                    }
                    screen = {}
                    nestKey = null
                    continue
                }

                let [key, ...value] = line.split(':', 2).map(token => token.trim())
                const isNested = line.startsWith('\t')

                if (key === 'Modes' || key === 'Screen' || key === 'EDID Info') {
                    nestKey = key
                    screen[key] = {}
                    continue
                }
                if (!isNested) {
                    nestKey = null
                }
                if (!value.length) {
                    continue
                }

                if (!isNested) {
                    screen[key] = parseValue(value[0])
                } else if (nestKey === 'EDID Info') {
                    // Only nested info we care about
                    screen[nestKey][key] = parseValue(value[0])
                } else if (nestKey === null) {
                    console.error(`Nested line not preceded by header in kscreen-console output: ${line.trimEnd()}`)
                }
            }

            return outputs;
        }

        function parseVerboseXrandr(output) {
            const brightness = {}
            let name, isConnected = false;
            for (const line of output.split('\n')) {
                // New screen start
                if (!line.startsWith(' ') && !line.startsWith('\t')) {
                    [name, isConnected] = line.split(' ', 3)
                    isConnected = (isConnected === 'connected')
                    if (isConnected) {
                        brightness[name] = 1.;
                    }
                }
                // After a connected screen start, search for brightness value
                else if (isConnected) {
                    const [key, ...value] = line.split(':', 2)
                    if (key.trim() === 'Brightness') {
                        brightness[name] = parseFloat(value[0].trim())
                    }
                }
            }
            return brightness
        }

        onNewData: {
            connectedSources.length = 0
            if (sourceName == kscreenConsoleCommand) {
                // Get list of monitor names and whether we should control by default
                for (const [name, outputName, controlledByDefault] of parseKScreenConsole(data.stdout)) {
                    const screen = listModelFindIndex(outputs, ({ name: xrandrName }) => xrandrName === name);
                    if (screen !== -1) {
                        const { controlled = controlledByDefault } = outputs.get(screen);
                        outputs.set(screen, { outputName, controlled })
                    } else {
                        console.error(`Monitor ${name} in kscreen-console output but not in xrandr!`)
                    }
                }
            }
            if (sourceName == verboseXrandrCommand) {
                const brightnessValues = parseVerboseXrandr(data.stdout);

                // Update list of monitors: set brightness or remove if they are not in xrandr output anymore
                for (let i = 0; i < outputs.count; ) {
                    const { name } = outputs.get(i);
                    if (name in brightnessValues) {
                        outputs.set(i, { brightness: brightnessValues[name] })
                        delete brightnessValues[name];
                        ++i;
                    } else {
                        outputs.remove(i, 1)
                    }
                }

                // Append new monitors to list
                for (const [name, level] of Object.entries(brightnessValues)) {
                    outputs.append({ name, outputName: name, controlled: true, brightness: level })
                }

                // Now lookup fancy names
                brightyDS.connectedSources.push(kscreenConsoleCommand)
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
