import QtQuick
import QtQuick.Controls
import QtTest
import Quickshell
import "ui"

// Exercises the actual bar Panel and its layer-shell popup, with a fake CLI.
ShellRoot {
  id: root
  PanelWindow {
    visible: true
    anchors { top: true; left: true; right: true }
    implicitHeight: 48
    exclusionMode: ExclusionMode.Ignore
    Panel { id: widget; width: 40; height: parent.height; settings: ({notify:false, syncIntervalSec:3600}) }
  }
  TestCase {
    id: tests
    when: false
    function check(value, label) { if (!value) throw new Error(label) }
    function findObject(object, name, seen) {
      if (!object || typeof object !== "object") return null
      seen = seen || []
      if (seen.indexOf(object) >= 0) return null
      seen.push(object)
      if (object.objectName === name) return object
      var collections = [object.children || [], object.data || []]
      var content = object.contentItem
      if (content) collections.push(content.length !== undefined ? content : [content])
      for (var j = 0; j < collections.length; j++) {
        for (var i = 0; i < collections[j].length; i++) {
          var found = findObject(collections[j][i], name, seen)
          if (found) return found
        }
      }
      return null
    }
    function runChecks() {
      wait(700)
      var service = findObject(widget, "olook-bar-service")
      check(service !== null, "bar service found")
      service.pollEnabled = false
      service.watchEnabled = false
      widget.open()
      wait(500)
      var row = findObject(widget, "olook-bar-message-row-0")
      var menu = findObject(widget, "olook-bar-message-menu")

      check(row !== null && menu !== null, "real bar row and menu found")
      var hit = findObject(widget, "olook-bar-message-hit-0")
      mouseMove(hit, hit.width/2, hit.height/2)
      wait(100)
      mouseClick(hit, hit.width/2, hit.height/2, Qt.RightButton)
      wait(150)
      check(widget.opened && menu.visible, "right-click keeps the panel open and shows the menu")
      check(menu.popupType === Popup.Item, "menu stays on the layer-shell surface")
      check(menu.message && menu.message.uid === 1, "context targets the clicked mail")
      var deleteItem = menu.itemAt(10)
      check(deleteItem.text === "Löschen", "delete action available")
      mouseClick(deleteItem, deleteItem.width/2, deleteItem.height/2, Qt.LeftButton)
      wait(400)
      check(service.recent.length === 0, "delete removes the fixture mail from the bar")
      check(widget.opened, "deleting a mail preserves the panel")
      check(findObject(widget, "olook-bar-message-menu") === menu, "menu survives deletion of its row")
      widget.close()
      console.log("OLOOK_BAR_TESTS_PASS: real panel right-click and delete")
    }
  }
  Timer {
    interval: 200; running: true
    onTriggered: Qt.callLater(function () {
      try { tests.runChecks() } catch (error) { console.error("OLOOK_BAR_TESTS_FAIL: " + error) }
      Qt.callLater(Qt.quit)
    })
  }
}
