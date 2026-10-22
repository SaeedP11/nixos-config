// One JSON file under Quickshell.statePath(), owned by one service. A
// missing file starts from `defaults`. A file that does not parse, or has
// a `version` other than 1, is moved aside to `<file>.bad-<epoch>` and
// `defaults` are used, with nothing written until the next save(). `ready`
// fires once `data` holds the loaded or default value. FileView's own
// `loaded` signal can't be redeclared, hence the different name.
import QtQuick
import Quickshell
import Quickshell.Io

FileView {
    id: root

    property string name
    property var defaults: ({})
    property var data: defaults

    signal ready

    function save(obj) {
        data = Object.assign({}, obj, {
            version: 1
        });
        setText(JSON.stringify(data));
    }

    function useDefaults() {
        data = Object.assign({}, defaults);
        ready();
    }

    path: Quickshell.statePath(name)
    printErrors: false
    atomicWrites: true

    onLoaded: {
        let parsed = null;
        try {
            parsed = JSON.parse(text());
        } catch (e) {}
        if (parsed?.version !== 1) {
            Quickshell.execDetached(["mv", path, path + ".bad-" + Date.now()]);
            useDefaults();
            return;
        }
        data = parsed;
        ready();
    }
    onLoadFailed: useDefaults()
}
