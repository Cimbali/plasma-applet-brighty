import QtQuick 2.0
import QtQuick.Layouts 1.3
import QtQuick.Controls 2.5 as QQC2
import org.kde.kirigami 2.4 as Kirigami

Kirigami.FormLayout {
	id: page

	property alias cfg_stepBrightnessPercent: step.value
	property alias cfg_minBrightnessPercent: min.value
	property alias cfg_maxBrightnessPercent: max.value

    PercentSpinBox {
        id: step
        Kirigami.FormData.label: i18n("Brightness step:")
    }

    PercentSpinBox {
        id: min
        Kirigami.FormData.label: i18n("Lowest brightness:")
    }

    PercentSpinBox {
        id: max
        Kirigami.FormData.label: i18n("Highest brightness:")
    }
}

