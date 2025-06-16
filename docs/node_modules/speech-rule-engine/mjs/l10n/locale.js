import { ALPHABETS, FUNCTIONS, MESSAGES, NUMBERS, SUBISO } from './messages.js';
export const LOCALE = createLocale();
export function createLocale() {
    return {
        FUNCTIONS: FUNCTIONS(),
        MESSAGES: MESSAGES(),
        ALPHABETS: ALPHABETS(),
        NUMBERS: NUMBERS(),
        COMBINERS: {},
        CORRECTIONS: {},
        SUBISO: SUBISO()
    };
}
