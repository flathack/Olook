import QtQuick
import QtQuick.Controls

// Shared actions for the client and the bar's recent-message rows.
Menu {
  id: root
  popupType: Popup.Window
  property var message: null
  property var service: null
  signal requested(string action)
  MenuItem { text: "Open"; onTriggered: root.requested("open") }
  MenuSeparator {}
  MenuItem { text: "Reply"; onTriggered: root.requested("reply") }
  MenuItem { text: "Reply all"; onTriggered: root.requested("reply-all") }
  MenuItem { text: "Forward"; onTriggered: root.requested("forward") }
  MenuSeparator {}
  MenuItem {
    text: root.message && root.message.seen ? "Mark unread" : "Mark read"
    onTriggered: root.requested("read")
  }
  MenuItem {
    text: root.message && root.message.flagged ? "Remove flag" : "Flag"
    onTriggered: root.requested("flag")
  }
  Menu {
    id: moveMenu
    title: "Move to folder"
    Instantiator {
      model: root.service && root.message
        ? root.service.foldersFor(root.message.account).filter(function (folder) {
            return !folder.virtual && folder.name !== root.message.folder
          }) : []
      delegate: MenuItem {
        required property var modelData
        text: modelData.name
        onTriggered: root.requested("move:" + modelData.name)
      }
      onObjectAdded: function (index, object) { moveMenu.insertItem(index, object) }
      onObjectRemoved: function (index, object) { moveMenu.removeItem(object) }
    }
  }
  MenuItem { text: "Archive"; onTriggered: root.requested("archive") }
  MenuItem { text: "Delete"; onTriggered: root.requested("delete") }
}
