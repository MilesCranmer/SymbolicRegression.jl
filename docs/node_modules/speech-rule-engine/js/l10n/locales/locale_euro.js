"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.euro = euro;
const locale_js_1 = require("../locale.js");
let locale = null;
function euro() {
    if (!locale) {
        locale = (0, locale_js_1.createLocale)();
    }
    return locale;
}
