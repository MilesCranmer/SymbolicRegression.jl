declare module '@xmldom/xmldom' {
	// START ./lib/conventions.js
	/**
	 * Since xmldom can not rely on `Object.assign`,
	 * it uses/provides a simplified version that is sufficient for its needs.
	 *
	 * @throws {TypeError}
	 * If target is not an object.
	 * @see https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/assign
	 * @see https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-object.assign
	 */
	function assign<T, S>(target: T, source: S): T & S;

	/**
	 * For both the `text/html` and the `application/xhtml+xml` namespace the spec defines that
	 * the HTML namespace is provided as the default.
	 *
	 * @param {string} mimeType
	 * @returns {boolean}
	 * @see https://dom.spec.whatwg.org/#dom-document-createelement
	 * @see https://dom.spec.whatwg.org/#dom-domimplementation-createdocument
	 * @see https://dom.spec.whatwg.org/#dom-domimplementation-createhtmldocument
	 */
	function hasDefaultHTMLNamespace(
		mimeType: string
	): mimeType is typeof MIME_TYPE.HTML | typeof MIME_TYPE.XML_XHTML_APPLICATION;

	/**
	 * Only returns true if `value` matches MIME_TYPE.HTML, which indicates an HTML document.
	 *
	 * @see https://www.iana.org/assignments/media-types/text/html
	 * @see https://en.wikipedia.org/wiki/HTML
	 * @see https://developer.mozilla.org/en-US/docs/Web/API/DOMParser/parseFromString
	 * @see https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-domparser-parsefromstring
	 */
	function isHTMLMimeType(mimeType: string): mimeType is typeof MIME_TYPE.HTML;

	/**
	 * Only returns true if `mimeType` is one of the allowed values for `DOMParser.parseFromString`.
	 */
	function isValidMimeType(mimeType: string): mimeType is MIME_TYPE;

	/**
	 * All mime types that are allowed as input to `DOMParser.parseFromString`
	 *
	 * @see https://developer.mozilla.org/en-US/docs/Web/API/DOMParser/parseFromString#Argument02
	 *      MDN
	 * @see https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#domparsersupportedtype
	 *      WHATWG HTML Spec
	 * @see {@link DOMParser.prototype.parseFromString}
	 */
	type MIME_TYPE = (typeof MIME_TYPE)[keyof typeof MIME_TYPE];
	/**
	 * All mime types that are allowed as input to `DOMParser.parseFromString`
	 *
	 * @see https://developer.mozilla.org/en-US/docs/Web/API/DOMParser/parseFromString#Argument02
	 *      MDN
	 * @see https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#domparsersupportedtype
	 *      WHATWG HTML Spec
	 * @see {@link DOMParser.prototype.parseFromString}
	 */
	var MIME_TYPE: {
		/**
		 * `text/html`, the only mime type that triggers treating an XML document as HTML.
		 *
		 * @see https://www.iana.org/assignments/media-types/text/html IANA MimeType registration
		 * @see https://en.wikipedia.org/wiki/HTML Wikipedia
		 * @see https://developer.mozilla.org/en-US/docs/Web/API/DOMParser/parseFromString MDN
		 * @see https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-domparser-parsefromstring
		 *      WHATWG HTML Spec
		 */
		readonly HTML: 'text/html';
		/**
		 * `application/xml`, the standard mime type for XML documents.
		 *
		 * @see https://www.iana.org/assignments/media-types/application/xml IANA MimeType
		 *      registration
		 * @see https://tools.ietf.org/html/rfc7303#section-9.1 RFC 7303
		 * @see https://en.wikipedia.org/wiki/XML_and_MIME Wikipedia
		 */
		readonly XML_APPLICATION: 'application/xml';
		/**
		 * `text/html`, an alias for `application/xml`.
		 *
		 * @see https://tools.ietf.org/html/rfc7303#section-9.2 RFC 7303
		 * @see https://www.iana.org/assignments/media-types/text/xml IANA MimeType registration
		 * @see https://en.wikipedia.org/wiki/XML_and_MIME Wikipedia
		 */
		readonly XML_TEXT: 'text/xml';
		/**
		 * `application/xhtml+xml`, indicates an XML document that has the default HTML namespace,
		 * but is parsed as an XML document.
		 *
		 * @see https://www.iana.org/assignments/media-types/application/xhtml+xml IANA MimeType
		 *      registration
		 * @see https://dom.spec.whatwg.org/#dom-domimplementation-createdocument WHATWG DOM Spec
		 * @see https://en.wikipedia.org/wiki/XHTML Wikipedia
		 */
		readonly XML_XHTML_APPLICATION: 'application/xhtml+xml';
		/**
		 * `image/svg+xml`,
		 *
		 * @see https://www.iana.org/assignments/media-types/image/svg+xml IANA MimeType registration
		 * @see https://www.w3.org/TR/SVG11/ W3C SVG 1.1
		 * @see https://en.wikipedia.org/wiki/Scalable_Vector_Graphics Wikipedia
		 */
		readonly XML_SVG_IMAGE: 'image/svg+xml';
	};
	/**
	 * Namespaces that are used in xmldom.
	 *
	 * @see http://www.w3.org/TR/REC-xml-names
	 */
	type NAMESPACE = (typeof NAMESPACE)[keyof typeof NAMESPACE];
	/**
	 * Namespaces that are used in xmldom.
	 *
	 * @see http://www.w3.org/TR/REC-xml-names
	 */
	var NAMESPACE: {
		/**
		 * The XHTML namespace.
		 *
		 * @see http://www.w3.org/1999/xhtml
		 */
		readonly HTML: 'http://www.w3.org/1999/xhtml';
		/**
		 * The SVG namespace.
		 *
		 * @see http://www.w3.org/2000/svg
		 */
		readonly SVG: 'http://www.w3.org/2000/svg';
		/**
		 * The `xml:` namespace.
		 *
		 * @see http://www.w3.org/XML/1998/namespace
		 */
		readonly XML: 'http://www.w3.org/XML/1998/namespace';

		/**
		 * The `xmlns:` namespace.
		 *
		 * @see https://www.w3.org/2000/xmlns/
		 */
		readonly XMLNS: 'http://www.w3.org/2000/xmlns/';
	};

	// END ./lib/conventions.js

	// START ./lib/errors.js
	type DOMExceptionName =
		(typeof DOMExceptionName)[keyof typeof DOMExceptionName];
	var DOMExceptionName: {
		/**
		 * the default value as defined by the spec
		 */
		readonly Error: 'Error';
		/**
		 * @deprecated
		 * Use RangeError instead.
		 */
		readonly IndexSizeError: 'IndexSizeError';
		/**
		 * @deprecated
		 * Just to match the related static code, not part of the spec.
		 */
		readonly DomstringSizeError: 'DomstringSizeError';
		readonly HierarchyRequestError: 'HierarchyRequestError';
		readonly WrongDocumentError: 'WrongDocumentError';
		readonly InvalidCharacterError: 'InvalidCharacterError';
		/**
		 * @deprecated
		 * Just to match the related static code, not part of the spec.
		 */
		readonly NoDataAllowedError: 'NoDataAllowedError';
		readonly NoModificationAllowedError: 'NoModificationAllowedError';
		readonly NotFoundError: 'NotFoundError';
		readonly NotSupportedError: 'NotSupportedError';
		readonly InUseAttributeError: 'InUseAttributeError';
		readonly InvalidStateError: 'InvalidStateError';
		readonly SyntaxError: 'SyntaxError';
		readonly InvalidModificationError: 'InvalidModificationError';
		readonly NamespaceError: 'NamespaceError';
		/**
		 * @deprecated
		 * Use TypeError for invalid arguments,
		 * "NotSupportedError" DOMException for unsupported operations,
		 * and "NotAllowedError" DOMException for denied requests instead.
		 */
		readonly InvalidAccessError: 'InvalidAccessError';
		/**
		 * @deprecated
		 * Just to match the related static code, not part of the spec.
		 */
		readonly ValidationError: 'ValidationError';
		/**
		 * @deprecated
		 * Use TypeError instead.
		 */
		readonly TypeMismatchError: 'TypeMismatchError';
		readonly SecurityError: 'SecurityError';
		readonly NetworkError: 'NetworkError';
		readonly AbortError: 'AbortError';
		/**
		 * @deprecated
		 * Just to match the related static code, not part of the spec.
		 */
		readonly URLMismatchError: 'URLMismatchError';
		readonly QuotaExceededError: 'QuotaExceededError';
		readonly TimeoutError: 'TimeoutError';
		readonly InvalidNodeTypeError: 'InvalidNodeTypeError';
		readonly DataCloneError: 'DataCloneError';
		readonly EncodingError: 'EncodingError';
		readonly NotReadableError: 'NotReadableError';
		readonly UnknownError: 'UnknownError';
		readonly ConstraintError: 'ConstraintError';
		readonly DataError: 'DataError';
		readonly TransactionInactiveError: 'TransactionInactiveError';
		readonly ReadOnlyError: 'ReadOnlyError';
		readonly VersionError: 'VersionError';
		readonly OperationError: 'OperationError';
		readonly NotAllowedError: 'NotAllowedError';
		readonly OptOutError: 'OptOutError';
	};
	type ExceptionCode = (typeof ExceptionCode)[keyof typeof ExceptionCode];

	var ExceptionCode: {
		readonly INDEX_SIZE_ERR: 1;
		readonly DOMSTRING_SIZE_ERR: 2;
		readonly HIERARCHY_REQUEST_ERR: 3;
		readonly WRONG_DOCUMENT_ERR: 4;
		readonly INVALID_CHARACTER_ERR: 5;
		readonly NO_DATA_ALLOWED_ERR: 6;
		readonly NO_MODIFICATION_ALLOWED_ERR: 7;
		readonly NOT_FOUND_ERR: 8;
		readonly NOT_SUPPORTED_ERR: 9;
		readonly INUSE_ATTRIBUTE_ERR: 10;
		readonly INVALID_STATE_ERR: 11;
		readonly SYNTAX_ERR: 12;
		readonly INVALID_MODIFICATION_ERR: 13;
		readonly NAMESPACE_ERR: 14;
		readonly INVALID_ACCESS_ERR: 15;
		readonly VALIDATION_ERR: 16;
		readonly TYPE_MISMATCH_ERR: 17;
		readonly SECURITY_ERR: 18;
		readonly NETWORK_ERR: 19;
		readonly ABORT_ERR: 20;
		readonly URL_MISMATCH_ERR: 21;
		readonly QUOTA_EXCEEDED_ERR: 22;
		readonly TIMEOUT_ERR: 23;
		readonly INVALID_NODE_TYPE_ERR: 24;
		readonly DATA_CLONE_ERR: 25;
	};

	/**
	 * DOM operations only raise exceptions in "exceptional" circumstances, i.e., when an
	 * operation is impossible to perform (either for logical reasons, because data is lost, or
	 * because the implementation has become unstable). In general, DOM methods return specific
	 * error values in ordinary processing situations, such as out-of-bound errors when using
	 * NodeList.
	 *
	 * Implementations should raise other exceptions under other circumstances. For example,
	 * implementations should raise an implementation-dependent exception if a null argument is
	 * passed when null was not expected.
	 *
	 * This implementation supports the following usages:
	 * 1. according to the living standard (both arguments are optional):
	 * ```
	 * new DOMException("message (can be empty)", DOMExceptionNames.HierarchyRequestError)
	 * ```
	 * 2. according to previous xmldom implementation (only the first argument is required):
	 * ```
	 * new DOMException(DOMException.HIERARCHY_REQUEST_ERR, "optional message")
	 * ```
	 * both result in the proper name being set.
	 *
	 * @see https://webidl.spec.whatwg.org/#idl-DOMException
	 * @see https://webidl.spec.whatwg.org/#dfn-error-names-table
	 * @see https://www.w3.org/TR/DOM-Level-3-Core/core.html#ID-17189187
	 * @see http://www.w3.org/TR/2000/REC-DOM-Level-2-Core-20001113/ecma-script-binding.html
	 * @see http://www.w3.org/TR/REC-DOM-Level-1/ecma-script-language-binding.html
	 */
	class DOMException extends Error {
		constructor(message?: string, name?: DOMExceptionName | string);
		constructor(code?: ExceptionCode, message?: string);

		readonly name: DOMExceptionName;
		readonly code: ExceptionCode | 0;
		static readonly INDEX_SIZE_ERR: 1;
		static readonly DOMSTRING_SIZE_ERR: 2;
		static readonly HIERARCHY_REQUEST_ERR: 3;
		static readonly WRONG_DOCUMENT_ERR: 4;
		static readonly INVALID_CHARACTER_ERR: 5;
		static readonly NO_DATA_ALLOWED_ERR: 6;
		static readonly NO_MODIFICATION_ALLOWED_ERR: 7;
		static readonly NOT_FOUND_ERR: 8;
		static readonly NOT_SUPPORTED_ERR: 9;
		static readonly INUSE_ATTRIBUTE_ERR: 10;
		static readonly INVALID_STATE_ERR: 11;
		static readonly SYNTAX_ERR: 12;
		static readonly INVALID_MODIFICATION_ERR: 13;
		static readonly NAMESPACE_ERR: 14;
		static readonly INVALID_ACCESS_ERR: 15;
		static readonly VALIDATION_ERR: 16;
		static readonly TYPE_MISMATCH_ERR: 17;
		static readonly SECURITY_ERR: 18;
		static readonly NETWORK_ERR: 19;
		static readonly ABORT_ERR: 20;
		static readonly URL_MISMATCH_ERR: 21;
		static readonly QUOTA_EXCEEDED_ERR: 22;
		static readonly TIMEOUT_ERR: 23;
		static readonly INVALID_NODE_TYPE_ERR: 24;
		static readonly DATA_CLONE_ERR: 25;
	}

	/**
	 * Creates an error that will not be caught by XMLReader aka the SAX parser.
	 */
	class ParseError extends Error {
		constructor(message: string, locator?: any, cause?: Error);

		readonly message: string;
		readonly locator?: any;
	}

	// END ./lib/errors.js

	// START ./lib/dom.js

	type InstanceOf<T> = {
		// instanceof pre ts 5.3
		(val: unknown): val is T;
		// instanceof post ts 5.3
		[Symbol.hasInstance](val: unknown): val is T;
	};

	type GetRootNodeOptions = {
		composed?: boolean;
	};

	/**
	 * The DOM Node interface is an abstract base class upon which many other DOM API objects are
	 * based, thus letting those object types to be used similarly and often interchangeably. As an
	 * abstract class, there is no such thing as a plain Node object. All objects that implement
	 * Node functionality are based on one of its subclasses. Most notable are Document, Element,
	 * and DocumentFragment.
	 *
	 * In addition, every kind of DOM node is represented by an interface based on Node. These
	 * include Attr, CharacterData (which Text, Comment, CDATASection and ProcessingInstruction are
	 * all based on), and DocumentType.
	 *
	 * In some cases, a particular feature of the base Node interface may not apply to one of its
	 * child interfaces; in that case, the inheriting node may return null or throw an exception,
	 * depending on circumstances. For example, attempting to add children to a node type that
	 * cannot have children will throw an exception.
	 *
	 * **This behavior is slightly different from the in the specs**:
	 * - unimplemented interfaces: EventTarget
	 *
	 * @see http://www.w3.org/TR/2000/REC-DOM-Level-2-Core-20001113/core.html#ID-1950641247
	 * @see https://dom.spec.whatwg.org/#node
	 * @prettierignore
	 */
	interface Node {
		/**
		 * Returns the children.
		 *
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Node/childNodes)
		 */
		readonly childNodes: NodeList;
		/**
		 * Returns the first child.
		 *
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Node/firstChild)
		 */
		readonly firstChild: Node | null;
		/**
		 * Returns the last child.
		 *
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Node/lastChild)
		 */
		readonly lastChild: Node | null;
		/**
		 * The local part of the qualified name of this node.
		 */
		localName: string | null;
		/**
		 * Always returns `about:blank` currently.
		 *
		 * [MDN Reference](https://developer.mozilla.org/en-US/docs/Web/API/Node/baseURI)
		 */
		readonly baseURI: 'about:blank';
		/**
		 * Returns true if this node is inside of a document or is the document node itself.
		 *
		 * [MDN Reference](https://developer.mozilla.org/en-US/docs/Web/API/Node/isConnected)
		 */
		readonly isConnected: boolean;
		/**
		 * The namespace URI of this node.
		 */
		readonly namespaceURI: string | null;
		/**
		 * Returns the next sibling.
		 *
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Node/nextSibling)
		 */
		readonly nextSibling: Node | null;
		/**
		 * Returns a string appropriate for the type of node.
		 *
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Node/nodeName)
		 */
		readonly nodeName: string;
		/**
		 * Returns the type of node.
		 *
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Node/nodeType)
		 */
		readonly nodeType: number;
		/** [MDN Reference](https://developer.mozilla.org/docs/Web/API/Node/nodeValue) */
		nodeValue: string | null;
		/**
		 * Returns the node document. Returns null for documents.
		 *
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Node/ownerDocument)
		 */
		readonly ownerDocument: Document | null;
		/**
		 * Returns the parent.
		 *
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Node/parentNode)
		 */
		readonly parentNode: Node | null;
		/**
		 * Returns the parent `Node` if it is of type `Element`, otherwise `null`.
		 *
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Node/parentElement)
		 */
		readonly parentElement: Element | null;
		/**
		 * The prefix of the namespace for this node.
		 */
		prefix: string | null;
		/**
		 * Returns the previous sibling.
		 *
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Node/previousSibling)
		 */
		readonly previousSibling: Node | null;
		/** [MDN Reference](https://developer.mozilla.org/docs/Web/API/Node/textContent) */
		textContent: string | null;

		/**
		 * Zero based line position inside the parsed source,
		 * if the `locator` was not disabled.
		 */
		lineNumber?: number;
		/**
		 * One based column position inside the parsed source,
		 * if the `locator` was not disabled.
		 */
		columnNumber?: number;

		/** [MDN Reference](https://developer.mozilla.org/docs/Web/API/Node/appendChild) */
		appendChild(node: Node): Node;

		/**
		 * Checks whether `other` is an inclusive descendant of this node.
		 *
		 * [MDN Reference](https://developer.mozilla.org/en-US/docs/Web/API/Node/contains)
		 */
		contains(other: Node | null | undefined): boolean;
		/**
		 * Searches for the root node of this node.
		 *
		 * **This behavior is slightly different from the one in the specs**:
		 * - ignores `options.composed`, since `ShadowRoot`s are unsupported, therefore always
		 * returning root.
		 *
		 * [MDN Reference](https://developer.mozilla.org/en-US/docs/Web/API/Node/getRootNode)
		 *
		 * @see https://dom.spec.whatwg.org/#dom-node-getrootnode
		 * @see https://dom.spec.whatwg.org/#concept-shadow-including-root
		 */
		getRootNode(options: GetRootNodeOptions): Node;

		/**
		 * Checks whether the given node is equal to this node.
		 *
		 * [MDN Reference](https://developer.mozilla.org/en-US/docs/Web/API/Node/isEqualNode)
		 */
		isEqualNode(other: Node): boolean;

		/**
		 * Checks whether the given node is this node.
		 *
		 * [MDN Reference](https://developer.mozilla.org/en-US/docs/Web/API/Node/isSameNode)
		 */
		isSameNode(other: Node): boolean;

		/**
		 * Returns a copy of node. If deep is true, the copy also includes the node's descendants.
		 *
		 * @throws {DOMException}
		 * May throw a DOMException if operations within {@link Element#setAttributeNode} or
		 * {@link Node#appendChild} (which are potentially invoked in this method) do not meet their
		 * specific constraints.
		 *
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Node/cloneNode)
		 */
		cloneNode(deep?: boolean): Node;

		/**
		 * Returns a bitmask indicating the position of other relative to node.
		 *
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Node/compareDocumentPosition)
		 */
		compareDocumentPosition(other: Node): number;

		/**
		 * Returns whether node has children.
		 *
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Node/hasChildNodes)
		 */
		hasChildNodes(): boolean;

		/** [MDN Reference](https://developer.mozilla.org/docs/Web/API/Node/insertBefore) */
		insertBefore(node: Node, child: Node | null): Node;

		/** [MDN Reference](https://developer.mozilla.org/docs/Web/API/Node/isDefaultNamespace) */
		isDefaultNamespace(namespace: string | null): boolean;

		/**
		 * Checks whether the DOM implementation implements a specific feature and its version.
		 *
		 * @deprecated
		 * Since `DOMImplementation.hasFeature` is deprecated and always returns true.
		 * @param feature
		 * The package name of the feature to test. This is the same name that can be passed to the
		 * method `hasFeature` on `DOMImplementation`.
		 * @param version
		 * This is the version number of the package name to test.
		 * @since Introduced in DOM Level 2
		 * @see {@link DOMImplementation.hasFeature}
		 */
		isSupported(feature: string, version: string): true;

		/** [MDN Reference](https://developer.mozilla.org/docs/Web/API/Node/lookupNamespaceURI) */
		lookupNamespaceURI(prefix: string | null): string | null;

		/** [MDN Reference](https://developer.mozilla.org/docs/Web/API/Node/lookupPrefix) */
		lookupPrefix(namespace: string | null): string | null;

		/**
		 * Removes empty exclusive Text nodes and concatenates the data of remaining contiguous
		 * exclusive Text nodes into the first of their nodes.
		 *
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Node/normalize)
		 */
		normalize(): void;

		/** [MDN Reference](https://developer.mozilla.org/docs/Web/API/Node/removeChild) */
		removeChild(child: Node): Node;

		/** [MDN Reference](https://developer.mozilla.org/docs/Web/API/Node/replaceChild) */
		replaceChild(node: Node, child: Node): Node;

		/** node is an element. */
		readonly ELEMENT_NODE: 1;
		readonly ATTRIBUTE_NODE: 2;
		/** node is a Text node. */
		readonly TEXT_NODE: 3;
		/** node is a CDATASection node. */
		readonly CDATA_SECTION_NODE: 4;
		readonly ENTITY_REFERENCE_NODE: 5;
		readonly ENTITY_NODE: 6;
		/** node is a ProcessingInstruction node. */
		readonly PROCESSING_INSTRUCTION_NODE: 7;
		/** node is a Comment node. */
		readonly COMMENT_NODE: 8;
		/** node is a document. */
		readonly DOCUMENT_NODE: 9;
		/** node is a doctype. */
		readonly DOCUMENT_TYPE_NODE: 10;
		/** node is a DocumentFragment node. */
		readonly DOCUMENT_FRAGMENT_NODE: 11;
		readonly NOTATION_NODE: 12;
		/** Set when node and other are not in the same tree. */
		readonly DOCUMENT_POSITION_DISCONNECTED: 0x01;
		/** Set when other is preceding node. */
		readonly DOCUMENT_POSITION_PRECEDING: 0x02;
		/** Set when other is following node. */
		readonly DOCUMENT_POSITION_FOLLOWING: 0x04;
		/** Set when other is an ancestor of node. */
		readonly DOCUMENT_POSITION_CONTAINS: 0x08;
		/** Set when other is a descendant of node. */
		readonly DOCUMENT_POSITION_CONTAINED_BY: 0x10;
		readonly DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC: 0x20;
	}

	var Node: InstanceOf<Node> & {
		/** node is an element. */
		readonly ELEMENT_NODE: 1;
		readonly ATTRIBUTE_NODE: 2;
		/** node is a Text node. */
		readonly TEXT_NODE: 3;
		/** node is a CDATASection node. */
		readonly CDATA_SECTION_NODE: 4;
		readonly ENTITY_REFERENCE_NODE: 5;
		readonly ENTITY_NODE: 6;
		/** node is a ProcessingInstruction node. */
		readonly PROCESSING_INSTRUCTION_NODE: 7;
		/** node is a Comment node. */
		readonly COMMENT_NODE: 8;
		/** node is a document. */
		readonly DOCUMENT_NODE: 9;
		/** node is a doctype. */
		readonly DOCUMENT_TYPE_NODE: 10;
		/** node is a DocumentFragment node. */
		readonly DOCUMENT_FRAGMENT_NODE: 11;
		readonly NOTATION_NODE: 12;
		/** Set when node and other are not in the same tree. */
		readonly DOCUMENT_POSITION_DISCONNECTED: 0x01;
		/** Set when other is preceding node. */
		readonly DOCUMENT_POSITION_PRECEDING: 0x02;
		/** Set when other is following node. */
		readonly DOCUMENT_POSITION_FOLLOWING: 0x04;
		/** Set when other is an ancestor of node. */
		readonly DOCUMENT_POSITION_CONTAINS: 0x08;
		/** Set when other is a descendant of node. */
		readonly DOCUMENT_POSITION_CONTAINED_BY: 0x10;
		readonly DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC: 0x20;
	};

	/**
	 * A DOM element's attribute as an object. In most DOM methods, you will probably directly
	 * retrieve the attribute as a string (e.g., Element.getAttribute(), but certain functions (e.g.,
	 * Element.getAttributeNode()) or means of iterating give Attr types.
	 *
	 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Attr)
	 */
	interface Attr extends Node {
		readonly nodeType: typeof Node.ATTRIBUTE_NODE;
		/** [MDN Reference](https://developer.mozilla.org/docs/Web/API/Attr/name) */
		readonly name: string;
		/** [MDN Reference](https://developer.mozilla.org/docs/Web/API/Attr/namespaceURI) */
		readonly namespaceURI: string | null;
		readonly ownerDocument: Document;
		/** [MDN Reference](https://developer.mozilla.org/docs/Web/API/Attr/ownerElement) */
		readonly ownerElement: Element | null;
		/** [MDN Reference](https://developer.mozilla.org/docs/Web/API/Attr/prefix) */
		readonly prefix: string | null;
		/**
		 * @deprecated
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Attr/specified)
		 */
		readonly specified: true;
		/** [MDN Reference](https://developer.mozilla.org/docs/Web/API/Attr/value) */
		value: string;
	}
	/**
	 * A DOM element's attribute as an object. In most DOM methods, you will probably directly
	 * retrieve the attribute as a string (e.g., Element.getAttribute(), but certain functions (e.g.,
	 * Element.getAttributeNode()) or means of iterating give Attr types.
	 *
	 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Attr)
	 */
	var Attr: InstanceOf<Attr>;

	/**
	 * Objects implementing the NamedNodeMap interface are used to represent collections of nodes
	 * that can be accessed by name.
	 * Note that NamedNodeMap does not inherit from NodeList;
	 * NamedNodeMaps are not maintained in any particular order.
	 * Objects contained in an object implementing NamedNodeMap may also be accessed by an ordinal
	 * index,
	 * but this is simply to allow convenient enumeration of the contents of a NamedNodeMap,
	 * and does not imply that the DOM specifies an order to these Nodes.
	 * NamedNodeMap objects in the DOM are live.
	 * used for attributes or DocumentType entities
	 *
	 * This implementation only supports property indices, but does not support named properties,
	 * as specified in the living standard.
	 *
	 * @see https://dom.spec.whatwg.org/#interface-namednodemap
	 * @see https://webidl.spec.whatwg.org/#dfn-supported-property-names
	 */
	class NamedNodeMap implements Iterable<Attr> {
		/** [MDN Reference](https://developer.mozilla.org/docs/Web/API/NamedNodeMap/length) */
		readonly length: number;
		/**
		 * Get an attribute by name. Note: Name is in lower case in case of HTML namespace and
		 * document.
		 *
		 * @see https://dom.spec.whatwg.org/#concept-element-attributes-get-by-name
		 */
		getNamedItem(qualifiedName: string): Attr | null;
		/**
		 * Get an attribute by namespace and local name.
		 *
		 * @see https://dom.spec.whatwg.org/#concept-element-attributes-get-by-namespace
		 */
		getNamedItemNS(namespace: string | null, localName: string): Attr | null;
		/** [MDN Reference](https://developer.mozilla.org/docs/Web/API/NamedNodeMap/item) */
		item(index: number): Attr | null;

		/**
		 * Removes an attribute specified by the local name.
		 *
		 * @throws {DOMException}
		 * With code:
		 * - {@link DOMException.NOT_FOUND_ERR} if no attribute with the given name is found.
		 * @see https://dom.spec.whatwg.org/#dom-namednodemap-removenameditem
		 * @see https://dom.spec.whatwg.org/#concept-element-attributes-remove-by-name
		 */
		removeNamedItem(qualifiedName: string): Attr;
		/**
		 * Removes an attribute specified by the namespace and local name.
		 *
		 * @throws {DOMException}
		 * With code:
		 * - {@link DOMException.NOT_FOUND_ERR} if no attribute with the given namespace URI and
		 * local name is found.
		 * @see https://dom.spec.whatwg.org/#dom-namednodemap-removenameditemns
		 * @see https://dom.spec.whatwg.org/#concept-element-attributes-remove-by-namespace
		 */
		removeNamedItemNS(namespace: string | null, localName: string): Attr;
		/**
		 * Set an attribute.
		 *
		 * @throws {DOMException}
		 * With code:
		 * - {@link INUSE_ATTRIBUTE_ERR} - If the attribute is already an attribute of another
		 * element.
		 * @see https://dom.spec.whatwg.org/#concept-element-attributes-set
		 */
		setNamedItem(attr: Attr): Attr | null;
		/**
		 * Set an attribute, replacing an existing attribute with the same local name and namespace
		 * URI if one exists.
		 *
		 * @throws {DOMException}
		 * Throws a DOMException with the name "InUseAttributeError" if the attribute is already an
		 * attribute of another element.
		 * @see https://dom.spec.whatwg.org/#concept-element-attributes-set
		 */
		setNamedItemNS(attr: Attr): Attr | null;
		[index: number]: Attr;
		[Symbol.iterator](): Iterator<Attr>;
	}

	/**
	 * NodeList objects are collections of nodes, usually returned by properties such as
	 * Node.childNodes and methods such as document.querySelectorAll().
	 *
	 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/NodeList)
	 */
	class NodeList<T extends Node = Node> implements Iterable<T> {
		/**
		 * Returns the number of nodes in the collection.
		 *
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/NodeList/length)
		 */
		readonly length: number;
		/**
		 * Returns the node with index index from the collection. The nodes are sorted in tree order.
		 *
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/NodeList/item)
		 */
		item(index: number): T | null;
		/**
		 * Returns a string representation of the NodeList.
		 */
		toString(nodeFilter: (node: T) => T | undefined): string;
		/**
		 * Filters the NodeList based on a predicate.
		 *
		 * @private
		 */
		filter(predicate: (node: T) => boolean): T[];
		/**
		 * Returns the first index at which a given node can be found in the NodeList, or -1 if it is
		 * not present.
		 *
		 * @private
		 */
		indexOf(node: T): number;

		/**
		 * Index based access returns `undefined`, when accessing indexes >= `length`.
		 * But it would break a lot of code (like `Array.from` usages),
		 * if it would be typed as `T | undefined`.
		 */
		[index: number]: T;

		[Symbol.iterator](): Iterator<T>;
	}

	/**
	 * Represents a live collection of nodes that is automatically updated when its associated
	 * document changes.
	 */
	interface LiveNodeList<T extends Node = Node> extends NodeList<T> {}
	/**
	 * Represents a live collection of nodes that is automatically updated when its associated
	 * document changes.
	 */
	var LiveNodeList: InstanceOf<LiveNodeList>;

	/**
	 * Element is the most general base class from which all objects in a Document inherit. It only
	 * has methods and properties common to all kinds of elements. More specific classes inherit from
	 * Element.
	 *
	 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Element)
	 */
	interface Element extends Node {
		readonly nodeType: typeof Node.ELEMENT_NODE;

		/** [MDN Reference](https://developer.mozilla.org/docs/Web/API/Element/attributes) */
		readonly attributes: NamedNodeMap;
		/**
		 * Returns the HTML-uppercased qualified name.
		 *
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Element/tagName)
		 */
		readonly tagName: string;

		/**
		 * Returns element's first attribute whose qualified name is qualifiedName, and null if there
		 * is no such attribute otherwise.
		 *
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Element/getAttribute)
		 */
		getAttribute(qualifiedName: string): string | null;
		/**
		 * Returns element's attribute whose namespace is namespace and local name is localName, and
		 * null if there is no such attribute otherwise.
		 *
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Element/getAttributeNS)
		 */
		getAttributeNS(namespace: string | null, localName: string): string | null;
		/**
		 * Returns the qualified names of all element's attributes. Can contain duplicates.
		 *
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Element/getAttributeNames)
		 */
		getAttributeNames(): string[];
		/** [MDN Reference](https://developer.mozilla.org/docs/Web/API/Element/getAttributeNode) */
		getAttributeNode(qualifiedName: string): Attr | null;
		/** [MDN Reference](https://developer.mozilla.org/docs/Web/API/Element/getAttributeNodeNS) */
		getAttributeNodeNS(
			namespace: string | null,
			localName: string
		): Attr | null;
		/**
		 * Returns a LiveNodeList of all child elements which have **all** of the given class
		 * name(s).
		 *
		 * Returns an empty list if `classNames` is an empty string or only contains HTML white space
		 * characters.
		 *
		 * Warning: This returns a live LiveNodeList.
		 * Changes in the DOM will reflect in the array as the changes occur.
		 * If an element selected by this array no longer qualifies for the selector,
		 * it will automatically be removed. Be aware of this for iteration purposes.
		 *
		 * @see https://developer.mozilla.org/en-US/docs/Web/API/Element/getElementsByClassName
		 * @see https://dom.spec.whatwg.org/#concept-getelementsbyclassname
		 */
		getElementsByClassName(classNames: string): LiveNodeList<Element>;

		/**
		 * Returns a LiveNodeList of elements with the given qualifiedName.
		 * Searching for all descendants can be done by passing `*` as `qualifiedName`.
		 *
		 * All descendants of the specified element are searched, but not the element itself.
		 * The returned list is live, which means it updates itself with the DOM tree automatically.
		 * Therefore, there is no need to call `Element.getElementsByTagName()`
		 * with the same element and arguments repeatedly if the DOM changes in between calls.
		 *
		 * When called on an HTML element in an HTML document,
		 * `getElementsByTagName` lower-cases the argument before searching for it.
		 * This is undesirable when trying to match camel-cased SVG elements (such as
		 * `<linearGradient>`) in an HTML document.
		 * Instead, use `Element.getElementsByTagNameNS()`,
		 * which preserves the capitalization of the tag name.
		 *
		 * `Element.getElementsByTagName` is similar to `Document.getElementsByTagName()`,
		 * except that it only searches for elements that are descendants of the specified element.
		 *
		 * @see https://developer.mozilla.org/en-US/docs/Web/API/Element/getElementsByTagName
		 * @see https://dom.spec.whatwg.org/#concept-getelementsbytagname
		 */
		getElementsByTagName(qualifiedName: string): LiveNodeList<Element>;

		/**
		 * Returns a `LiveNodeList` of elements with the given tag name belonging to the given
		 * namespace. It is similar to `Document.getElementsByTagNameNS`, except that its search is
		 * restricted to descendants of the specified element.
		 *
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Element/getElementsByTagNameNS)
		 * */
		getElementsByTagNameNS(
			namespaceURI: string | null,
			localName: string
		): LiveNodeList<Element>;

		getQualifiedName(): string;
		/**
		 * Returns true if element has an attribute whose qualified name is qualifiedName, and false
		 * otherwise.
		 *
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Element/hasAttribute)
		 */
		hasAttribute(qualifiedName: string): boolean;
		/**
		 * Returns true if element has an attribute whose namespace is namespace and local name is
		 * localName.
		 *
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Element/hasAttributeNS)
		 */
		hasAttributeNS(namespace: string | null, localName: string): boolean;
		/**
		 * Returns true if element has attributes, and false otherwise.
		 *
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Element/hasAttributes)
		 */
		hasAttributes(): boolean;
		/**
		 * Removes element's first attribute whose qualified name is qualifiedName.
		 *
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Element/removeAttribute)
		 */
		removeAttribute(qualifiedName: string): void;
		/**
		 * Removes element's attribute whose namespace is namespace and local name is localName.
		 *
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Element/removeAttributeNS)
		 */
		removeAttributeNS(namespace: string | null, localName: string): void;
		/** [MDN Reference](https://developer.mozilla.org/docs/Web/API/Element/removeAttributeNode) */
		removeAttributeNode(attr: Attr): Attr;
		/**
		 * Sets the value of element's first attribute whose qualified name is qualifiedName to value.
		 *
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Element/setAttribute)
		 */
		setAttribute(qualifiedName: string, value: string): void;
		/**
		 * Sets the value of element's attribute whose namespace is namespace and local name is
		 * localName to value.
		 *
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Element/setAttributeNS)
		 */
		setAttributeNS(
			namespace: string | null,
			qualifiedName: string,
			value: string
		): void;
		/** [MDN Reference](https://developer.mozilla.org/docs/Web/API/Element/setAttributeNode) */
		setAttributeNode(attr: Attr): Attr | null;
		/** [MDN Reference](https://developer.mozilla.org/docs/Web/API/Element/setAttributeNodeNS) */
		setAttributeNodeNS(attr: Attr): Attr | null;
	}
	/**
	 * Element is the most general base class from which all objects in a Document inherit. It only
	 * has methods and properties common to all kinds of elements. More specific classes inherit from
	 * Element.
	 *
	 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Element)
	 */
	var Element: InstanceOf<Element>;

	/**
	 * The CharacterData abstract interface represents a Node object that contains characters. This
	 * is an abstract interface, meaning there aren't any object of type CharacterData: it is
	 * implemented by other interfaces, like Text, Comment, or ProcessingInstruction which aren't
	 * abstract.
	 *
	 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/CharacterData)
	 */
	interface CharacterData extends Node {
		/** [MDN Reference](https://developer.mozilla.org/docs/Web/API/CharacterData/data) */
		data: string;
		/** [MDN Reference](https://developer.mozilla.org/docs/Web/API/CharacterData/length) */
		readonly length: number;
		readonly ownerDocument: Document;
		/** [MDN Reference](https://developer.mozilla.org/docs/Web/API/CharacterData/appendData) */
		appendData(data: string): void;
		/** [MDN Reference](https://developer.mozilla.org/docs/Web/API/CharacterData/deleteData) */
		deleteData(offset: number, count: number): void;
		/** [MDN Reference](https://developer.mozilla.org/docs/Web/API/CharacterData/insertData) */
		insertData(offset: number, data: string): void;
		/** [MDN Reference](https://developer.mozilla.org/docs/Web/API/CharacterData/replaceData) */
		replaceData(offset: number, count: number, data: string): void;
		/** [MDN Reference](https://developer.mozilla.org/docs/Web/API/CharacterData/substringData) */
		substringData(offset: number, count: number): string;
	}
	/**
	 * The CharacterData abstract interface represents a Node object that contains characters. This
	 * is an abstract interface, meaning there aren't any object of type CharacterData: it is
	 * implemented by other interfaces, like Text, Comment, or ProcessingInstruction which aren't
	 * abstract.
	 *
	 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/CharacterData)
	 */
	var CharacterData: InstanceOf<CharacterData>;

	/**
	 * The textual content of Element or Attr. If an element has no markup within its content, it has
	 * a single child implementing Text that contains the element's text. However, if the element
	 * contains markup, it is parsed into information items and Text nodes that form its children.
	 *
	 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Text)
	 */
	interface Text extends CharacterData {
		nodeName: '#text' | '#cdata-section';
		nodeType: typeof Node.TEXT_NODE | typeof Node.CDATA_SECTION_NODE;
		/**
		 * Splits data at the given offset and returns the remainder as Text node.
		 *
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Text/splitText)
		 */
		splitText(offset: number): Text;
	}

	/**
	 * The textual content of Element or Attr. If an element has no markup within its content, it has
	 * a single child implementing Text that contains the element's text. However, if the element
	 * contains markup, it is parsed into information items and Text nodes that form its children.
	 *
	 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Text)
	 */
	var Text: InstanceOf<Text>;

	/**
	 * The Comment interface represents textual notations within markup; although it is generally not
	 * visually shown, such comments are available to be read in the source view. Comments are
	 * represented in HTML and XML as content between '<!--' and '-->'. In XML, like inside SVG or
	 * MathML markup, the character sequence '--' cannot be used within a comment.
	 *
	 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Comment)
	 */
	interface Comment extends CharacterData {
		nodeName: '#comment';
		nodeType: typeof Node.COMMENT_NODE;
	}
	/**
	 * The Comment interface represents textual notations within markup; although it is generally not
	 * visually shown, such comments are available to be read in the source view. Comments are
	 * represented in HTML and XML as content between '<!--' and '-->'. In XML, like inside SVG or
	 * MathML markup, the character sequence '--' cannot be used within a comment.
	 *
	 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Comment)
	 */
	var Comment: InstanceOf<Comment>;

	/**
	 * A CDATA section that can be used within XML to include extended portions of unescaped text.
	 * The symbols < and & don’t need escaping as they normally do when inside a CDATA section.
	 *
	 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/CDATASection)
	 */
	interface CDATASection extends Text {
		nodeName: '#cdata-section';
		nodeType: typeof Node.CDATA_SECTION_NODE;
	}
	/**
	 * A CDATA section that can be used within XML to include extended portions of unescaped text.
	 * The symbols < and & don’t need escaping as they normally do when inside a CDATA section.
	 *
	 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/CDATASection)
	 */
	var CDATASection: InstanceOf<CDATASection>;

	/**
	 * The DocumentFragment interface represents a minimal document object that has no parent.
	 * It is used as a lightweight version of Document that stores a segment of a document structure
	 * comprised of nodes just like a standard document.
	 * The key difference is due to the fact that the document fragment isn't part
	 * of the active document tree structure.
	 * Changes made to the fragment don't affect the document.
	 */
	interface DocumentFragment extends Node {
		readonly ownerDocument: Document;
		getElementById(elementId: string): Element | null;
	}
	var DocumentFragment: InstanceOf<DocumentFragment>;

	interface Entity extends Node {
		nodeType: typeof Node.ENTITY_NODE;
	}
	var Entity: InstanceOf<Entity>;

	interface EntityReference extends Node {
		nodeType: typeof Node.ENTITY_REFERENCE_NODE;
	}
	var EntityReference: InstanceOf<EntityReference>;

	interface Notation extends Node {
		nodeType: typeof Node.NOTATION_NODE;
	}
	var Notation: InstanceOf<Notation>;

	interface ProcessingInstruction extends CharacterData {
		nodeType: typeof Node.PROCESSING_INSTRUCTION_NODE;
		/**
		 * A string representing the textual data contained in this object.
		 * For `ProcessingInstruction`, that means everything that goes after the `target`, excluding
		 * `?>`.
		 *
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/CharacterData/data)
		 */
		data: string;
		/**
		 * A string containing the name of the application.
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/ProcessingInstruction/target) */
		readonly target: string;
	}
	var ProcessingInstruction: InstanceOf<ProcessingInstruction>;

	interface Document extends Node {
		/**
		 * The mime type of the document is determined at creation time and can not be modified.
		 *
		 * @see https://dom.spec.whatwg.org/#concept-document-content-type
		 * @see {@link DOMImplementation}
		 * @see {@link MIME_TYPE}
		 */
		readonly contentType: MIME_TYPE;
		/**
		 * @see https://dom.spec.whatwg.org/#concept-document-type
		 * @see {@link DOMImplementation}
		 */
		readonly type: 'html' | 'xml';
		/**
		 * The implementation that created this document.
		 *
		 * @readonly
		 */
		readonly implementation: DOMImplementation;
		readonly ownerDocument: Document;
		readonly nodeName: '#document';
		readonly nodeType: typeof Node.DOCUMENT_NODE;
		readonly doctype: DocumentType | null;
		/**
		 * Gets a reference to the root node of the document.
		 *
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Document/documentElement)
		 */
		readonly documentElement: Element | null;

		/**
		 * Creates an attribute object with a specified name.
		 *
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Document/createAttribute)
		 */
		createAttribute(localName: string): Attr;

		/** [MDN Reference](https://developer.mozilla.org/docs/Web/API/Document/createAttributeNS) */
		createAttributeNS(namespace: string | null, qualifiedName: string): Attr;

		/**
		 * Returns a CDATASection node whose data is data.
		 *
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Document/createCDATASection)
		 */
		createCDATASection(data: string): CDATASection;

		/**
		 * Creates a comment object with the specified data.
		 *
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Document/createComment)
		 */
		createComment(data: string): Comment;

		/**
		 * Creates a new document.
		 *
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Document/createDocumentFragment)
		 */
		createDocumentFragment(): DocumentFragment;

		createElement(tagName: string): Element;

		/**
		 * Returns an element with namespace namespace. Its namespace prefix will be everything before
		 * ":" (U+003E) in qualifiedName or null. Its local name will be everything after ":" (U+003E)
		 * in qualifiedName or qualifiedName.
		 *
		 * If localName does not match the Name production an "InvalidCharacterError" DOMException will
		 * be thrown.
		 *
		 * If one of the following conditions is true a "NamespaceError" DOMException will be thrown:
		 *
		 * localName does not match the QName production.
		 * Namespace prefix is not null and namespace is the empty string.
		 * Namespace prefix is "xml" and namespace is not the XML namespace.
		 * qualifiedName or namespace prefix is "xmlns" and namespace is not the XMLNS namespace.
		 * namespace is the XMLNS namespace and neither qualifiedName nor namespace prefix is "xmlns".
		 *
		 * When supplied, options's is can be used to create a customized built-in element.
		 *
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Document/createElementNS)
		 */
		createElementNS(namespace: string | null, qualifiedName: string): Element;
		/**
		 * Creates an EntityReference object.
		 * The current implementation does not fill the `childNodes` with those of the corresponding
		 * `Entity`
		 *
		 * The name of the entity to reference. No namespace well-formedness checks are performed.
		 *
		 * @deprecated
		 * In DOM Level 4.
		 * @returns {EntityReference}
		 * @throws {DOMException}
		 * With code `INVALID_CHARACTER_ERR` when `name` is not valid.
		 * @throws {DOMException}
		 * with code `NOT_SUPPORTED_ERR` when the document is of type `html`
		 * @see https://www.w3.org/TR/DOM-Level-3-Core/core.html#ID-392B75AE
		 */
		createEntityReference(name: string): EntityReference;

		/**
		 * Returns a ProcessingInstruction node whose target is target and data is data. If target does
		 * not match the Name production an "InvalidCharacterError" DOMException will be thrown. If
		 * data contains "?>" an "InvalidCharacterError" DOMException will be thrown.
		 *
		 * [MDN
		 * Reference](https://developer.mozilla.org/docs/Web/API/Document/createProcessingInstruction)
		 */
		createProcessingInstruction(
			target: string,
			data: string
		): ProcessingInstruction;

		/**
		 * Creates a text string from the specified value.
		 *
		 * @param data
		 * String that specifies the nodeValue property of the text node.
		 *
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Document/createTextNode)
		 */
		createTextNode(data: string): Text;

		/**
		 * Returns a reference to the first object with the specified value of the ID attribute.
		 */
		getElementById(elementId: string): Element | null;

		/**
		 * Returns a LiveNodeList of all child elements which have **all** of the given class
		 * name(s).
		 *
		 * Returns an empty list if `classNames` is an empty string or only contains HTML white space
		 * characters.
		 *
		 * Warning: This returns a live LiveNodeList.
		 * Changes in the DOM will reflect in the array as the changes occur.
		 * If an element selected by this array no longer qualifies for the selector,
		 * it will automatically be removed. Be aware of this for iteration purposes.
		 *
		 * @see https://developer.mozilla.org/en-US/docs/Web/API/Document/getElementsByClassName
		 * @see https://dom.spec.whatwg.org/#concept-getelementsbyclassname
		 */
		getElementsByClassName(classNames: string): LiveNodeList<Element>;

		/**
		 * Returns a LiveNodeList of elements with the given qualifiedName.
		 * Searching for all descendants can be done by passing `*` as `qualifiedName`.
		 *
		 * The complete document is searched, including the root node.
		 * The returned list is live, which means it updates itself with the DOM tree automatically.
		 * Therefore, there is no need to call `Element.getElementsByTagName()`
		 * with the same element and arguments repeatedly if the DOM changes in between calls.
		 *
		 * When called on an HTML element in an HTML document,
		 * `getElementsByTagName` lower-cases the argument before searching for it.
		 * This is undesirable when trying to match camel-cased SVG elements (such as
		 * `<linearGradient>`) in an HTML document.
		 * Instead, use `Element.getElementsByTagNameNS()`,
		 * which preserves the capitalization of the tag name.
		 *
		 * `Element.getElementsByTagName` is similar to `Document.getElementsByTagName()`,
		 * except that it only searches for elements that are descendants of the specified element.
		 *
		 * @see https://developer.mozilla.org/en-US/docs/Web/API/Element/getElementsByTagName
		 * @see https://dom.spec.whatwg.org/#concept-getelementsbytagname
		 */
		getElementsByTagName(qualifiedName: string): LiveNodeList<Element>;

		/**
		 * Returns a `LiveNodeList` of elements with the given tag name belonging to the given
		 * namespace. The complete document is searched, including the root node.
		 *
		 * The returned list is live, which means it updates itself with the DOM tree automatically.
		 * Therefore, there is no need to call `Element.getElementsByTagName()`
		 * with the same element and arguments repeatedly if the DOM changes in between calls.
		 *
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Element/getElementsByTagNameNS)
		 * */
		getElementsByTagNameNS(
			namespaceURI: string | null,
			localName: string
		): LiveNodeList<Element>;
		/**
		 * Returns a copy of node. If deep is true, the copy also includes the node's descendants.
		 *
		 * If node is a document or a shadow root, throws a "NotSupportedError" DOMException.
		 *
		 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/Document/importNode)
		 */
		importNode<T extends Node>(node: T, deep?: boolean): T;
	}

	var Document: InstanceOf<Document>;

	/**
	 * A Node containing a doctype.
	 *
	 * [MDN Reference](https://developer.mozilla.org/docs/Web/API/DocumentType)
	 */
	interface DocumentType extends Node {
		/** [MDN Reference](https://developer.mozilla.org/docs/Web/API/DocumentType/name) */
		readonly name: string;
		readonly internalSubset: string;
		/** [MDN Reference](https://developer.mozilla.org/docs/Web/API/DocumentType/publicId) */
		readonly publicId: string;
		/** [MDN Reference](https://developer.mozilla.org/docs/Web/API/DocumentType/systemId) */
		readonly systemId: string;
	}

	var DocumentType: InstanceOf<DocumentFragment>;

	class DOMImplementation {
		/**
		 * The DOMImplementation interface represents an object providing methods which are not
		 * dependent on any particular document.
		 * Such an object is returned by the `Document.implementation` property.
		 *
		 * __The individual methods describe the differences compared to the specs.__.
		 *
		 * @class
		 * @see https://developer.mozilla.org/en-US/docs/Web/API/DOMImplementation MDN
		 * @see https://www.w3.org/TR/REC-DOM-Level-1/level-one-core.html#ID-102161490 DOM Level 1
		 *      Core (Initial)
		 * @see https://www.w3.org/TR/DOM-Level-2-Core/core.html#ID-102161490 DOM Level 2 Core
		 * @see https://www.w3.org/TR/DOM-Level-3-Core/core.html#ID-102161490 DOM Level 3 Core
		 * @see https://dom.spec.whatwg.org/#domimplementation DOM Living Standard
		 */
		constructor();

		/**
		 * Creates an XML Document object of the specified type with its document element.
		 *
		 * __It behaves slightly different from the description in the living standard__:
		 * - There is no interface/class `XMLDocument`, it returns a `Document` instance (with it's
		 * `type` set to `'xml'`).
		 * - `encoding`, `mode`, `origin`, `url` fields are currently not declared.
		 *
		 * @returns {Document}
		 * The XML document.
		 * @see {@link DOMImplementation.createHTMLDocument}
		 * @see https://developer.mozilla.org/en-US/docs/Web/API/DOMImplementation/createDocument MDN
		 * @see https://www.w3.org/TR/DOM-Level-2-Core/core.html#Level-2-Core-DOM-createDocument DOM
		 *      Level 2 Core (initial)
		 * @see https://dom.spec.whatwg.org/#dom-domimplementation-createdocument DOM Level 2 Core
		 */
		createDocument(
			namespaceURI: NAMESPACE | string | null,
			qualifiedName: string,
			doctype?: DocumentType | null
		): Document;

		/**
		 * Returns a doctype, with the given `qualifiedName`, `publicId`, and `systemId`.
		 *
		 * __This behavior is slightly different from the in the specs__:
		 * - `encoding`, `mode`, `origin`, `url` fields are currently not declared.
		 *
		 * @returns {DocumentType}
		 * which can either be used with `DOMImplementation.createDocument`
		 * upon document creation or can be put into the document via methods like
		 * `Node.insertBefore()` or `Node.replaceChild()`
		 * @see https://developer.mozilla.org/en-US/docs/Web/API/DOMImplementation/createDocumentType
		 *      MDN
		 * @see https://www.w3.org/TR/DOM-Level-2-Core/core.html#Level-2-Core-DOM-createDocType DOM
		 *      Level 2 Core
		 * @see https://dom.spec.whatwg.org/#dom-domimplementation-createdocumenttype DOM Living
		 *      Standard
		 */
		createDocumentType(
			qualifiedName: string,
			publicId?: string,
			systemId?: string
		): DocumentType;

		/**
		 * Returns an HTML document, that might already have a basic DOM structure.
		 *
		 * __It behaves slightly different from the description in the living standard__:
		 * - If the first argument is `false` no initial nodes are added (steps 3-7 in the specs are
		 * omitted)
		 * - several properties and methods are missing - Nothing related to events is implemented.
		 *
		 * @see {@link DOMImplementation.createDocument}
		 * @see https://dom.spec.whatwg.org/#dom-domimplementation-createhtmldocument
		 * @see https://dom.spec.whatwg.org/#html-document
		 */
		createHTMLDocument(title?: string | false): Document;

		/**
		 * The DOMImplementation.hasFeature() method returns a Boolean flag indicating if a given
		 * feature is supported. The different implementations fairly diverged in what kind of
		 * features were reported. The latest version of the spec settled to force this method to
		 * always return true, where the functionality was accurate and in use.
		 *
		 * @deprecated
		 * It is deprecated and modern browsers return true in all cases.
		 * @see https://developer.mozilla.org/en-US/docs/Web/API/DOMImplementation/hasFeature MDN
		 * @see https://www.w3.org/TR/REC-DOM-Level-1/level-one-core.html#ID-5CED94D7 DOM Level 1
		 *      Core
		 * @see https://dom.spec.whatwg.org/#dom-domimplementation-hasfeature DOM Living Standard
		 */
		hasFeature(feature: string, version?: string): true;
	}

	class XMLSerializer {
		serializeToString(node: Node, nodeFilter?: (node: Node) => boolean): string;
	}
	// END ./lib/dom.js

	// START ./lib/dom-parser.js
	/**
	 * The DOMParser interface provides the ability to parse XML or HTML source code from a string
	 * into a DOM `Document`.
	 *
	 * _xmldom is different from the spec in that it allows an `options` parameter,
	 * to control the behavior._.
	 *
	 * @see https://developer.mozilla.org/en-US/docs/Web/API/DOMParser
	 * @see https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-parsing-and-serialization
	 */
	class DOMParser {
		/**
		 * The DOMParser interface provides the ability to parse XML or HTML source code from a
		 * string into a DOM `Document`.
		 *
		 * _xmldom is different from the spec in that it allows an `options` parameter,
		 * to control the behavior._.
		 *
		 * @class
		 * @param {DOMParserOptions} [options]
		 * @see https://developer.mozilla.org/en-US/docs/Web/API/DOMParser
		 * @see https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-parsing-and-serialization
		 */
		constructor(options?: DOMParserOptions);

		/**
		 * Parses `source` using the options in the way configured by the `DOMParserOptions` of
		 * `this`
		 * `DOMParser`. If `mimeType` is `text/html` an HTML `Document` is created, otherwise an XML
		 * `Document` is created.
		 *
		 * __It behaves different from the description in the living standard__:
		 * - Uses the `options` passed to the `DOMParser` constructor to modify the behavior.
		 * - Any unexpected input is reported to `onError` with either a `warning`, `error` or
		 * `fatalError` level.
		 * - Any `fatalError` throws a `ParseError` which prevents further processing.
		 * - Any error thrown by `onError` is converted to a `ParseError` which prevents further
		 * processing - If no `Document` was created during parsing it is reported as a `fatalError`.
		 *
		 * @returns
		 * The `Document` node.
		 * @throws {ParseError}
		 * for any `fatalError` or anything that is thrown by `onError`
		 * @throws {TypeError}
		 * for any invalid `mimeType`
		 * @see https://developer.mozilla.org/en-US/docs/Web/API/DOMParser/parseFromString
		 * @see https://html.spec.whatwg.org/#dom-domparser-parsefromstring-dev
		 */
		parseFromString(source: string, mimeType: MIME_TYPE | string): Document;
	}

	interface DOMParserOptions {
		/**
		 * The method to use instead of `Object.assign` (defaults to `conventions.assign`),
		 * which is used to copy values from the options before they are used for parsing.
		 *
		 * @private
		 * @see {@link assign}
		 */
		readonly assign?: typeof Object.assign;
		/**
		 * For internal testing: The class for creating an instance for handling events from the SAX
		 * parser.
		 * *****Warning: By configuring a faulty implementation,
		 * the specified behavior can completely be broken*****.
		 *
		 * @private
		 */
		readonly domHandler?: unknown;

		/**
		 * DEPRECATED: Use `onError` instead!
		 *
		 * For backwards compatibility:
		 * If it is a function, it will be used as a value for `onError`,
		 * but it receives different argument types than before 0.9.0.
		 *
		 * @deprecated
		 * @throws {TypeError}
		 * If it is an object.
		 */
		readonly errorHandler?: ErrorHandlerFunction;

		/**
		 * Configures if the nodes created during parsing
		 * will have a `lineNumber` and a `columnNumber` attribute
		 * describing their location in the XML string.
		 * Default is true.
		 */
		readonly locator?: boolean;

		/**
		 * used to replace line endings before parsing, defaults to exported `normalizeLineEndings`,
		 * which normalizes line endings according to <https://www.w3.org/TR/xml11/#sec-line-ends>,
		 * including some Unicode "newline" characters.
		 *
		 * @see {@link normalizeLineEndings}
		 */
		readonly normalizeLineEndings?: (source: string) => string;
		/**
		 * A function invoked for every error that occurs during parsing.
		 *
		 * If it is not provided, all errors are reported to `console.error`
		 * and only `fatalError`s are thrown as a `ParseError`,
		 * which prevents any further processing.
		 * If the provided method throws, a `ParserError` is thrown,
		 * which prevents any further processing.
		 *
		 * Be aware that many `warning`s are considered an error that prevents further processing in
		 * most implementations.
		 *
		 * @param level
		 * The error level as reported by the SAXParser.
		 * @param message
		 * The error message.
		 * @param context
		 * The DOMHandler instance used for parsing.
		 * @see {@link onErrorStopParsing}
		 * @see {@link onWarningStopParsing}
		 */
		readonly onError?: ErrorHandlerFunction;

		/**
		 * The XML namespaces that should be assumed when parsing.
		 * The default namespace can be provided by the key that is the empty string.
		 * When the `mimeType` for HTML, XHTML or SVG are passed to `parseFromString`,
		 * the default namespace that will be used,
		 * will be overridden according to the specification.
		 */
		readonly xmlns?: Readonly<Record<string, string | null | undefined>>;
	}

	interface ErrorHandlerFunction {
		(
			level: 'warning' | 'error' | 'fatalError',
			msg: string,
			context: any
		): void;
	}

	/**
	 * Normalizes line ending according to <https://www.w3.org/TR/xml11/#sec-line-ends>,
	 * including some Unicode "newline" characters:
	 *
	 * > XML parsed entities are often stored in computer files which,
	 * > for editing convenience, are organized into lines.
	 * > These lines are typically separated by some combination
	 * > of the characters CARRIAGE RETURN (#xD) and LINE FEED (#xA).
	 * >
	 * > To simplify the tasks of applications, the XML processor must behave
	 * > as if it normalized all line breaks in external parsed entities (including the document entity)
	 * > on input, before parsing, by translating the following to a single #xA character:
	 * >
	 * > 1. the two-character sequence #xD #xA,
	 * > 2. the two-character sequence #xD #x85,
	 * > 3. the single character #x85,
	 * > 4. the single character #x2028,
	 * > 5. the single character #x2029,
	 * > 6. any #xD character that is not immediately followed by #xA or #x85.
	 *
	 * @prettierignore
	 */
	function normalizeLineEndings(input: string): string;
	/**
	 * A method that prevents any further parsing when an `error`
	 * with level `error` is reported during parsing.
	 *
	 * @see {@link DOMParserOptions.onError}
	 * @see {@link onWarningStopParsing}
	 */
	function onErrorStopParsing(): void | never;

	/**
	 * A method that prevents any further parsing when an `error`
	 * with any level is reported during parsing.
	 *
	 * @see {@link DOMParserOptions.onError}
	 * @see {@link onErrorStopParsing}
	 */
	function onWarningStopParsing(): never;

	// END ./lib/dom-parser.js
}
