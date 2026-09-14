/*****************************************************************************
 *   Copyright (C) 2014 by Weng Xuetian <wengxt@gmail.com>                   *
 *   Copyright (C) 2013-2017 by Eike Hein <hein@kde.org>                     *
 *   Copyright (C) 2021 by Prateek SU <pankajsunal123@gmail.com>             *
 *   Copyright (C) 2022 by Friedrich Schriewer <friedrich.schriewer@gmx.net> *
 *                                                                           *
 *   This program is free software; you can redistribute it and/or modify    *
 *   it under the terms of the GNU General Public License as published by    *
 *   the Free Software Foundation; either version 2 of the License, or       *
 *   (at your option) any later version.                                     *
 *                                                                           *
 *   This program is distributed in the hope that it will be useful,         *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of          *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the           *
 *   GNU General Public License for more details.                            *
 *                                                                           *
 *   You should have received a copy of the GNU General Public License       *
 *   along with this program; if not, write to the                           *
 *   Free Software Foundation, Inc.,                                         *
 *   51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA .          *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts
import QtQml
import Qt5Compat.GraphicalEffects
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import org.kde.ksvg as KSvg
import org.kde.kirigami as Kirigami

PlasmaCore.Dialog {
	id: root

	objectName: "popupWindow"
	flags: Qt.WindowStaysOnTopHint

	// The background (theme SVG over a self-blurred wallpaper) is drawn in QML
	// instead of natively, so the whole visual can take part in the animations.
	backgroundHints: PlasmaCore.Types.NoBackground

	// Transparent window surface, so the theme SVG's rounded corners show
	// instead of the default opaque white window background.
	color: "transparent"

	location: Plasmoid.configuration.floating || Plasmoid.configuration.launcherPosition == 2 ? "Floating" : Plasmoid.location
	hideOnWindowDeactivate: false

	property bool closing: false

	// Blur radius applied to the whole panel content (see panel.layer.effect);
	// animated during open/close. The id inside layer.effect's implicit
	// Component is not visible from outside, so this property relays it.
	property real contentBlurRadius: 0

	// Wallpaper behind the panel: restores the frosted-glass look the native
	// dialog background used to get from the KWin blur effect.
	property string wallpaperPath: ""
	readonly property string wallpaperUrl: {
		if (wallpaperPath.length === 0) return "";
		var p = wallpaperPath;
		if (p.charAt(0) === "/") p = "file://" + p;
		return encodeURI(p);
	}

	property int iconSize: {
		switch(Plasmoid.configuration.appsIconSize){
			case 0: return Kirigami.Units.iconSizes.smallMedium;
			case 1: return Kirigami.Units.iconSizes.medium;
			case 2: return Kirigami.Units.iconSizes.large;
			case 3: return Kirigami.Units.iconSizes.huge;
			default: return 64
		}
	}

	property int columns: Plasmoid.configuration.numberColumns

	property int cellSizeHeight: iconSize
								+ Kirigami.Units.gridUnit * 2
								+ (2 * Math.max(
												highlightItemSvg.margins.top + highlightItemSvg.margins.bottom,
												highlightItemSvg.margins.left + highlightItemSvg.margins.right
												)
								  )
	property int cellSizeWidth: cellSizeHeight //+ Kirigami.Units.gridUnit
	property int rows: plasmoid.configuration.numberOfRows

	onVisibleChanged: {
		if (!visible) {
			reset();
		} else {
			closeAnim.stop();
			openAnim.stop();
			resetCloseState();
			refreshWallpaper();
			var pos = popupPosition(width, height);
			x = pos.x;
			y = pos.y;
			requestActivate();
			// macOS-style open: focus in from a slightly blurred, shrunken state.
			panel.scale = 0.94;
			panel.opacity = 0;
			contentBlurRadius = 16;
			openAnim.start();
		}
	}

	onActiveChanged: {
		// Close every "outside" dismissal (desktop, other windows, panel button)
		// with the same animated fade instead of an instant hide.
		if (!active && visible && !closing) {
			closeWithLaunchAnimation();
		}
	}

	onHeightChanged: {
		var pos = popupPosition(width, height);
		x = pos.x;
		y = pos.y;
	}

	onWidthChanged: {
		var pos = popupPosition(width, height);
		x = pos.x;
		y = pos.y;
	}

	function toggle() {
		closeWithLaunchAnimation();
	}

	// Toggle from the panel button. While the close animation is running the
	// window is still visible, so a plain visible toggle would hide it mid-fade.
	function toggleFromButton() {
		if (visible) {
			closeWithLaunchAnimation();
		} else {
			visible = true;
		}
	}

	// macOS-style launch feedback: blur + shrink + fade the whole panel,
	// then hide the window once the animation finished.
	function closeWithLaunchAnimation() {
		if (closing) {
			return;
		}
		openAnim.stop();
		closing = true;
		closeAnim.start();
	}

	function resetCloseState() {
		closing = false;
		panel.scale = 1;
		panel.opacity = 1;
		contentBlurRadius = 0;
	}

	function refreshWallpaper() {
		var path = "";
		try {
			var cor = Plasmoid.containment ? Plasmoid.containment.corona : null;
			if (cor) {
				for (var s = 0; s < Math.max(1, cor.numScreens); s++) {
					var w = cor.wallpaper(s);
					if (w && w.Image && w.Image.length > 0) {
						path = w.Image;
						break;
					}
				}
			}
		} catch (e) {
			path = "";
		}
		wallpaperPath = path;
	}

	function reset() {
		main.reset()
	}

	function popupPosition(width, height) {
		var screenAvail = Plasmoid.availableScreenRect;
		var screen/*Geom*/ = kicker.screenGeometry;
		//QtBug - QTBUG-64115
		/*var screen = Qt.rect(screenAvail.x + screenGeom.x,
				screenAvail.y + screenGeom.y,
				screenAvail.width,
				screenAvail.height);*/

		var offset = 0

		if (Plasmoid.configuration.offsetX > 0 && Plasmoid.configuration.floating) {
			offset = Plasmoid.configuration.offsetX
		} else {
			offset = plasmoid.configuration.floating ? parent.height * 0.35 : 0
		}
		// Fall back to bottom-left of screen area when the applet is on the desktop or floating.
		var x = offset;
		var y = screen.height - height - offset;
		var horizMidPoint = screen.x + (screen.width / 2);
		var vertMidPoint = screen.y + (screen.height / 2);
		var appletTopLeft = parent.mapToGlobal(0, 0);
		var appletBottomLeft = parent.mapToGlobal(0, parent.height);

		if (Plasmoid.configuration.launcherPosition != 0){
			x = horizMidPoint - width / 2;
		} else {
			x = (appletTopLeft.x < horizMidPoint) ? screen.x : (screen.x + screen.width) - width;
			if (Plasmoid.configuration.floating) {
				if (appletTopLeft.x < horizMidPoint) {
					x += offset
				} else if (appletTopLeft.x + width > horizMidPoint){
					x -= offset
				}
			}
		}

		if (Plasmoid.configuration.launcherPosition != 2){
			if (Plasmoid.location == PlasmaCore.Types.TopEdge) {
				if (Plasmoid.configuration.floating) {
											/*this is floatingAvatar.width*/
					if (Plasmoid.configuration.offsetY > 0) {
						offset = (125 * 1) / 2 + Plasmoid.configuration.offsetY
					} else {
						offset = (125 * 1) / 2 + parent.height * 0.125
					}
				}
				y = screen.y + parent.height + panelSvg.margins.bottom + offset;
			} else {
				if (Plasmoid.configuration.offsetY > 0) {
					offset = Plasmoid.configuration.offsetY
				}
				y = screen.y + screen.height - parent.height - height - panelSvg.margins.top - offset * 2.5;
			}
		} else {
			y = vertMidPoint - height / 2
		}

		return Qt.point(x, y);
	}

	FocusScope {
		id: fs
		focus: true
		width:  (root.cellSizeWidth * Plasmoid.configuration.numberColumns) + innerPadding*2
				+ dialogSvg.margins.left + dialogSvg.margins.right
		// Searchbar.height + separator.height  + categories switcher.height
		height: 40 + 2 + 40 + (root.cellSizeHeight *rows) + innerPadding
				+ dialogSvg.margins.top + dialogSvg.margins.bottom

		// We want the MainView to have an uniform margin through different plasma themes
		property real innerPadding: 15

		// Whole panel (wallpaper, theme background, content). Animated as one unit.
		Item {
			id: panel
			anchors.fill: parent
			enabled: !root.closing
			transformOrigin: Item.Center
			layer.enabled: root.closing || panel.opacity < 1
			layer.effect: FastBlur {
				radius: root.contentBlurRadius
			}

			// Blurred wallpaper: the "frost" of the glass panel. Masked with the
			// theme background's alpha so the rounded corners stay transparent
			// instead of showing sharp wallpaper edges.
			Item {
				id: wallpaperLayer
				anchors.fill: parent
				layer.enabled: true
				layer.effect: OpacityMask {
					maskSource: ShaderEffectSource {
						sourceItem: dialogBackground
						sourceRect: Qt.rect(0, 0, dialogBackground.width, dialogBackground.height)
					}
				}

				Image {
					id: wallpaperImage
					visible: false
					cache: true
					asynchronous: true
					smooth: true
					fillMode: Image.PreserveAspectCrop
					x: kicker.screenGeometry.x - root.x
					y: kicker.screenGeometry.y - root.y
					width: kicker.screenGeometry.width
					height: kicker.screenGeometry.height
					source: root.wallpaperUrl
				}

				ShaderEffectSource {
					id: wallpaperSource
					anchors.fill: parent
					sourceItem: wallpaperImage
					sourceRect: Qt.rect(root.x - kicker.screenGeometry.x,
										root.y - kicker.screenGeometry.y,
										width, height)
					smooth: true
					visible: wallpaperImage.status === Image.Ready
				}

				FastBlur {
					id: wallpaperBlur
					anchors.fill: parent
					source: wallpaperSource
					radius: 48
					visible: wallpaperSource.visible
				}
			}

			// Same theme background the dialog used to paint natively.
			KSvg.FrameSvgItem {
				id: dialogBackground
				anchors.fill: parent
				imagePath: "dialogs/background"
			}

			MainView {
				id: main
				width: parent.width - (fs.innerPadding)
				height: parent.height - (fs.innerPadding*2)
				x: fs.innerPadding
				y: fs.innerPadding
			}
		}

		Keys.onPressed: {
			if (event.key == Qt.Key_Escape) {
				root.closeWithLaunchAnimation();
			}
		}

		SequentialAnimation {
			id: closeAnim

			ParallelAnimation {
				NumberAnimation { target: panel; property: "scale"; to: 0.9; duration: 300; easing.type: Easing.OutCubic }
				NumberAnimation { target: panel; property: "opacity"; to: 0; duration: 300; easing.type: Easing.OutCubic }
				NumberAnimation { target: root; property: "contentBlurRadius"; to: 24; duration: 300; easing.type: Easing.OutCubic }
			}
			ScriptAction { script: { root.visible = false; resetCloseState(); } }
		}

		SequentialAnimation {
			id: openAnim

			ParallelAnimation {
				NumberAnimation { target: panel; property: "scale"; from: 0.94; to: 1; duration: 250; easing.type: Easing.OutCubic }
				NumberAnimation { target: panel; property: "opacity"; from: 0; to: 1; duration: 250; easing.type: Easing.OutCubic }
				NumberAnimation { target: root; property: "contentBlurRadius"; from: 16; to: 0; duration: 250; easing.type: Easing.OutCubic }
			}
		}
	}

	function refreshModel() {
		main.reload()
	}

	Component.onCompleted: {
		kicker.reset.connect(reset);
		rootModel.refresh();
		refreshWallpaper();
		try {
			Plasmoid.containment.corona.wallpaperChanged.connect(refreshWallpaper);
		} catch (e) { /* wallpaper tracking is optional */ }
	}
}
