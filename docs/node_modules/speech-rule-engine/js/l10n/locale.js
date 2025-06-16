"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.LOCALE = void 0;
exports.createLocale = createLocale;
const messages_js_1 = require("./messages.js");
exports.LOCALE = createLocale();
function createLocale() {
    return {
        FUNCTIONS: (0, messages_js_1.FUNCTIONS)(),
        MESSAGES: (0, messages_js_1.MESSAGES)(),
        ALPHABETS: (0, messages_js_1.ALPHABETS)(),
        NUMBERS: (0, messages_js_1.NUMBERS)(),
        COMBINERS: {},
        CORRECTIONS: {},
        SUBISO: (0, messages_js_1.SUBISO)()
    };
}
