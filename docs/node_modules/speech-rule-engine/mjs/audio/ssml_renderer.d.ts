import { Pause } from './audio_util.js';
import { AuditoryDescription } from './auditory_description.js';
import { Span } from './span.js';
import { XmlRenderer } from './xml_renderer.js';
export declare class SsmlRenderer extends XmlRenderer {
    finalize(str: string): string;
    pause(pause: Pause): string;
    prosodyElement(attr: string, value: number): string;
    closeTag(_tag: string): string;
    static MARK_ONCE: boolean;
    static MARK_KIND: boolean;
    private static CHARACTER_ATTR;
    private static MARKS;
    markup(descrs: AuditoryDescription[]): string;
    merge(spans: Span[]): string;
    private isEmptySpan;
}
