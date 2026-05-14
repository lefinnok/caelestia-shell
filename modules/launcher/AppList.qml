pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.modules.launcher.items
import qs.modules.launcher.services

StyledListView {
    id: root

    required property StyledTextField search
    required property DrawerVisibilities visibilities

    model: ScriptModel {
        id: model

        onValuesChanged: root.currentIndex = 0
    }

    spacing: Tokens.spacing.small
    orientation: Qt.Vertical
    implicitHeight: (Tokens.sizes.launcher.itemHeight + spacing) * Math.min(Config.launcher.maxShown, count) - spacing

    preferredHighlightBegin: 0
    preferredHighlightEnd: height
    highlightRangeMode: ListView.ApplyRange

    highlightFollowsCurrentItem: false
    highlight: StyledRect {
        radius: Tokens.rounding.normal
        color: Colours.palette.m3onSurface
        opacity: 0.08

        y: root.currentItem?.y ?? 0
        implicitWidth: root.width
        implicitHeight: root.currentItem?.implicitHeight ?? 0

        Behavior on y {
            Anim {
                type: Anim.DefaultSpatial
            }
        }
    }

    // Determine launcher mode from search text
    function getMode(): string {
        const text = search.text;
        const prefix = GlobalConfig.launcher.actionPrefix;
        if (text.startsWith(prefix)) {
            for (const action of ["calc", "scheme", "variant"])
                if (text.startsWith(`${prefix}${action} `))
                    return action;
            return "actions";
        }
        return "apps";
    }

    // Perform the search and update model safely (avoids ScriptModel move bug)
    function updateResults(): void {
        const mode = getMode();

        // Update delegate if mode changed
        switch (mode) {
        case "apps":
            delegate = appItem;
            break;
        case "actions":
            delegate = actionItem;
            break;
        case "calc":
            delegate = calcItem;
            break;
        case "scheme":
            delegate = schemeItem;
            break;
        case "variant":
            delegate = variantItem;
            break;
        }

        // Get new results
        let results;
        switch (mode) {
        case "apps":
            results = Apps.search(search.text);
            break;
        case "actions":
            results = Actions.query(search.text);
            break;
        case "calc":
            results = [0];
            break;
        case "scheme":
            results = Schemes.query(search.text);
            break;
        case "variant":
            results = M3Variants.query(search.text);
            break;
        default:
            results = [];
        }

        // Clear model first to avoid ScriptModel::updateValuesUnique move bug.
        // Going [] -> [items] only triggers inserts (no moves), avoiding the
        // segfault in QQmlDelegateModelPrivate::itemsMoved.
        model.values = [];
        model.values = results;
    }

    property string _lastMode: ""

    // Debounced search: update after brief pause to reduce model churn
    Timer {
        id: searchDebounce
        interval: 16 // ~1 frame at 60fps - just enough to batch rapid keystrokes
        onTriggered: root.updateResults()
    }

    Connections {
        target: root.search
        function onTextChanged(): void {
            const mode = root.getMode();
            if (mode !== root._lastMode) {
                root._lastMode = mode;
                if (mode === "scheme" || mode === "variant")
                    Schemes.reload();
            }
            searchDebounce.restart();
        }
    }

    // Initial population
    Component.onCompleted: {
        delegate = appItem;
        updateResults();
    }

    StyledScrollBar.vertical: StyledScrollBar {
        flickable: root
    }

    add: Transition {
        Anim {
            properties: "opacity,scale"
            from: 0
            to: 1
        }
    }

    remove: Transition {
        Anim {
            properties: "opacity,scale"
            from: 1
            to: 0
        }
    }

    addDisplaced: Transition {
        Anim {
            property: "y"
            type: Anim.StandardSmall
        }
        Anim {
            properties: "opacity,scale"
            to: 1
        }
    }

    displaced: Transition {
        Anim {
            property: "y"
        }
        Anim {
            properties: "opacity,scale"
            to: 1
        }
    }

    Component {
        id: appItem

        AppItem {
            visibilities: root.visibilities
        }
    }

    Component {
        id: actionItem

        ActionItem {
            list: root
        }
    }

    Component {
        id: calcItem

        CalcItem {
            list: root
        }
    }

    Component {
        id: schemeItem

        SchemeItem {
            list: root
        }
    }

    Component {
        id: variantItem

        VariantItem {
            list: root
        }
    }
}
