# Brightness Controller

A simple plasma applet to control monitor brightness for built-in and external monitors simultaneously.

If possible it will use the hardware control for your built-in screen brightness, while other monitors' brightness is controlled through a software filter.

Note that it clashes with Night Color Control, in the sense that the last to set a screen brightness wins:
- if you are in a window of progressively changing screen color, manual settings from this plugin will be overwritten
- if you set the color manually through this plugin while the night color is active, you lose the screen color setting

Additionally, if brightness is changed outside of this applet (e.g. directly `xrandr --brightness X` on the command line), clicking on it will refresh the values.
Otherwise, scrolls on the icon will be based on the latest value known to the applet.

Forked from [Misagh Lotfi's Brighty](https://github.com/Misaghlb/plasma-applet-brighty)

## Download and Install:
https://www.opendesktop.org/p/1239150/
