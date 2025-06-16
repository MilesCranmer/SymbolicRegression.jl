import { Locale } from './locale.js';
export declare const locales: {
    [key: string]: () => Locale;
};
export declare function setLocale(): void;
export declare function completeLocale(json: any): void;
