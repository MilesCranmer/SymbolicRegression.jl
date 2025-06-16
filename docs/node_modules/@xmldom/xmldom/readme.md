# @xmldom/xmldom

***Since version 0.7.0 this package is published to npm as [`@xmldom/xmldom`](https://www.npmjs.com/package/@xmldom/xmldom) and no longer as [`xmldom`](https://www.npmjs.com/package/xmldom), because [we are no longer able to publish `xmldom`](https://github.com/xmldom/xmldom/issues/271).***  
*For better readability in the docs, we will continue to talk about this library as "xmldom".*

[![license(MIT)](https://img.shields.io/npm/l/@xmldom/xmldom?color=blue&style=flat-square)](https://github.com/xmldom/xmldom/blob/master/LICENSE)
[![no dependencies](https://img.shields.io/badge/dependencies-0-lightgreen)](https://socket.dev/npm/package/@xmldom/xmldom)
[![codecov](https://codecov.io/gh/xmldom/xmldom/branch/master/graph/badge.svg?token=NisDcchEOV)](https://codecov.io/gh/xmldom/xmldom)
[![install size](https://packagephobia.com/badge?p=@xmldom/xmldom)](https://packagephobia.com/result?p=@xmldom/xmldom)

[![OpenSSF Best Practices](https://www.bestpractices.dev/projects/7879/badge)](https://www.bestpractices.dev/projects/7879)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/xmldom/xmldom/badge)](https://securityscorecards.dev/viewer/?uri=github.com/xmldom/xmldom)
[![Socket Badge](https://socket.dev/api/badge/npm/package/@xmldom/xmldom)](https://socket.dev/npm/package/@xmldom/xmldom)
[![snyk.io package health](https://snyk.io/advisor/npm-package/@xmldom/xmldom/badge.svg)](https://snyk.io/advisor/npm-package/@xmldom/xmldom)

[![npm:latest](https://img.shields.io/npm/v/@xmldom/xmldom/latest?style=flat-square)](https://www.npmjs.com/package/@xmldom/xmldom)
[![npm:next](https://img.shields.io/npm/v/@xmldom/xmldom/next?style=flat-square)](https://www.npmjs.com/package/@xmldom/xmldom?activeTab=versions)
[![npm:lts](https://img.shields.io/npm/v/@xmldom/xmldom/lts?style=flat-square)](https://www.npmjs.com/package/@xmldom/xmldom?activeTab=versions)

[![bug issues](https://img.shields.io/github/issues/xmldom/xmldom/bug?color=red&style=flat-square)](https://github.com/xmldom/xmldom/issues?q=is%3Aissue+is%3Aopen+label%3Abug)
[![help-wanted issues](https://img.shields.io/github/issues/xmldom/xmldom/help-wanted?color=darkgreen&style=flat-square)](https://github.com/xmldom/xmldom/issues?q=is%3Aissue+is%3Aopen+label%3Ahelp-wanted)

xmldom is a javascript [ponyfill](https://ponyfill.com/) to provide the following APIs [that are present in modern browsers](https://caniuse.com/xml-serializer) to other runtimes:
- convert an XML string into a DOM tree
  ```
  new DOMParser().parseFromString(xml, mimeType) => Document
  ```
- create, access and modify a DOM tree
  ```
  new DOMImplementation().createDocument(...) => Document
  ```
- serialize a DOM tree back into an XML string
  ```
  new XMLSerializer().serializeToString(node) => string
  ```

The target runtimes `xmldom` supports are currently Node >= v14.6 (and very likely any other [ES5 compatible runtime](https://compat-table.github.io/compat-table/es5/)).

When deciding how to fix bugs or implement features, `xmldom` tries to stay as close  as possible to the various [related specifications/standards](#specs).  
As indicated by the version starting with `0.`, this implementation is not feature complete and some implemented features differ from what the specifications describe.  
**Issues and PRs for such differences are always welcome, even when they only provide a failing test case.**

This project was forked from it's [original source](https://github.com/jindw/xmldom) in 2019, more details about that transition can be found in the [CHANGELOG](CHANGELOG.md#maintainer-changes).

## Usage

### Install:

``` 
npm install @xmldom/xmldom
```

### Example:

[In NodeJS](examples/nodejs/src/index.js)
```javascript
const { DOMParser, XMLSerializer } = require('@xmldom/xmldom')

const source = `<xml xmlns="a">
	<child>test</child>
	<child/>
</xml>`

const doc = new DOMParser().parseFromString(source, 'text/xml')

const serialized = new XMLSerializer().serializeToString(doc)
```

Note: in Typescript ~~and ES6~~ (see [#316](https://github.com/xmldom/xmldom/issues/316)) you can use the `import` approach, as follows:

```typescript
import { DOMParser } from '@xmldom/xmldom'
```

## API Reference

* [DOMParser](https://developer.mozilla.org/en-US/docs/Web/API/DOMParser):

   ```javascript
   parseFromString(xmlsource, mimeType)
   ```
   * **options extension** _by xmldom_ (not DOM standard!!)

   ```javascript
   // the options argument can be used to modify behavior
   // for more details check the documentation on the code or type definition  
   new DOMParser(options)
   ```

 * [XMLSerializer](https://developer.mozilla.org/en-US/docs/Web/API/XMLSerializer)
 
	```javascript
	serializeToString(node)
	```
### DOM level2 method and attribute:

* [Node](http://www.w3.org/TR/2000/REC-DOM-Level-2-Core-20001113/core.html#ID-1950641247)

  readonly class properties (aka `NodeType`),  
  these can be accessed from any `Node` instance `node`:  
  `if (node.nodeType === node.ELEMENT_NODE) {...`

    1. `ELEMENT_NODE` (`1`)
    2. `ATTRIBUTE_NODE` (`2`)
    3. `TEXT_NODE` (`3`)
    4. `CDATA_SECTION_NODE` (`4`)
    5. `ENTITY_REFERENCE_NODE` (`5`)
    6. `ENTITY_NODE` (`6`)
    7. `PROCESSING_INSTRUCTION_NODE` (`7`)
    8. `COMMENT_NODE` (`8`)
    9. `DOCUMENT_NODE` (`9`)
    10. `DOCUMENT_TYPE_NODE` (`10`)
    11. `DOCUMENT_FRAGMENT_NODE` (`11`)
    12. `NOTATION_NODE` (`12`)

  attribute:
    - `nodeValue` | `prefix` | `textContent`

  readonly attribute:
    - `nodeName` | `nodeType` | `parentNode` | `parentElement` | `childNodes` | `firstChild` | `lastChild` | `previousSibling` | `nextSibling` | `attributes` | `ownerDocument` | `namespaceURI` | `localName` | `isConnected` | `baseURI`

  method:
    * `insertBefore(newChild, refChild)`
    * `replaceChild(newChild, oldChild)`
    * `removeChild(oldChild)`
    * `appendChild(newChild)`
    * `hasChildNodes()`
    * `cloneNode(deep)`
    * `normalize()`
    * `contains(otherNode)`
    * `getRootNode()`
    * `isEqualNode(otherNode)`
    * `isSameNode(otherNode)`
    * `isSupported(feature, version)`
    * `hasAttributes()`
* [DOMException](http://www.w3.org/TR/2000/REC-DOM-Level-2-Core-20001113/ecma-script-binding.html)

  extends the Error type thrown as part of DOM API.

  readonly class properties:
  - `INDEX_SIZE_ERR` (`1`)
  - `DOMSTRING_SIZE_ERR` (`2`)
  - `HIERARCHY_REQUEST_ERR` (`3`)
  - `WRONG_DOCUMENT_ERR` (`4`)
  - `INVALID_CHARACTER_ERR` (`5`)
  - `NO_DATA_ALLOWED_ERR` (`6`)
  - `NO_MODIFICATION_ALLOWED_ERR` (`7`)
  - `NOT_FOUND_ERR` (`8`)
  - `NOT_SUPPORTED_ERR` (`9`)
  - `INUSE_ATTRIBUTE_ERR` (`10`)
  - `INVALID_STATE_ERR` (`11`)
  - `SYNTAX_ERR` (`12`)
  - `INVALID_MODIFICATION_ERR` (`13`)
  - `NAMESPACE_ERR` (`14`)
  - `INVALID_ACCESS_ERR` (`15`)

  attributes:
  -  `code` with a value matching one of the above constants.

* [DOMImplementation](http://www.w3.org/TR/2000/REC-DOM-Level-2-Core-20001113/core.html#ID-102161490)

  method:
  - `hasFeature(feature, version)` (deprecated)
  - `createDocumentType(qualifiedName, publicId, systemId)`
  - `createDocument(namespaceURI, qualifiedName, doctype)`

* [Document](http://www.w3.org/TR/2000/REC-DOM-Level-2-Core-20001113/core.html#i-Document) : Node
		
  readonly attribute:
  - `doctype` | `implementation` | `documentElement`
  
  method:
  - `createElement(tagName)`
  - `createDocumentFragment()`
  - `createTextNode(data)`
  - `createComment(data)`
  - `createCDATASection(data)`
  - `createProcessingInstruction(target, data)`
  - `createAttribute(name)`
  - `createEntityReference(name)`
  - `getElementsByTagName(tagname)`
  - `importNode(importedNode, deep)`
  - `createElementNS(namespaceURI, qualifiedName)`
  - `createAttributeNS(namespaceURI, qualifiedName)`
  - `getElementsByTagNameNS(namespaceURI, localName)`
  - `getElementById(elementId)`

* [DocumentFragment](http://www.w3.org/TR/2000/REC-DOM-Level-2-Core-20001113/core.html#ID-B63ED1A3) : Node
* [Element](http://www.w3.org/TR/2000/REC-DOM-Level-2-Core-20001113/core.html#ID-745549614) : Node

  readonly attribute:
  - `tagName`

  method:
  - `getAttribute(name)`
  - `setAttribute(name, value)`
  - `removeAttribute(name)`
  - `getAttributeNode(name)`
  - `setAttributeNode(newAttr)`
  - `removeAttributeNode(oldAttr)`
  - `getElementsByTagName(name)`
  - `getAttributeNS(namespaceURI, localName)`
  - `setAttributeNS(namespaceURI, qualifiedName, value)`
  - `removeAttributeNS(namespaceURI, localName)`
  - `getAttributeNodeNS(namespaceURI, localName)`
  - `setAttributeNodeNS(newAttr)`
  - `getElementsByTagNameNS(namespaceURI, localName)`
  - `hasAttribute(name)`
  - `hasAttributeNS(namespaceURI, localName)`

* [Attr](http://www.w3.org/TR/2000/REC-DOM-Level-2-Core-20001113/core.html#ID-637646024) : Node

  attribute:
  - `value`

  readonly attribute:
  - `name` | `specified` | `ownerElement`

* [NodeList](http://www.w3.org/TR/2000/REC-DOM-Level-2-Core-20001113/core.html#ID-536297177)
		
  readonly attribute:
  - `length`
  
  method:
  - `item(index)`
	
* [NamedNodeMap](http://www.w3.org/TR/2000/REC-DOM-Level-2-Core-20001113/core.html#ID-1780488922)

  readonly attribute:
  - `length`
  
  method:
  - `getNamedItem(name)`
  - `setNamedItem(arg)`
  - `removeNamedItem(name)`
  - `item(index)`
  - `getNamedItemNS(namespaceURI, localName)`
  - `setNamedItemNS(arg)`
  - `removeNamedItemNS(namespaceURI, localName)`
		
* [CharacterData](http://www.w3.org/TR/2000/REC-DOM-Level-2-Core-20001113/core.html#ID-FF21A306) : Node
	
  method:
  - `substringData(offset, count)`
  - `appendData(arg)`
  - `insertData(offset, arg)`
  - `deleteData(offset, count)`
  - `replaceData(offset, count, arg)`
		
* [Text](http://www.w3.org/TR/2000/REC-DOM-Level-2-Core-20001113/core.html#ID-1312295772) : CharacterData
	 
  method:
  - `splitText(offset)`
			
* [CDATASection](http://www.w3.org/TR/2000/REC-DOM-Level-2-Core-20001113/core.html#ID-667469212)
* [Comment](http://www.w3.org/TR/2000/REC-DOM-Level-2-Core-20001113/core.html#ID-1728279322) : CharacterData
	
* [DocumentType](http://www.w3.org/TR/2000/REC-DOM-Level-2-Core-20001113/core.html#ID-412266927)
	
  readonly attribute:
  - `name` | `entities` | `notations` | `publicId` | `systemId` | `internalSubset`
			
* Notation : Node
	
  readonly attribute:
  - `publicId` | `systemId`
			
* Entity : Node
	
  readonly attribute:
  - `publicId` | `systemId` | `notationName`
			
* EntityReference : Node 
* ProcessingInstruction : Node 

  attribute:
  - `data`
  readonly attribute:
  - `target`
		
### DOM level 3 support:

* [Node](http://www.w3.org/TR/DOM-Level-3-Core/core.html#Node3-textContent)
		
  attribute:
  - `textContent`
  
  method:
  - `isDefaultNamespace(namespaceURI)`
  - `lookupNamespaceURI(prefix)`

### DOM extension by xmldom

* [Node] Source position extension; 
		
  attribute:
  - `lineNumber` //number starting from `1`
  - `columnNumber` //number starting from `1`

## Specs

The implementation is based on several specifications:

<!-- Should open in new tab and the links in the SVG should be clickable there! -->
<a href="https://raw.githubusercontent.com/xmldom/xmldom/master/docs/specs.svg" target="_blank" rel="noopener noreferrer nofollow" >![Overview of related specifications and their relations](docs/specs.svg)</a>

### DOM Parsing and Serialization

From the [W3C DOM Parsing and Serialization (WD 2016)](https://www.w3.org/TR/2016/WD-DOM-Parsing-20160517/) `xmldom` provides an implementation for the interfaces:
- `DOMParser`
- `XMLSerializer`

Note that there are some known deviations between this implementation and the W3 specifications.

Note: [The latest version of this spec](https://w3c.github.io/DOM-Parsing/) has the status "Editors Draft", since it is under active development. One major change is that [the definition of the `DOMParser` interface has been moved to the HTML spec](https://w3c.github.io/DOM-Parsing/#the-domparser-interface)


### DOM

The original author claims that xmldom implements [DOM Level 2] in a "fully compatible" way and some parts of [DOM Level 3], but there are not enough tests to prove this. Both Specifications are now superseded by the [DOM Level 4 aka Living standard] wich has a much broader scope than xmldom.
In the past, there have been multiple (even breaking) changes to align xmldom with the living standard,
so if you find a difference that is not documented, any contribution to resolve the difference is very welcome (even just reporting it as an issue). 

xmldom implements the following interfaces:
- `Attr`
- `CDATASection`
- `CharacterData`
- `Comment`
- `Document`
- `DocumentFragment`
- `DocumentType`
- `DOMException` 
- `DOMImplementation`
- `Element`
- `Entity`
- `EntityReference`
- `LiveNodeList`
- `NamedNodeMap`
- `Node`
- `NodeList`
- `Notation`
- `ProcessingInstruction`
- `Text`

more details are available in the (incomplete) [API Reference](#api-reference) section.

### HTML

xmldom does not have any goal of supporting the full spec, but it has some capability to parse, report and serialize things differently when it is told to parse HTML (by passing the HTML namespace).

### SAX, XML, XMLNS

xmldom has an own SAX parser implementation to do the actual parsing, which implements some interfaces in alignment with the Java interfaces SAX defines:
- `XMLReader`
- `DOMHandler`

There is an idea/proposal to make it possible to replace it with something else in <https://github.com/xmldom/xmldom/issues/55>
