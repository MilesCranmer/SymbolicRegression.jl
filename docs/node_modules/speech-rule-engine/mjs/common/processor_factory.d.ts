import { KeyCode } from './event_util.js';
export declare function process<T>(name: string, expr: string): T;
export declare function output(name: string, expr: string): string;
export declare function keypress(name: string, expr: KeyCode | string): string;
