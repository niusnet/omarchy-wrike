import QtQuick

// Puts text on the system clipboard.
TextEdit {
  id: root

  function put(value) {
    root.text = String(value || "")
    root.selectAll()
    root.copy()
  }

  visible: false
  width: 0
  height: 0
}
