import QtQuick
import QtQuick.Controls
import QtTest
import Quickshell
import "ui"
ShellRoot {
  QtObject {
    id: style
    property color background: "#181818"
    property color foreground: "#eeeeee"
    property color border: "#555555"
    property color hover: "#444444"
    property color selected: "#335577"
    property color accent: "#aaccff"
    property color dim: "#aaaaaa"
    property color faint: "#888888"
    property color urgent: "#ffaaaa"
    property string fontFamily: "monospace"
    property int radius: 4
    property int hairline: 1
  }
  Item {
    id: service
    property var accounts: [{ id: "qa", name: "QA", email: "qa@example.test" }]
    property string accountId: "qa"
    property string folder: "INBOX"
    property int unreadEverywhere: 0
    property string filter: "all"
    property var moved: []
    function foldersFor(account) { return [{name:"INBOX",special:"inbox"},{name:"Archive",special:"archive"}] }
    function moveMany(entries, target) { moved.push({entries:entries,target:target}) }
  }
  FloatingWindow {
    id: readerWindow
    visible: false
    title: "Olook newsletter QA"
    implicitWidth: 820
    implicitHeight: 640
    MailReader {
      id: reader
      anchors.fill: parent
      ui: style
      message: ({account:"qa",folder:"INBOX",uid:1,subject:"Newsletter fixture",fromAddr:"qa@example.test",date:1})
      body: ({text:"Fixture",rich:"<table>" + "<tr><td>Newsletter</td></tr>".repeat(1800) + "</table>",
              document:"<!DOCTYPE html><html><body><table>" + "<tr><td>Newsletter</td></tr>".repeat(1800) + "</table></body></html>"})
    }
  }
  FloatingWindow {
    id: window
    visible: true
    title: "Olook interaction QA"
    implicitWidth: 800
    implicitHeight: 500
    Item {
      id: surface
      anchors.fill: parent
      MailFolderPane { id: folders; width: 230; height: parent.height; ui: style; service: service }
      MailList {
        id: list
        x: 230; width: parent.width - x; height: parent.height
        ui: style; service: service
        rows: [{account:"qa",folder:"INBOX",uid:1,subject:"Fixture",fromAddr:"qa@example.test",seen:true,date:1}]
      }
      // Synthetic QtTest input has no compositor serial for a Wayland popup.
      MailContextMenu { id: menu; popupType: Popup.Item; service: service; message: list.rows[0] }
      // QtTest injects mouse events into this fixture window only.
      TestCase {
        id: tests
        name: "Interaction"
        when: false
        function assertTrue(value, label) { if (!value) throw new Error(label) }
        function assertEqual(actual, expected, label) {
          if (actual !== expected) throw new Error(label + ": got " + actual + ", expected " + expected)
        }
        function findFolder(item) {
          if (item.folder && item.folder.name === "Archive") return item
          var children = item.children || []
          for (var i = 0; i < children.length; i++) {
            var found = findFolder(children[i]); if (found) return found
          }
          return null
        }
        function findDrop(item) {
          if (typeof item.accepts === "function") return item
          var children = item.children || []
          for (var i = 0; i < children.length; i++) {
            var found = findDrop(children[i]); if (found) return found
          }
          return null
        }
        function findEngine(item) {
          if (item.source && String(item.source).endsWith("MailHtmlView.qml")) return item
          var children = item.children || []
          for (var i = 0; i < children.length; i++) {
            var found = findEngine(children[i]); if (found) return found
          }
          return null
        }
        function test_interactions() {
          wait(500)
          mouseClick(list, 100, 70, Qt.LeftButton)
          menu.popup(surface, 250, 50)
          wait(150)
          assertTrue(menu.visible, "line 100: verify(menu.visible)")
          var move = menu.itemAt(8).subMenu
          assertTrue(move !== null, "line 102: verify(move !== null)")
          assertEqual(move.count, 1, "line 103: compare(move.count, 1)")
          assertEqual(move.itemAt(0).text, "Archive", "line 104: compare(move.itemAt(0).text, \"Archive\")")
          menu.close()
          var folder = findFolder(folders)
          assertTrue(folder !== null, "line 107: verify(folder !== null)")
          var drop = findDrop(folder)
          assertTrue(drop !== null, "line 109: verify(drop !== null)")
          assertTrue(!drop.accepts({entries:[{account:"other",folder:"INBOX",uid:1}]}), "line 110: verify(!drop.accepts({entries:[{account:\"other\",folder:\"INBOX\",uid:1}]}))")
          assertTrue(!drop.accepts({entries:[{account:"qa",folder:"Archive",uid:1}]}), "line 111: verify(!drop.accepts({entries:[{account:\"qa\",folder:\"Archive\",uid:1}]}))")
          assertTrue(!drop.accepts({entries:[list.rows[0],{account:"other",folder:"INBOX",uid:1}]}), "line 112: verify(!drop.accepts({entries:[list.rows[0],{account:\"other\",folder:\"INBOX\",uid:1}]}))")
          var target = folder.mapToItem(list, folder.width/2, folder.height/2)
          mousePress(list, 100, 70, Qt.LeftButton)
          mouseMove(list, 120, 70, 80)
          mouseMove(list, target.x, target.y, 150)
          wait(100)
          mouseRelease(list, target.x, target.y, Qt.LeftButton)
          wait(100)
          assertEqual(service.moved.length, 1, "line 120: compare(service.moved.length, 1)")
          assertEqual(service.moved[0].target, "Archive", "line 121: compare(service.moved[0].target, \"Archive\")")
          service.moved = []
          list.selectedKeys = ["qa|INBOX|1"]
          list.dragEntries = [list.rows[0], {account:"qa",folder:"INBOX",uid:2}]
          mousePress(list, 100, 70, Qt.LeftButton)
          mouseMove(list, 120, 70, 80)
          mouseMove(list, target.x, target.y, 150)
          mouseRelease(list, target.x, target.y, Qt.LeftButton)
          wait(100)
          assertEqual(service.moved.length, 1, "line 130: compare(service.moved.length, 1)")
          assertEqual(service.moved[0].entries.length, 2, "line 131: compare(service.moved[0].entries.length, 2)")
          readerWindow.visible = true
          wait(1500)
          assertTrue(reader.webRenderer, "line 134: verify(reader.webRenderer)")
          var engine = findEngine(reader)
          assertTrue(engine !== null, "line 136: verify(engine !== null)")
          assertTrue(engine.item !== null, "line 137: verify(engine.item !== null)")
          assertTrue(engine.item.measured > 120, "line 138: verify(engine.item.contentHeight > 0)")
          reader.message = null
          wait(100)
          assertTrue(engine.active && engine.item !== null, "line 141: verify(engine.active && engine.item !== null)")
          console.log("OLOOK_INTERACTION_TESTS_PASS: menu, single/bulk drag, persistent newsletter renderer")
        }
      }
    }
  }
  Timer { interval: 600; running: true; onTriggered: {
    Qt.callLater(function () {
      try { tests.test_interactions() } catch (error) { console.error("INTERACTION_FAIL: " + error) }
      Qt.callLater(Qt.quit)
    })
  } }
}
