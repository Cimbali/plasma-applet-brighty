import QtQuick 2.2
import QtQuick.Layouts 1.1
import QtGraphicalEffects 1.0
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents

Item {
    id: compactRepresentation

    property bool textColorLight: ((theme.textColor.r + theme.textColor.g + theme.textColor.b) / 3) > 0.5
    property color iconColor: textColorLight ? Qt.tint(theme.textColor, '#f6f1f2') : Qt.tint(theme.textColor, '#232627')

    property string buttonImagePath: Qt.resolvedUrl('../icons/sun-flat.svg')

    PlasmaCore.IconItem {
        source: "video-display-brightness"
        width: parent.width
        height: parent.height
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        onClicked: {
            plasmoid.expanded = !plasmoid.expanded
            brightyDS.connectedSources.push(verboseXrandrCommand)
        }

        onWheel: {
            if (brightyDS.connectedSources.length > 0) {
                return
            }

            const cmd = []
            const step = (wheel.angleDelta.y > 0) ? brightnessStep : -brightnessStep

            for (let i = 0; i < outputs.count; i++) {
                const { name, controlled, brightness: oldBrightness } = outputs.get(i);
                if (controlled !== 'NO') {
                    const brightness = clipBrightness(oldBrightness + step);
                    cmd.push(`--output ${name} --brightness ${brightness.toFixed(2)}`)
                    outputs.set(i, { brightness })
                }
            }

            if (cmd.length) {
                brightyDS.connectedSources.push(`xrandr ${cmd.join(' ')}`)
            }
        }
    }
}
