import QtQuick
import qs.Commons
import qs.Ui

PanelHero {
  id: root

  property bool showingSettings: false
  property bool loading: false
  property bool hasData: false
  property string state: "loading"
  property string message: ""
  property string site: ""
  property int inProgressCount: 0
  property int todoCount: 0

  signal settingsToggled()

  title: site !== "" ? "Wrike · " + site : "Wrike"

  meta: {
    if (showingSettings)
      return qsTr("Settings")
    if (loading && !hasData)
      return qsTr("Loading")
    if (loading)
      return qsTr("Refreshing Wrike…")
    if (state !== "ok")
      return message
    return inProgressCount + qsTr(" in progress · ") + todoCount + qsTr(" to do")
  }

  trailingControl: Component {
    GearButton {
      active: root.showingSettings
      foreground: root.foreground
      fontFamily: root.fontFamily
      onToggled: root.settingsToggled()
    }
  }
}
