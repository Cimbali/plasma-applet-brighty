import QtQuick 2.2
import QtQuick.Layouts 1.1
import QtQuick.Controls 1.3

Item {
	id: full

	width: 15
	height: 3

    ListView {
        id: multiSelectCheckList
        model: outputs
        height: parent.height
        width: parent.width
        anchors {
            margins: 10
        }

        delegate: CheckBox {
            id: modelCheckBoxes
            checked: model.controlled
            text: model.outputName

			onClicked: {
				model.controlled = checked
			}

			width: 15
			height: 30
        }
    }
}
