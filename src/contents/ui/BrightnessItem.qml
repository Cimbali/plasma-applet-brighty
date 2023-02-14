/*
    SPDX-FileCopyrightText: 2012-2013 Daniel Nicoletti <dantti12@gmail.com>
    SPDX-FileCopyrightText: 2013, 2015 Kai Uwe Broulik <kde@privat.broulik.de>

    SPDX-License-Identifier: LGPL-2.0-or-later


	Taken from the battery applet
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15

import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.core 2.1 as PlasmaCore

PlasmaComponents3.ItemDelegate {
    id: root

    property alias slider: control
    property alias value: control.value
    property alias controlled: includeInScroll.checked
    property alias maximumValue: control.to
    property alias minimumValue: control.from
    property alias stepSize: control.stepSize
    property alias showPercentage: percent.visible

    readonly property real percentage: Math.round(100 * value / maximumValue)

    signal moved()
    signal toggled()

    background.visible: highlighted
    highlighted: activeFocus
    hoverEnabled: false

    Accessible.description: percent.text
    Accessible.role: Accessible.Slider
    Keys.forwardTo: [slider]

    contentItem: RowLayout {
        spacing: PlasmaCore.Units.gridUnit

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: PlasmaCore.Units.smallSpacing

                PlasmaComponents3.CheckBox {
                    id: includeInScroll
                    Layout.alignment: Qt.AlignLeft
					onClicked: root.toggled()

					PlasmaComponents3.ToolTip {
						text: i18n("Modify display brightness by scrolling on icon")
					}
				}

                PlasmaComponents3.Label {
                    id: title
                    Layout.fillWidth: true
                    text: root.text
                }

                PlasmaComponents3.Label {
                    id: percent
                    Layout.alignment: Qt.AlignRight
                    text: i18nc("Placeholder is brightness percentage", "%1%", root.percentage)
                }
            }

            PlasmaComponents3.Slider {
                id: control
                Layout.fillWidth: true

                activeFocusOnTab: false
                stepSize: 1

                Accessible.name: root.text
                Accessible.description: percent.text

                onMoved: root.moved()
            }
        }
    }
}

