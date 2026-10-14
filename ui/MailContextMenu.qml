import "I18n.js" as I18n
import QtQuick
import QtQuick.Controls

// Shared actions for the client and the bar's recent-message rows.
Menu {
  id: root
  popupType: Popup.Window
  property var message: null
  property var service: null
  signal requested(string action)
  MenuItem { text: I18n.tr("Open"); onTriggered: root.requested("open") }
  MenuSeparator {}
  MenuItem { text: I18n.tr("Reply"); onTriggered: root.requested("reply") }
  MenuItem { text: I18n.tr("Reply all"); onTriggered: root.requested("reply-all") }
  MenuItem { text: I18n.tr("Forward"); onTriggered: root.requested("forward") }
  MenuSeparator {}
  MenuItem {
    text: root.message && root.message.seen ? I18n.tr("Mark unread") : I18n.tr("Mark read")
    onTriggered: root.requested("read")
  }
  MenuItem {
    text: root.message && root.message.flagged ? I18n.tr("Remove flag") : I18n.tr("Flag")
    onTriggered: root.requested("flag")
  }
  Menu {
    id: moveMenu
    title: I18n.tr("Move to folder")
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
  MenuItem { text: I18n.tr("Archive"); onTriggered: root.requested("archive") }
  MenuItem { text: I18n.tr("Delete"); onTriggered: root.requested("delete") }
}
