PWD := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
SRCDIR := src
PACKAGE := kpackagetool5 -t Plasma/Applet
GETMETA := kreadconfig5 --file=${PWD}${SRCDIR}/metadata.desktop --group="Desktop Entry"

PLASMOID_NAME := $(shell ${GETMETA} --key="X-KDE-PluginInfo-Name" | sed s/^org\.kde\.//)
PLASMOID_VERS := $(shell ${GETMETA} --key="X-KDE-PluginInfo-Version")

build: ${PLASMOID_NAME}-v${PLASMOID_VERS}.plasmoid
	@sha256sum $<

%.plasmoid:
	@cd ${SRCDIR} && zip -qr "../$@" *

test:
	@env QML_DISABLE_DISK_CACHE=true plasmoidviewer -a ${SRCDIR}

install:
	${PACKAGE} -i ${SRCDIR}

uninstall:
	${PACKAGE} -r ${SRCDIR}

clean:
	@rm -vf *.plasmoid
