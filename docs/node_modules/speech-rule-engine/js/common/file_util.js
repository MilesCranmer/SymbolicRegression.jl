"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.makePath = makePath;
exports.localePath = localePath;
const system_external_js_1 = require("./system_external.js");
function makePath(path) {
    return path.match('/$') ? path : path + '/';
}
function localePath(locale, ext = 'json') {
    return (makePath(system_external_js_1.SystemExternal.jsonPath) +
        locale +
        (ext.match(/^\./) ? ext : '.' + ext));
}
