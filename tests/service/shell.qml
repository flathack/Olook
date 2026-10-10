import QtQuick
import Quickshell
import "ui"

// Run with: tests/service/run.sh
// All engine calls are intercepted; no accounts, servers or mail are touched.
ShellRoot {
  Service {
    id: service
    pollEnabled: false
    watchEnabled: false
    property var calls: []
    function run(args, handler, label) {
      calls.push({ args: args, handler: handler, label: label })
      return null
    }
  }

  function check(value, label) {
    if (!value) throw new Error(label)
  }
  function entry(account, folder, uid) {
    return { account: account, folder: folder, uid: uid, seen: true }
  }
  function reset() {
    service.selected = null
    service.body = null
    service.messages = []
    service.recent = []
    service.removedKeys = ({})
    service.accountId = "a"
    service.folder = "INBOX"
    service.calls = []
  }
  function runChecks() {
    try {
      reset()
      var a = entry("a", "INBOX", 1)
      var b = entry("b", "INBOX", 1)
      service.messages = [a, b]
      service.markLocalSeen(a, false)
      check(!service.messages[0].seen && service.messages[1].seen,
            "read flags must match account as well as UID")
      service.dropLocal(a)
      check(service.messages.length === 1 && service.messages[0].account === "b",
            "deleting one account must preserve another account's matching UID")

      reset()
      service.openMessage(a)
      var oldBody = service.calls[0].handler
      service.openMessage(b)
      var newBody = service.calls[1].handler
      oldBody(true, { body: { text: "old" }, message: a }, "")
      check(service.body === null, "a late body must not replace another account's message")
      newBody(true, { body: { text: "new" }, message: b }, "")
      check(service.body.text === "new", "the current body must still load")

      reset()
      service.messages = [a, b]
      service.loadMessages()
      var oldList = service.calls[0].handler
      service.dropLocal(a)
      oldList(true, { messages: [a, b] }, "")
      check(service.messages.length === 1 && service.messages[0].account === "b",
            "a late list must not resurrect an optimistic deletion")

      reset()
      service.loadMessages()
      var inboxList = service.calls[0].handler
      service.folder = "Archive"
      service.loadMessages()
      var archiveList = service.calls[1].handler
      archiveList(true, { messages: [entry("a", "Archive", 2)] }, "")
      inboxList(true, { messages: [a] }, "")
      check(service.messages[0].folder === "Archive", "a stale folder list must be ignored")

      reset()
      service.messages = [a]
      service.remove(a)
      check(service.withoutRemoved([a]).length === 0, "pending delete must hide cached rows")
      service.calls[0].handler(false, { error: "fixture failure" }, "")
      check(service.withoutRemoved([a]).length === 1, "failed delete must restore visibility")

      reset()
      service.messages = [a, b]
      service.removeMany([a, b])
      service.calls[0].handler(true, { to: "Trash" }, "")
      service.calls[1].handler(false, { error: "fixture failure" }, "")
      check(service.withoutRemoved([a, b]).length === 1
            && service.withoutRemoved([a, b])[0].account === "b",
            "partial bulk failure must restore only its own mailbox")

      console.log("OLOOK_SERVICE_TESTS_PASS: 6 scenarios")
    } catch (error) {
      console.error("OLOOK_SERVICE_TESTS_FAIL: " + error)
    }
    Qt.quit()
  }
  Component.onCompleted: Qt.callLater(runChecks)
}
