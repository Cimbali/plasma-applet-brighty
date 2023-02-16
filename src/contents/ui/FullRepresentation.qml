import QtQuick 2.2
import QtQuick.Layouts 1.1
import QtQuick.Controls 1.3

Item {
	id: full

    ListView {
        id: multiSelectCheckList
        model: outputs
        height: parent.height
        width: parent.width
        anchors {
            margins: 10
        }

		delegate: BrightnessItem {
			id: brightnessSlider

			width: parent.width

			maximumValue: brightnessMax
			minimumValue: brightnessMin
			stepSize: brightnessMax / 100

			text: model.outputName

			value: model.brightness
			onMoved: {
				model.brightness = value
				setBrightness({[name]: brightness})
			}

			controlled: model.controlled
			onToggled: model.controlled = controlled
		}
	}
}
