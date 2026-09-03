.import "../../ui/js/Menu.js" as Menu
.import "../../ui/js/Archive.js" as Archive

// ui/MenuRow.qml sizes its disclosure slot from this one predicate, and it used to test
// submenu === true. Every row ui/ContextMenu.qml builds puts the flyout's own entries in that
// field instead, so the slot was zero wide on every submenu row and no chevron was ever drawn.
// The bug survived because the menu's sibling test at ui/ContextMenu.qml "onActivated" asks
// !== undefined, so the flyout opened correctly and only the affordance was missing.

function run(check) {
    runMenu(check)
    check("a Compress row carrying the probed formats is a submenu row",
          Menu.hasSubmenu({ label: "Compress", action: "compress",
                            submenu: Archive.formatEntries(["zip", "7z"]) }),
          true)
    check("a Taildrop row with no peer yet is still a submenu row, so the disclosure stays",
          Menu.hasSubmenu({ label: "Send with Taildrop", action: "taildrop", submenu: [] }),
          true)
    check("a plain action row has no submenu",
          Menu.hasSubmenu({ label: "Rename", action: "rename", glyph: "rename" }),
          false)
    check("a separator has no submenu",
          Menu.hasSubmenu({ separator: true }), false)
    check("ui/MenuRow.qml's own default entry has no submenu",
          Menu.hasSubmenu({}), false)
    check("a missing entry answers false rather than throwing",
          Menu.hasSubmenu(undefined) + "|" + Menu.hasSubmenu(null), "false|false")

    // ui/ContextMenu.qml used to clamp against frame.height inside place(), and a Column hands its
    // implicitHeight to the frame one polish after the model changes. So every menu was placed
    // against the height of the menu that was open before it. The two numbers below are what an
    // offscreen model of that file measured, at a pane 800 tall with rows of 37 and an inset of 7:
    // a listing menu is 310, the rail's single Eject row is 51.
    var pane = 800
    var listingMenu = 310
    var railMenu = 51

    check("a menu that fits under the row opens exactly there",
          Menu.clamp(100, listingMenu, pane), 100)
    check("a menu that would run out through the bottom is pulled back to sit against it",
          Menu.clamp(700, listingMenu, pane) + "|" + (Menu.clamp(700, listingMenu, pane) + listingMenu),
          "490|800")
    check("the rail menu low in the sidebar sits against the bottom, not 280 px above the row",
          Menu.clamp(770, railMenu, pane), 749)
    check("clamping the rail menu against the listing menu still resident is the defect itself",
          Menu.clamp(770, listingMenu, pane), 490)
    check("a point off the near edge pins to it rather than going negative",
          Menu.clamp(-40, railMenu, pane), 0)
    check("a frame taller than the pane pins to the near edge, which is where its tail is cut",
          Menu.clamp(700, 1200, pane), 0)
}

// ui/js/Menu.js listingEntries: the listing's rows, built from the pane's state in one object.
// The row order below is the canvas's own, and the Open row now carries the resolved application
// name as a muted suffix (ui/MenuRow.qml draws it after the label), beside a Copy Path row.

function labels(entries) {
    var out = []
    for (var i = 0; i < entries.length; i++)
        out.push(entries[i].separator === true ? "-" : entries[i].label)
    return out.join("|")
}

function findEntry(entries, action) {
    for (var i = 0; i < entries.length; i++)
        if (entries[i].action === action)
            return entries[i]
    return {}
}

function runMenu(check) {
    var full = Menu.listingEntries({
        showHidden: false, hasRow: true, rowInDropbox: false,
        dropboxPath: "/home/jw/Dropbox", taildropPeers: [{ id: "x", label: "Box" }],
        archiveFormats: ["zip"], rowIsArchive: false, rowIsImage: false, canConvert: true,
        openSuffix: "Sublime Text"
    })
    check("the listing menu opens with the row's own Open", full[0].label + "|" + full[0].suffix, "Open|Sublime Text")
    check("Copy Path sits beside Open", findEntry(full, "copypath").label, "Copy Path")
    check("the hidden toggle moved behind Advanced, off the top level",
          findEntry(full, "toggleHidden").label + "|" + findEntry(full, "advanced").submenu[0].label,
          "undefined|Show hidden files")
    check("Advanced carries the hidden toggle, flipping with the state",
          Menu.advancedRows(false)[0].label + "|" + Menu.advancedRows(true)[0].label,
          "Show hidden files|Hide hidden files")
    check("an empty listing still offers New Folder and Advanced",
          labels(Menu.listingEntries({ showHidden: false, hasRow: false, rowInDropbox: false,
                                       dropboxPath: "", taildropPeers: [], archiveFormats: [],
                                       rowIsArchive: false, rowIsImage: false, canConvert: false,
                                       openSuffix: "" })),
          "New Folder|Advanced")
    check("a directory's Open row carries no app name, because flea opens it itself",
          Menu.listingEntries({ showHidden: false, hasRow: true, rowInDropbox: false,
                                dropboxPath: "", taildropPeers: [], archiveFormats: [],
                                rowIsArchive: false, rowIsImage: false, canConvert: false,
                                openSuffix: "" })[0].suffix, "")

    // ui/Header.qml's own rows, on a right click over the column titles. Four toggles, flipping
    // labels, each answering "col:<key>"; Name is absent because it never hides.
    var head = Menu.headerEntries([], false, true)
    check("the header menu offers the four optional columns, flipping labels when hidden, then the two state rows flat",
          labels(Menu.headerEntries(["size"], false, false)),
          "Hide Mode|Show Size|Hide Date Modified|Hide Kind|-|Show hidden files|Keep folders first")
    check("every column row answers col:<key>",
          findEntry(head, "col:size").action + "|" + findEntry(head, "col:kind").action,
          "col:size|col:kind")
    check("the header menu is flat: the hidden toggle is a top-level row, no Advanced",
          findEntry(head, "toggleHidden").label + "|" + findEntry(head, "advanced").label,
          "Show hidden files|undefined")
    check("the header menu carries the folders-first flip, both ways",
          findEntry(head, "foldersFirst").label + "|" + Menu.headerEntries([], false, false)[6].label,
          "Mix folders and files|Keep folders first")
}
