import "I18n.js" as I18n
import QtQuick
import QtQuick.Controls
import qs.Commons

// The keyboard reference, from Help → Keyboard shortcuts (or `?`).
//
// A mail client you drive from the keyboard needs somewhere to say which keys,
// and a card over the window is cheaper to reach than the README.
Item {
  id: root

  property var ui: null

  signal dismissed()

  // Two columns of { keys, does }, laid out as one list per column so a short
  // window scrolls rather than clipping.
  readonly property var sections: [
    { title: I18n.tr("Reading"), keys: [
      ["j / k    ↓ / ↑", I18n.tr("Move through the list")],
      ["Enter", I18n.tr("Open the selected message")],
      ["Tab", I18n.tr("Folder pane → list → reading pane")],
      ["/", "Search"],
      ["g", I18n.tr("Check for new mail")],
      ["Esc", "Back, then clear search, then close"]
    ] },
    { title: I18n.tr("Acting on a message"), keys: [
      ["r  /  a", I18n.tr("Reply / reply all")],
      ["f", I18n.tr("Forward")],
      ["e", I18n.tr("Archive")],
      ["Del", I18n.tr("Delete")],
      ["s", I18n.tr("Flag")],
      ["u", I18n.tr("Mark read or unread")]
    ] },
    { title: I18n.tr("Writing"), keys: [
      ["c", I18n.tr("New message")],
      ["Ctrl+N", I18n.tr("New message in its own window")],
      ["Ctrl+Enter", I18n.tr("Send")],
      ["Ctrl+Shift+A", I18n.tr("Attach files")],
      ["Ctrl+Shift+O", I18n.tr("Move this draft to its own window")]
    ] },
    { title: I18n.tr("The window"), keys: [
      ["F10", I18n.tr("Menus — then ← → and ↑ ↓")],
      ["Ctrl+,", I18n.tr("Settings")],
      ["?", "This list"]
    ] }
  ]

  // Everything under the card is unreachable while it is up, and a click
  // anywhere dismisses it.
  Rectangle {
    anchors.fill: parent
    color: Util.alpha(Qt.darker(ui.background, 1.6), 0.72)

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismissed()
    }
  }

  Rectangle {
    id: card
    anchors.centerIn: parent
    width: Math.min(Style.space(640), root.width - Style.space(64))
    height: Math.min(cardColumn.implicitHeight + Style.space(48),
                     root.height - Style.space(64))
    radius: ui.radius
    color: Qt.lighter(ui.background, 1.16)
    border.width: 1
    border.color: ui.border

    // Swallow clicks so they do not reach the dimmer behind.
    MouseArea { anchors.fill: parent }

    Flickable {
      id: sheetFlick
      anchors.fill: parent
      anchors.margins: Style.space(24)
      contentWidth: width
      contentHeight: cardColumn.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      interactive: contentHeight > height
      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

      Column {
        id: cardColumn
        width: parent.width
        spacing: Style.space(18)

        Item {
          width: parent.width
          height: Style.space(24)

          Text {
            textFormat: Text.PlainText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.tr("Keyboard shortcuts")
            color: ui.foreground
            font.family: ui.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
          }

          Text {
            textFormat: Text.PlainText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.tr("Esc to close")
            color: ui.faint
            font.family: ui.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        Repeater {
          model: root.sections

          Column {
            required property var modelData
            width: cardColumn.width
            spacing: Style.space(6)

            Text {
              textFormat: Text.PlainText
              text: parent.modelData.title
              color: ui.accent
              font.family: ui.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Repeater {
              model: parent.modelData.keys

              Item {
                required property var modelData
                width: cardColumn.width
                height: Style.space(20)

                Text {
                  id: keyText
                  textFormat: Text.PlainText
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  width: Style.space(150)
                  text: parent.modelData[0]
                  color: ui.foreground
                  font.family: ui.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }

                Text {
                  textFormat: Text.PlainText
                  anchors.left: keyText.right
                  anchors.leftMargin: Style.space(12)
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  text: parent.modelData[1]
                  color: ui.dim
                  font.family: ui.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  elide: Text.ElideRight
                }
              }
            }
          }
        }
      }

      MomentumScroll { view: sheetFlick }
    }
  }
}
