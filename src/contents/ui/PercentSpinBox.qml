import QtQuick.Controls 2.5 as QQC2
import org.kde.kirigami 2.4 as Kirigami

// Taken from org.kde.plasma.mediacontroller/contents/ui/ConfigGeneral.qml
QQC2.SpinBox {
	from: 1
	to: 100
	stepSize: 1
	editable: true
	textFromValue: function(value) {
		return value + "%";
	}
	valueFromText: function(text) {
		return parseInt(text);
	}
}

