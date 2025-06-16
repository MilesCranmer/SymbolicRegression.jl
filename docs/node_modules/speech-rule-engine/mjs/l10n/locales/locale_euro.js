import { createLocale } from '../locale.js';
let locale = null;
export function euro() {
    if (!locale) {
        locale = createLocale();
    }
    return locale;
}
