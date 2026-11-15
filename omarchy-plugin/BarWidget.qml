import QtQuick
import qs.Ui

BarWidget {
  id: root
  moduleName: "vyoltrava.orbit"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "◉"
    tooltipText: "Orbit launcher"
    onPressed: function() {
      if (root.bar)
        root.bar.run("omarchy-shell shell toggle vyoltrava.orbit")
    }
  }
}
