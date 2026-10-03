// SPDX-License-Identifier: GPL-2.0-or-later
function buildRows(counts, columns, expanded) {
    var result = [];
    columns = Math.max(1, Math.floor(columns));
    for (var category = 0; category < counts.length; ++category) {
        var count = Math.max(0, counts[category]);
        result.push({ kind: "header", category: category, firstIndex: -1 });
        var rows = expanded[category] ? Math.ceil(count / columns) : Math.min(1, Math.ceil(count / columns));
        for (var row = 0; row < rows; ++row) result.push({ kind: "apps", category: category, firstIndex: row * columns });
    }
    return result;
}
if (typeof module !== "undefined") module.exports = { buildRows: buildRows };
