# Changelog

All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.8](https://github.com/xmldom/xmldom/compare/0.9.8...0.9.7)

### Fixed

- fix: replace \u2029 as part of normalizeLineEndings [`#839`](https://github.com/xmldom/xmldom/pull/839) / [`#838`](https://github.com/xmldom/xmldom/issues/838)
- perf: speed up line detection [`#847`](https://github.com/xmldom/xmldom/pull/847) / [`#838`](https://github.com/xmldom/xmldom/issues/838)

### Chore

- updated dependencies
- drop jazzer and rxjs devDependencies [`#845`](https://github.com/xmldom/xmldom/pull/845)

Thank you,
[@kboshold](https://github.com/kboshold),
[@Ponynjaa](https://github.com/Ponynjaa),
for your contributions.


## [0.9.7](https://github.com/xmldom/xmldom/compare/0.9.6...0.9.7)

### Added

- Implementation of `hasAttributes` [`#804`](https://github.com/xmldom/xmldom/pull/804)

### Fixed

- locator is now true even when other options are being used for the DOMParser [`#802`](https://github.com/xmldom/xmldom/issues/802) / [`#803`](https://github.com/xmldom/xmldom/pull/803)
- allow case-insensitive DOCTYPE in HTML [`#817`](https://github.com/xmldom/xmldom/issues/817) / [`#819`](https://github.com/xmldom/xmldom/pull/819)

### Performance

- simplify `DOM.compareDocumentPosition` [`#805`](https://github.com/xmldom/xmldom/pull/805)

### Chore

- updated devDependencies

Thank you,
[@zorkow](https://github.com/zorkow),
[@Ponynjaa](https://github.com/Ponynjaa),
[@WesselKroos](https://github.com/WesselKroos),
for your contributions.


## [0.9.6](https://github.com/xmldom/xmldom/compare/0.9.5...0.9.6)

### Fixed

- lower error level for unicode replacement character [`#790`](https://github.com/xmldom/xmldom/issues/790) / [`#794`](https://github.com/xmldom/xmldom/pull/794) / [`#797`](https://github.com/xmldom/xmldom/pull/797)

### Chore

- updated devDependencies
- migrate renovate config [`#792`](https://github.com/xmldom/xmldom/pull/792)

Thank you, [@eglitise](https://github.com/eglitise), for your contributions.


## [0.9.5](https://github.com/xmldom/xmldom/compare/0.9.4...0.9.5)

### Fixed

- fix: re-index childNodes on insertBefore [`#763`](https://github.com/xmldom/xmldom/issues/763) / [`#766`](https://github.com/xmldom/xmldom/pull/766)

Thank you,
[@mureinik](https://github.com/mureinik),
for your contributions.


## [0.9.4](https://github.com/xmldom/xmldom/compare/0.9.3...0.9.4)

### Fixed

- restore performance for large amount of child nodes [`#748`](https://github.com/xmldom/xmldom/issues/748) /  [`#760`](https://github.com/xmldom/xmldom/pull/760)
- types: correct error handler level to `warning` (#759) [`#754`](https://github.com/xmldom/xmldom/issues/754) / [`#759`](https://github.com/xmldom/xmldom/pull/759)

### Docs

- test: verify BOM handling [`#758`](https://github.com/xmldom/xmldom/pull/758)

Thank you,
[@luffynando](https://github.com/luffynando),
[@mattiasw](https://github.com/mattiasw),
[@JoinerDev](https://github.com/JoinerDev),
for your contributions.


## [0.9.3](https://github.com/xmldom/xmldom/compare/0.9.2...0.9.3)

### Fixed

- restore more `Node` and `ProcessingInstruction` types [`#725`](https://github.com/xmldom/xmldom/issues/725) / [`#726`](https://github.com/xmldom/xmldom/pull/726)
- `getElements*` methods return `LiveNodeList&lt;Element&gt;` [`#731`](https://github.com/xmldom/xmldom/issues/731) / [`#734`](https://github.com/xmldom/xmldom/pull/734)
- Add more missing `Node` props [`#728`](https://github.com/xmldom/xmldom/pull/728), triggered by unclosed [`#724`](https://github.com/xmldom/xmldom/pull/724)

### Docs

- Update supported runtimes in readme (NodeJS >= 14.6 and other [ES5 compatible runtimes](https://compat-table.github.io/compat-table/es5/))

### Chore

- updates devDependencies

Thank you,
[@Ponynjaa](https://github.com/Ponynjaa),
[@ayZagen](https://github.com/ayZagen),
[@sserdyuk](https://github.com/sserdyuk),
[@wydengyre](https://github.com/wydengyre),
[@mykola-mokhnach](https://github.com/mykola-mokhnach),
[@benkroeger](https://github.com/benkroeger),
for your contributions.

# Changelog

All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.2](https://github.com/xmldom/xmldom/compare/0.9.1...0.9.2)

### Feature

- add `Element.getElementsByClassName` [`#722`](https://github.com/xmldom/xmldom/pull/722)

### Fixed

- add missing types for `Document.documentElement` and `Element.tagName` [`#721`](https://github.com/xmldom/xmldom/pull/721) [`#720`](https://github.com/xmldom/xmldom/issues/720)

Thank you, [@censujiang](https://github.com/censujiang), [@Mathias-S](https://github.com/Mathias-S), for your contributions


## [0.9.1](https://github.com/xmldom/xmldom/compare/0.9.0...0.9.1)

### Fixed

- DOMParser.parseFromString requires mimeType as second argument [`#713`](https://github.com/xmldom/xmldom/pull/713)
- correct spelling of `isHTMLMimeType` in type definition [`#715`](https://github.com/xmldom/xmldom/pull/715) / [`#712`](https://github.com/xmldom/xmldom/issues/712)
- sync types with exports [`#717`](https://github.com/xmldom/xmldom/pull/717) / [`#285`](https://github.com/xmldom/xmldom/issues/285) / [`#695`](https://github.com/xmldom/xmldom/issues/695)

### Other

- minimum tested node version is 14 [`#710`](https://github.com/xmldom/xmldom/pull/710)

Thank you, [@krystofwoldrich](https://github.com/krystofwoldrich), [@marvinruder](https://github.com/marvinruder), [@amacneil](https://github.com/amacneil), [@defunctzombie](https://github.com/defunctzombie), 
[@tjhorner](https://github.com/tjhorner), [@danon](https://github.com/danon), for your contributions


## [0.9.0](https://github.com/xmldom/xmldom/compare/0.9.0-beta.11...0.9.0)

- [Discussion](https://github.com/xmldom/xmldom/discussions/435)
- [Summary on dev.to](https://dev.to/karfau/release-090-of-xmldomxmldom-4106)

### Features

- feat: expose all DOM level 2 element prototypes [`#637`](https://github.com/xmldom/xmldom/pull/637) / [`#40`](https://github.com/xmldom/xmldom/issues/40)
- feat: add iterator function to NodeList and NamedNodeMap [`#634`](https://github.com/xmldom/xmldom/pull/634) / [`#633`](https://github.com/xmldom/xmldom/issues/633)

### Fixed

- parse empty/whitspace only doctype internal subset [`#692`](https://github.com/xmldom/xmldom/pull/692)
- avoid prototype clash in namespace prefix [`#554`](https://github.com/xmldom/xmldom/pull/554)
- report fatalError when doctype is inside elements [`#550`](https://github.com/xmldom/xmldom/pull/550)

### Other

- test: add fuzz target and regression tests [`#556`](https://github.com/xmldom/xmldom/pull/556)
- chore: improve .gitignore and provide .envrc.template [`#697`](https://github.com/xmldom/xmldom/pull/697)
- chore: Apply security best practices [`#546`](https://github.com/xmldom/xmldom/pull/546)
- ci: check test coverage in PRs [`#524`](https://github.com/xmldom/xmldom/pull/524)
- docs: add missing commas to readme [`#566`](https://github.com/xmldom/xmldom/pull/566)
- docs: click to copy install command in readme [`#644`](https://github.com/xmldom/xmldom/pull/644)
- docs: enhance jsdoc comments [`#511`](https://github.com/xmldom/xmldom/pull/511)

Thank you, [@kboshold](https://github.com/kboshold), [@edi9999](https://github.com/edi9999), [@apupier](https://github.com/apupier), 
[@shunkica](https://github.com/shunkica), [@homer0](https://github.com/homer0), [@jhauga](https://github.com/jhauga), 
[@UdayKharatmol](https://github.com/UdayKharatmol), for your contributions


## [0.9.0-beta.11](https://github.com/xmldom/xmldom/compare/0.9.0-beta.10...0.9.0-beta.11)

### Fixed

- report more non well-formed cases [`#519`](https://github.com/xmldom/xmldom/pull/519)  / [`#45`](https://github.com/xmldom/xmldom/issues/45) / [`#125`](https://github.com/xmldom/xmldom/issues/125) / [`#467`](https://github.com/xmldom/xmldom/issues/467)
  BREAKING-CHANGE: Reports more not well-formed documents as fatalError
  and drop broken support for optional and unclosed tags in HTML.

### Other

- Translate/drop non English comments [`#518`](https://github.com/xmldom/xmldom/pull/518)
- use node v16 for development [`#517`](https://github.com/xmldom/xmldom/pull/517)

Thank you, [@brodybits](https://github.com/brodybits), [@cbettinger](https://github.com/cbettinger), [@josecarlosrx](https://github.com/josecarlosrx), for your contributions


## [0.9.0-beta.10](https://github.com/xmldom/xmldom/compare/0.9.0-beta.9...0.9.0-beta.10)

### Fixed

- dom: prevent iteration over deleted items [`#514`](https://github.com/xmldom/xmldom/pull/514)/ [`#499`](https://github.com/xmldom/xmldom/issues/499)

### Chore

- use prettier plugin for jsdoc [`#513`](https://github.com/xmldom/xmldom/pull/513)

Thank you, [@qtow](https://github.com/qtow), [@shunkica](https://github.com/shunkica), [@homer0](https://github.com/homer0), for your contributions


## [0.8.10](https://github.com/xmldom/xmldom/compare/0.8.9...0.8.10)

### Fixed

- dom: prevent iteration over deleted items [`#514`](https://github.com/xmldom/xmldom/pull/514)/ [`#499`](https://github.com/xmldom/xmldom/issues/499)

Thank you, [@qtow](https://github.com/qtow), for your contributions


## [0.7.13](https://github.com/xmldom/xmldom/compare/0.7.12...0.7.13)

### Fixed

- dom: prevent iteration over deleted items [`#514`](https://github.com/xmldom/xmldom/pull/514)/ [`#499`](https://github.com/xmldom/xmldom/issues/499)

Thank you, [@qtow](https://github.com/qtow), for your contributions


## [0.9.0-beta.9](https://github.com/xmldom/xmldom/compare/0.9.0-beta.8...0.9.0-beta.9)

### Fixed

- Set nodeName property in ProcessingInstruction [`#509`](https://github.com/xmldom/xmldom/pull/509) / [`#505`](https://github.com/xmldom/xmldom/issues/505)
- preserve DOCTYPE internal subset [`#498`](https://github.com/xmldom/xmldom/pull/498) / [`#497`](https://github.com/xmldom/xmldom/pull/497) / [`#117`](https://github.com/xmldom/xmldom/issues/117)\
  BREAKING CHANGES: Many documents that were previously accepted by xmldom, esecially non well-formed ones are no longer accepted. Some issues that were formerly reported as errors are now a fatalError.
- DOMParser: Align parseFromString errors with specs [`#454`](https://github.com/xmldom/xmldom/pull/454)

### Chore

- stop running mutation tests using stryker [`#496`](https://github.com/xmldom/xmldom/pull/496)
- make `toErrorSnapshot` windows compatible [`#503`](https://github.com/xmldom/xmldom/pull/503)

Thank you, [@cjbarth](https://github.com/cjbarth), [@shunkica](https://github.com/shunkica), [@pmahend1](https://github.com/pmahend1), [@niklasl](https://github.com/niklasl), for your contributions


## [0.8.9](https://github.com/xmldom/xmldom/compare/0.8.8...0.8.9)

### Fixed

- Set nodeName property in ProcessingInstruction [`#509`](https://github.com/xmldom/xmldom/pull/509) / [`#505`](https://github.com/xmldom/xmldom/issues/505)

Thank you, [@cjbarth](https://github.com/cjbarth), for your contributions


## [0.7.12](https://github.com/xmldom/xmldom/compare/0.7.11...0.7.12)

### Fixed

- Set nodeName property in ProcessingInstruction [`#509`](https://github.com/xmldom/xmldom/pull/509) / [`#505`](https://github.com/xmldom/xmldom/issues/505)

Thank you, [@cjbarth](https://github.com/cjbarth), for your contributions


## [0.9.0-beta.8](https://github.com/xmldom/xmldom/compare/0.9.0-beta.7...0.9.0-beta.8)

### Fixed

- Throw DOMException when calling removeChild with invalid parameter [`#494`](https://github.com/xmldom/xmldom/pull/494) / [`#135`](https://github.com/xmldom/xmldom/issues/135)

BREAKING CHANGE: Previously it was possible (but not documented) to call `Node.removeChild` with any node in the tree,
and with certain exceptions, it would work. This is no longer the case: calling `Node.removeChild` with an argument that is not a direct child of the node that it is called from, will throw a NotFoundError DOMException, as it is described by the specs.

Thank you, [@noseworthy](https://github.com/noseworthy), [@davidmc24](https://github.com/davidmc24), for your contributions


## [0.9.0-beta.7](https://github.com/xmldom/xmldom/compare/0.9.0-beta.6...0.9.0-beta.7)

### Feature

- Add `compareDocumentPosition` method from level 3 spec. [`#488`](https://github.com/xmldom/xmldom/pull/488)

### Fixed

- `getAttribute` and `getAttributeNS` should return `null` (#477) [`#46`](https://github.com/xmldom/xmldom/issues/46)
- several issues in NamedNodeMap and Element (#482) [`#46`](https://github.com/xmldom/xmldom/issues/46)
- properly parse closing where the last attribute has no value [`#485`](https://github.com/xmldom/xmldom/pull/485) / [`#486`](https://github.com/xmldom/xmldom/issues/486)
- extend list of HTML entities [`#489`](https://github.com/xmldom/xmldom/pull/489)

BREAKING CHANGE: Iteration over attributes now happens in the right order and non-existing attributes now return `null` instead of undefined. THe same is true for the `namepsaceURI` and `prefix` of Attr nodes.
All of the changes are fixing misalignment with the DOM specs, so if you expected it to work as specified,
nothing should break for you.

### Chore

- update multiple devDependencies
- Configure jest (correctly) and wallaby [`#481`](https://github.com/xmldom/xmldom/pull/481) / [`#483`](https://github.com/xmldom/xmldom/pull/483)

Thank you, [@bulandent](https://github.com/bulandent), [@zorkow](https://github.com/zorkow), for your contributions


## [0.8.8](https://github.com/xmldom/xmldom/compare/0.8.7...0.8.8)

### Fixed

- extend list of HTML entities [`#489`](https://github.com/xmldom/xmldom/pull/489)

Thank you, [@zorkow](https://github.com/zorkow), for your contributions

## [0.7.11](https://github.com/xmldom/xmldom/compare/0.7.10...0.7.11)

### Fixed

- extend list of HTML entities [`#489`](https://github.com/xmldom/xmldom/pull/489)

Thank you, [@zorkow](https://github.com/zorkow), for your contributions


## [0.8.7](https://github.com/xmldom/xmldom/compare/0.8.6...0.8.7)

### Fixed

- properly parse closing where the last attribute has no value [`#485`](https://github.com/xmldom/xmldom/pull/485) / [`#486`](https://github.com/xmldom/xmldom/issues/486)

Thank you, [@bulandent](https://github.com/bulandent), for your contributions


## [0.7.10](https://github.com/xmldom/xmldom/compare/0.7.9...0.7.10)

### Fixed

- properly parse closing where the last attribute has no value [`#485`](https://github.com/xmldom/xmldom/pull/485) / [`#486`](https://github.com/xmldom/xmldom/issues/486)

Thank you, [@bulandent](https://github.com/bulandent), for your contributions


## [0.8.6](https://github.com/xmldom/xmldom/compare/0.8.5...0.8.6)

### Fixed

- Properly check nodes before replacement [`#457`](https://github.com/xmldom/xmldom/pull/457) / [`#455`](https://github.com/xmldom/xmldom/issues/455) / [`#456`](https://github.com/xmldom/xmldom/issues/456)

Thank you, [@edemaine](https://github.com/edemaine), [@pedro-l9](https://github.com/pedro-l9), for your contributions


## [0.7.9](https://github.com/xmldom/xmldom/compare/0.7.8...0.7.9)

### Fixed

- Properly check nodes before replacement [`#457`](https://github.com/xmldom/xmldom/pull/457) / [`#455`](https://github.com/xmldom/xmldom/issues/455) / [`#456`](https://github.com/xmldom/xmldom/issues/456)

Thank you, [@edemaine](https://github.com/edemaine), [@pedro-l9](https://github.com/pedro-l9), for your contributions


## [0.9.0-beta.6](https://github.com/xmldom/xmldom/compare/0.9.0-beta.5...0.9.0-beta.6)

### Fixed

- Properly check nodes before replacement [`#457`](https://github.com/xmldom/xmldom/pull/457) / [`#455`](https://github.com/xmldom/xmldom/issues/455) / [`#456`](https://github.com/xmldom/xmldom/issues/456)

Thank you, [@edemaine](https://github.com/edemaine), [@pedro-l9](https://github.com/pedro-l9), for your contributions


## [0.9.0-beta.5](https://github.com/xmldom/xmldom/compare/0.9.0-beta.4...0.9.0-beta.5)

### Fixed

- fix: Restore ES5 compatibility [`#452`](https://github.com/xmldom/xmldom/pull/452) / [`#453`](https://github.com/xmldom/xmldom/issues/453)

Thank you, [@fengxinming](https://github.com/fengxinming), for your contributions


## [0.8.5](https://github.com/xmldom/xmldom/compare/0.8.4...0.8.5)

### Fixed

- fix: Restore ES5 compatibility [`#452`](https://github.com/xmldom/xmldom/pull/452) / [`#453`](https://github.com/xmldom/xmldom/issues/453)

Thank you, [@fengxinming](https://github.com/fengxinming), for your contributions


## [0.7.8](https://github.com/xmldom/xmldom/compare/0.7.7...0.7.8)

### Fixed

- fix: Restore ES5 compatibility [`#452`](https://github.com/xmldom/xmldom/pull/452) / [`#453`](https://github.com/xmldom/xmldom/issues/453)

Thank you, [@fengxinming](https://github.com/fengxinming), for your contributions


## [0.9.0-beta.4](https://github.com/xmldom/xmldom/compare/0.9.0-beta.3...0.9.0-beta.4)

### Fixed

- Security: Prevent inserting DOM nodes when they are not well-formed [`CVE-2022-39353`](https://github.com/xmldom/xmldom/security/advisories/GHSA-crh6-fp67-6883)
  In case such a DOM would be created, the part that is not well-formed will be transformed into text nodes, in which xml specific characters like `<` and `>` are encoded accordingly.
  In the upcoming version 0.9.0 those text nodes will no longer be added and an error will be thrown instead.
  This change can break your code, if you relied on this behavior, e.g. multiple root elements in the past. We consider it more important to align with the specs that we want to be aligned with, considering the potential security issues that might derive from people not being aware of the difference in behavior.
  Related Spec: <https://dom.spec.whatwg.org/#concept-node-ensure-pre-insertion-validity>

### Chore

- update multiple devDependencies
- Add eslint-plugin-node for `lib` [`#448`](https://github.com/xmldom/xmldom/pull/448) / [`#190`](https://github.com/xmldom/xmldom/issues/190)
- style: Apply prettier to all code [`#447`](https://github.com/xmldom/xmldom/pull/447) / [`#29`](https://github.com/xmldom/xmldom/issues/29) / [`#130`](https://github.com/xmldom/xmldom/issues/130)

Thank you, [@XhmikosR](https://github.com/XhmikosR), [@awwright](https://github.com/awwright), [@frumioj](https://github.com/frumioj), [@cjbarth](https://github.com/cjbarth), [@markgollnick](https://github.com/markgollnick) for your contributions


## [0.8.4](https://github.com/xmldom/xmldom/compare/0.8.3...0.8.4)

### Fixed

- Security: Prevent inserting DOM nodes when they are not well-formed [`CVE-2022-39353`](https://github.com/xmldom/xmldom/security/advisories/GHSA-crh6-fp67-6883)
  In case such a DOM would be created, the part that is not well-formed will be transformed into text nodes, in which xml specific characters like `<` and `>` are encoded accordingly.
  In the upcoming version 0.9.0 those text nodes will no longer be added and an error will be thrown instead.
  This change can break your code, if you relied on this behavior, e.g. multiple root elements in the past. We consider it more important to align with the specs that we want to be aligned with, considering the potential security issues that might derive from people not being aware of the difference in behavior.
  Related Spec: <https://dom.spec.whatwg.org/#concept-node-ensure-pre-insertion-validity>

Thank you, [@frumioj](https://github.com/frumioj), [@cjbarth](https://github.com/cjbarth), [@markgollnick](https://github.com/markgollnick) for your contributions


## [0.7.7](https://github.com/xmldom/xmldom/compare/0.7.6...0.7.7)

### Fixed

- Security: Prevent inserting DOM nodes when they are not well-formed [`CVE-2022-39353`](https://github.com/xmldom/xmldom/security/advisories/GHSA-crh6-fp67-6883)
  In case such a DOM would be created, the part that is not well-formed will be transformed into text nodes, in which xml specific characters like `<` and `>` are encoded accordingly.
  In the upcoming version 0.9.0 those text nodes will no longer be added and an error will be thrown instead.
  This change can break your code, if you relied on this behavior, e.g. multiple root elements in the past. We consider it more important to align with the specs that we want to be aligned with, considering the potential security issues that might derive from people not being aware of the difference in behavior.
  Related Spec: <https://dom.spec.whatwg.org/#concept-node-ensure-pre-insertion-validity>

Thank you, [@frumioj](https://github.com/frumioj), [@cjbarth](https://github.com/cjbarth), [@markgollnick](https://github.com/markgollnick) for your contributions


## [0.9.0-beta.3](https://github.com/xmldom/xmldom/compare/0.9.0-beta.2...0.9.0-beta.3)

### Fixed

- fix: Stop adding tags after incomplete closing tag [`#445`](https://github.com/xmldom/xmldom/pull/445) / [`#416`](https://github.com/xmldom/xmldom/pull/416)
  BREAKING CHANGE: It no longer reports an error when parsing HTML containing incomplete closing tags, to align the behavior with the one in the browser.
  BREAKING CHANGE: If your code relied on not well-formed XML to be parsed and include subsequent tags, this will no longer work.
- fix: Avoid bidirectional characters in source code [`#440`](https://github.com/xmldom/xmldom/pull/440)

### Other

- ci: Add CodeQL scan [`#444`](https://github.com/xmldom/xmldom/pull/444)

Thank you, [@ACN-kck](https://github.com/ACN-kck), [@mgerlach](https://github.com/mgerlach) for your contributions


## [0.7.6](https://github.com/xmldom/xmldom/compare/0.7.5...0.7.6)

### Fixed
- Avoid iterating over prototype properties [`#441`](https://github.com/xmldom/xmldom/pull/441) / [`#437`](https://github.com/xmldom/xmldom/pull/437) / [`#436`](https://github.com/xmldom/xmldom/issues/436)

Thank you, [@jftanner](https://github.com/jftanner), [@Supraja9726](https://github.com/Supraja9726) for your contributions


## [0.8.3](https://github.com/xmldom/xmldom/compare/0.8.3...0.8.2)

### Fixed
- Avoid iterating over prototype properties [`#437`](https://github.com/xmldom/xmldom/pull/437) / [`#436`](https://github.com/xmldom/xmldom/issues/436)

Thank you, [@Supraja9726](https://github.com/Supraja9726) for your contributions


## [0.9.0-beta.2](https://github.com/xmldom/xmldom/compare/0.9.0-beta.1...0.9.0-beta.2)

### Fixed
- Avoid iterating over prototype properties [`#437`](https://github.com/xmldom/xmldom/pull/437) / [`#436`](https://github.com/xmldom/xmldom/issues/436)

Thank you, [@Supraja9726](https://github.com/Supraja9726) for your contributions


## [0.9.0-beta.1](https://github.com/xmldom/xmldom/compare/0.8.2...0.9.0-beta.1)

### Fixed

**Only use HTML rules if mimeType matches** [`#338`](https://github.com/xmldom/xmldom/pull/338), fixes [`#203`](https://github.com/xmldom/xmldom/issues/203)

In the living specs for parsing XML and HTML, that this library is trying to implement,
there is a distinction between the different types of documents being parsed:
There are quite some rules that are different for parsing, constructing and serializing XML vs HTML documents.

So far xmldom was always "detecting" whether "the HTML rules should be applied" by looking at the current namespace. So from the first time an the HTML default namespace (`http://www.w3.org/1999/xhtml`) was found, every node was treated as being part of an HTML document. This misconception is the root cause for quite some reported bugs.

BREAKING CHANGE: HTML rules are no longer applied just because of the namespace, but require the `mimeType` argument passed to `DOMParser.parseFromString(source, mimeType)` to match `'text/html'`. Doing so implies all rules for handling casing for tag and attribute names when parsing, creation of nodes and searching nodes.

BREAKING CHANGE: Correct the return type of `DOMParser.parseFromString` to `Document | undefined`. In case of parsing errors it was always possible that "the returned `Document`" has not been created. In case you are using Typescript you now need to handle those cases.

BREAKING CHANGE: The instance property `DOMParser.options` is no longer available, instead use the individual `readonly` property per option (`assign`, `domHandler`, `errorHandler`, `normalizeLineEndings`, `locator`, `xmlns`). Those also provides the default value if the option was not passed. The 'locator' option is now just a boolean (default remains `true`).

BREAKING CHANGE: The following methods no longer allow a (non spec compliant) boolean argument to toggle "HTML rules":
- `XMLSerializer.serializeToString`
- `Node.toString`
- `Document.toString`

The following interfaces have been implemented:
`DOMImplementation` now implements all methods defined in the DOM spec, but not all of the behavior is implemented (see docstring):
- `createDocument` creates an "XML Document" (prototype: `Document`, property `type` is `'xml'`)
- `createHTMLDocument` creates an "HTML Document" (type/prototype: `Document`, property `type` is `'html'`).
  - when no argument is passed or the first argument is a string, the basic nodes for an HTML structure are created, as specified
  - when the first argument is `false` no child nodes are created

`Document` now has two new readonly properties as specified in the DOM spec:
- `contentType` which is the mime-type that was used to create the document
- `type` which is either the string literal `'xml'` or `'html'`

`MIME_TYPE` (`/lib/conventions.js`):
- `hasDefaultHTMLNamespace` test if the provided string is one of the miem types that implies the default HTML namespace: `text/html` or `application/xhtml+xml`

Thank you [@weiwu-zhang](https://github.com/weiwu-zhang) for your contributions

### Chore

- update multiple devDependencies


## [0.8.2](https://github.com/xmldom/xmldom/compare/0.8.1...0.8.2)

### Fixed
- fix(dom): Serialize `&gt;` as specified (#395) [`#58`](https://github.com/xmldom/xmldom/issues/58)

### Other
- docs: Add `nodeType` values to public interface description [`#396`](https://github.com/xmldom/xmldom/pull/396)
- test: Add executable examples for node and typescript [`#317`](https://github.com/xmldom/xmldom/pull/317)
- fix(dom): Serialize `&gt;` as specified [`#395`](https://github.com/xmldom/xmldom/pull/395)
- chore: Add minimal `Object.assign` ponyfill [`#379`](https://github.com/xmldom/xmldom/pull/379)
- docs: Refine release documentation [`#378`](https://github.com/xmldom/xmldom/pull/378)
- chore: update various dev dependencies

Thank you [@niklasl](https://github.com/niklasl), [@cburatto](https://github.com/cburatto), [@SheetJSDev](https://github.com/SheetJSDev), [@pyrsmk](https://github.com/pyrsmk) for your contributions

## [0.8.1](https://github.com/xmldom/xmldom/compare/0.8.0...0.8.1)

### Fixes
- Only use own properties in entityMap [`#374`](https://github.com/xmldom/xmldom/pull/374)

### Docs
- Add security policy [`#365`](https://github.com/xmldom/xmldom/pull/365)
- changelog: Correct contributor name and link [`#366`](https://github.com/xmldom/xmldom/pull/366)
- Describe release/publish steps [`#358`](https://github.com/xmldom/xmldom/pull/358), [`#376`](https://github.com/xmldom/xmldom/pull/376)
- Add snyk package health badge [`#360`](https://github.com/xmldom/xmldom/pull/360)


## [0.8.0](https://github.com/xmldom/xmldom/compare/0.7.5...0.8.0)

### Fixed
- Normalize all line endings according to XML specs [1.0](https://w3.org/TR/xml/#sec-line-ends) and [1.1](https://www.w3.org/TR/xml11/#sec-line-ends) \
  BREAKING CHANGE: Certain combination of line break characters are normalized to a single `\n` before parsing takes place and will no longer be preserved.
  - [`#303`](https://github.com/xmldom/xmldom/issues/303) / [`#307`](https://github.com/xmldom/xmldom/pull/307)
  - [`#49`](https://github.com/xmldom/xmldom/issues/49), [`#97`](https://github.com/xmldom/xmldom/issues/97), [`#324`](https://github.com/xmldom/xmldom/issues/324) / [`#314`](https://github.com/xmldom/xmldom/pull/314)
- XMLSerializer: Preserve whitespace character references [`#284`](https://github.com/xmldom/xmldom/issues/284) / [`#310`](https://github.com/xmldom/xmldom/pull/310) \
  BREAKING CHANGE: If you relied on the not spec compliant preservation of literal `\t`, `\n` or `\r` in **attribute values**.
  To preserve those you will have to create XML that instead contains the correct numerical (or hexadecimal) equivalent (e.g. `&#x9;`, `&#xA;`, `&#xD;`).
- Drop deprecated exports `DOMImplementation` and `XMLSerializer` from `lib/dom-parser.js` [#53](https://github.com/xmldom/xmldom/issues/53) / [`#309`](https://github.com/xmldom/xmldom/pull/309)
  BREAKING CHANGE: Use the one provided by the main package export.
- dom: Remove all links as part of `removeChild` [`#343`](https://github.com/xmldom/xmldom/issues/343) / [`#355`](https://github.com/xmldom/xmldom/pull/355)

### Chore
- ci: Restore latest tested node version to 16.x [`#325`](https://github.com/xmldom/xmldom/pull/325)
- ci: Split test and lint steps into jobs [`#111`](https://github.com/xmldom/xmldom/issues/111) / [`#304`](https://github.com/xmldom/xmldom/pull/304)
- Pinned and updated devDependencies

Thank you [@marrus-sh](https://github.com/marrus-sh), [@victorandree](https://github.com/victorandree), [@mdierolf](https://github.com/mdierolf), [@tsabbay](https://github.com/tsabbay), [@fatihpense](https://github.com/fatihpense) for your contributions

## 0.7.5

[Commits](https://github.com/xmldom/xmldom/compare/0.7.4...0.7.5)

### Fixes:

- Preserve default namespace when serializing [`#319`](https://github.com/xmldom/xmldom/issues/319) / [`#321`](https://github.com/xmldom/xmldom/pull/321)
  Thank you, [@lupestro](https://github.com/lupestro)

## 0.7.4

[Commits](https://github.com/xmldom/xmldom/compare/0.7.3...0.7.4)

### Fixes:

- Restore ability to parse `__prototype__` attributes [`#315`](https://github.com/xmldom/xmldom/pull/315)
  Thank you, [@dsimpsonOMF](https://github.com/dsimpsonOMF)

## 0.7.3

[Commits](https://github.com/xmldom/xmldom/compare/0.7.2...0.7.3)

### Fixes:

- Add doctype when parsing from string [`#277`](https://github.com/xmldom/xmldom/issues/277) / [`#301`](https://github.com/xmldom/xmldom/pull/301)
- Correct typo in error message [`#294`](https://github.com/xmldom/xmldom/pull/294)
  Thank you, [@rrthomas](https://github.com/rrthomas)

### Refactor:

- Improve exports & require statements, new main package entry [`#233`](https://github.com/xmldom/xmldom/pull/233)

### Docs:

- Fix Stryker badge [`#298`](https://github.com/xmldom/xmldom/pull/298)
- Fix link to help-wanted issues [`#299`](https://github.com/xmldom/xmldom/pull/299)

### Chore:

- Execute stryker:dry-run on branches [`#302`](https://github.com/xmldom/xmldom/pull/302)
- Fix stryker config [`#300`](https://github.com/xmldom/xmldom/pull/300)
- Split test and lint scripts [`#297`](https://github.com/xmldom/xmldom/pull/297)
- Switch to stryker dashboard owned by org [`#292`](https://github.com/xmldom/xmldom/pull/292)

## 0.7.2

[Commits](https://github.com/xmldom/xmldom/compare/0.7.1...0.7.2)

### Fixes:

- Types: Add index.d.ts to packaged files [`#288`](https://github.com/xmldom/xmldom/pull/288)
  Thank you, [@forty](https://github.com/forty)

## 0.7.1

[Commits](https://github.com/xmldom/xmldom/compare/0.7.0...0.7.1)

### Fixes:

- Types: Copy types from DefinitelyTyped [`#283`](https://github.com/xmldom/xmldom/pull/283)
  Thank you, [@kachkaev](https://github.com/kachkaev)

### Chore:
- package.json: remove author, maintainers, etc. [`#279`](https://github.com/xmldom/xmldom/pull/279)

## 0.7.0 

[Commits](https://github.com/xmldom/xmldom/compare/0.6.0...0.7.0)

Due to [`#271`](https://github.com/xmldom/xmldom/issue/271) this version was published as
- unscoped `xmldom` package to github (git tags [`0.7.0`](https://github.com/xmldom/xmldom/tree/0.7.0) and [`0.7.0+unscoped`](https://github.com/xmldom/xmldom/tree/0.7.0%2Bunscoped))
- scoped `@xmldom/xmldom` package to npm (git tag `0.7.0+scoped`)
For more details look at [`#278`](https://github.com/xmldom/xmldom/pull/278#issuecomment-902172483)

### Fixes:

- Security: Misinterpretation of malicious XML input [`CVE-2021-32796`](https://github.com/xmldom/xmldom/security/advisories/GHSA-5fg8-2547-mr8q)
- Implement `Document.getElementsByClassName` as specified [`#213`](https://github.com/xmldom/xmldom/pull/213), thank you, [@ChALkeR](https://github.com/ChALkeR)
- Inherit namespace prefix from parent when required [`#268`](https://github.com/xmldom/xmldom/pull/268)
- Handle whitespace in closing tags [`#267`](https://github.com/xmldom/xmldom/pull/267)
- Update `DOMImplementation` according to recent specs [`#210`](https://github.com/xmldom/xmldom/pull/210)  
  BREAKING CHANGE: Only if you "passed features to be marked as available as a constructor arguments" and expected it to "magically work".
- No longer serializes any namespaces with an empty URI [`#244`](https://github.com/xmldom/xmldom/pull/244)   
  (related to [`#168`](https://github.com/xmldom/xmldom/pull/168) released in 0.6.0)  
  BREAKING CHANGE: Only if you rely on ["unsetting" a namespace prefix](https://github.com/xmldom/xmldom/pull/168#issuecomment-886984994) by setting it to an empty string 
- Set `localName` as part of `Document.createElement` [`#229`](https://github.com/xmldom/xmldom/pull/229), thank you, [@rrthomas](https://github.com/rrthomas)

### CI

- We are now additionally running tests against node v16
- Stryker tests on the master branch now run against node v14

### Docs

- Describe relations with and between specs: [`#211`](https://github.com/xmldom/xmldom/pull/211), [`#247`](https://github.com/xmldom/xmldom/pull/247)

## 0.6.0

[Commits](https://github.com/xmldom/xmldom/compare/0.5.0...0.6.0)

### Fixes

- Stop serializing empty namespace values like `xmlns:ds=""` [`#168`](https://github.com/xmldom/xmldom/pull/168)  
  BREAKING CHANGE: If your code expected empty namespaces attributes to be serialized.  
  Thank you, [@pdecat](https://github.com/pdecat) and [@FranckDepoortere](https://github.com/FranckDepoortere)
- Escape `<` to `&lt;` when serializing attribute values [`#198`](https://github.com/xmldom/xmldom/issues/198) / [`#199`](https://github.com/xmldom/xmldom/pull/199)

## 0.5.0

[Commits](https://github.com/xmldom/xmldom/compare/0.4.0...0.5.0)

### Fixes
- Avoid misinterpretation of malicious XML input - [`GHSA-h6q6-9hqw-rwfv`](https://github.com/xmldom/xmldom/security/advisories/GHSA-h6q6-9hqw-rwfv) (CVE-2021-21366)
  - Improve error reporting; throw on duplicate attribute\
    BREAKING CHANGE: It is currently not clear how to consistently deal with duplicate attributes, so it's also safer for our users to fail when detecting them.
    It's possible to configure the `DOMParser.errorHandler` before parsing, to handle those errors differently.

    To accomplish this and also be able to verify it in tests I needed to
    - create a new `Error` type `ParseError` and export it
    - Throw `ParseError` from `errorHandler.fatalError` and prevent those from being caught in `XMLReader`.
    - export `DOMHandler` constructor as `__DOMHandler`
  - Preserve quotes in DOCTYPE declaration
    Since the only purpose of parsing the DOCTYPE is to be able to restore it when serializing, we decided that it would be best to leave the parsed `publicId` and `systemId` as is, including any quotes.
    BREAKING CHANGE: If somebody relies on the actual unquoted values of those ids, they will need to take care of either single or double quotes and the right escaping.
    (Without this change this would not have been possible because the SAX parser already dropped the information about the quotes that have been used in the source.)

    https://www.w3.org/TR/2006/REC-xml11-20060816/#dtd
    https://www.w3.org/TR/2006/REC-xml11-20060816/#IDAX1KS (External Entity Declaration)

- Fix breaking preprocessors' directives when parsing attributes [`#171`](https://github.com/xmldom/xmldom/pull/171)
- fix(dom): Escape `]]&gt;` when serializing CharData [`#181`](https://github.com/xmldom/xmldom/pull/181)
- Switch to (only) MIT license (drop problematic LGPL license option) [`#178`](https://github.com/xmldom/xmldom/pull/178)
- Export DOMException; remove custom assertions; etc.  [`#174`](https://github.com/xmldom/xmldom/pull/174)

### Docs
- Update MDN links in `readme.md` [`#188`](https://github.com/xmldom/xmldom/pull/188)

## 0.4.0

[Commits](https://github.com/xmldom/xmldom/compare/0.3.0...0.4.0)

### Fixes
- **BREAKING** Restore `&nbsp;` behavior from v0.1.27 [`#67`](https://github.com/xmldom/xmldom/pull/67)
- **BREAKING** Typecheck source param before parsing [`#113`](https://github.com/xmldom/xmldom/pull/113)
- Include documents in package files list [`#156`](https://github.com/xmldom/xmldom/pull/156)
- Preserve doctype with sysid [`#144`](https://github.com/xmldom/xmldom/pull/144)
- Remove ES6 syntax from getElementsByClassName [`#91`](https://github.com/xmldom/xmldom/pull/91)
- Revert "Add lowercase of åäö in entityMap" due to duplicate entries [`#84`](https://github.com/xmldom/xmldom/pull/84)
- fix: Convert all line separators to LF [`#66`](https://github.com/xmldom/xmldom/pull/66)

### Docs
- Update CHANGELOG.md through version 0.3.0 [`#63`](https://github.com/xmldom/xmldom/pull/63)
- Update badges [`#78`](https://github.com/xmldom/xmldom/pull/78)
- Add .editorconfig file [`#104`](https://github.com/xmldom/xmldom/pull/104)
- Add note about import [`#79`](https://github.com/xmldom/xmldom/pull/79)
- Modernize & improve the example in readme.md [`#81`](https://github.com/xmldom/xmldom/pull/81)

### CI
- Add Stryker Mutator [`#70`](https://github.com/xmldom/xmldom/pull/70)
- Add Stryker action to update dashboard [`#77`](https://github.com/xmldom/xmldom/pull/77)
- Add Node GitHub action workflow [`#64`](https://github.com/xmldom/xmldom/pull/64)
- add & enable eslint [`#106`](https://github.com/xmldom/xmldom/pull/106)
- Use eslint-plugin-es5 to enforce ES5 syntax [`#107`](https://github.com/xmldom/xmldom/pull/107)
- Recover `vows` tests, drop `proof` tests [`#59`](https://github.com/xmldom/xmldom/pull/59)
- Add jest tessuite and first tests [`#114`](https://github.com/xmldom/xmldom/pull/114)
- Add jest testsuite with `xmltest` cases [`#112`](https://github.com/xmldom/xmldom/pull/112)
- Configure Renovate [`#108`](https://github.com/xmldom/xmldom/pull/108)
- Test European HTML entities [`#86`](https://github.com/xmldom/xmldom/pull/86)
- Updated devDependencies

### Other
- Remove files that are not of any use [`#131`](https://github.com/xmldom/xmldom/pull/131), [`#65`](https://github.com/xmldom/xmldom/pull/65), [`#33`](https://github.com/xmldom/xmldom/pull/33)

## 0.3.0

[Commits](https://github.com/xmldom/xmldom/compare/0.2.1...0.3.0)

- **BREAKING** Node >=10.x is now required.
- **BREAKING** Remove `component.json` (deprecated package manager https://github.com/componentjs/guide)
- **BREAKING** Move existing sources into `lib` subdirectory.
- **POSSIBLY BREAKING** Introduce `files` entry in `package.json` and remove use of `.npmignore`.
- [Add `Document.getElementsByClassName`](https://github.com/xmldom/xmldom/issues/24).
- [Add `Node` to the list of exports](https://github.com/xmldom/xmldom/pull/27)
- [Add lowercase of åäö in `entityMap`](https://github.com/xmldom/xmldom/pull/23).
- Move CHANGELOG to markdown file.
- Move LICENSE to markdown file.

## 0.2.1

[Commits](https://github.com/xmldom/xmldom/compare/0.2.0...0.2.1)

- Correct `homepage`, `repository` and `bugs` URLs in `package.json`.

## 0.2.0

[Commits](https://github.com/xmldom/xmldom/compare/v0.1.27...0.2.0)

- Includes all **BREAKING** changes introduced in [`xmldom-alpha@v0.1.28`](#0128) by the original authors.
- **POSSIBLY BREAKING** [remove the `Object.create` check from the `_extends` method of `dom.js` that added a `__proto__` property](https://github.com/xmldom/xmldom/commit/0be2ae910a8a22c9ec2cac042e04de4c04317d2a#diff-7d1c5d97786fdf9af5446a241d0b6d56L19-L22) ().
- **POSSIBLY BREAKING** [remove code that added a `__proto__` property](https://github.com/xmldom/xmldom/commit/366159a76a181ce9a0d83f5dc48205686cfaf9cc)
- formatting/corrections in `package.json`

## 0.1.31

[Commits](https://github.com/xmldom/xmldom/compare/v0.1.27...v0.1.31)

The patch versions (`v0.1.29` - `v0.1.31`) that have been released on the [v0.1.x branch](https://github.com/xmldom/xmldom/tree/0.1.x), to reflect the changed maintainers, **are branched off from [`v0.1.27`](#0127) so they don't include the breaking changes introduced in [`xmldom-alpha@v0.1.28`](#0128)**:

## Maintainer changes

After the last commit to the original repository <https://github.com/jindw/xmldom> on the 9th of May 2017, the first commit to <https://github.com/xmldom/xmldom> is from the 19th of December 2019. [The fork has been announced in the original repository on the 2nd of March 2020.](https://github.com/jindw/xmldom/issues/259)

The versions listed below have been published to one or both of the following packages:
- <https://www.npmjs.com/package/xmldom-alpha>
- <https://www.npmjs.com/package/xmldom>

It is currently not planned to continue publishing the `xmldom-alpha` package.

The new maintainers did not invest time to understand changes that led to the last `xmldom` version [`0.1.27`](#0127) published by the original maintainer, but consider it the basis for their work.
A timeline of all the changes that happened from that version until `0.3.0` is available in <https://github.com/xmldom/xmldom/issues/62>. Any related questions should be asked there.

## 0.1.28

[Commits](https://github.com/xmldom/xmldom/compare/v0.1.27...xmldom-alpha@v0.1.28)

Published by @jindw on the 9th of May 2017 as
- `xmldom-alpha@0.1.28`

- **BREAKING** includes [regression regarding `&nbsp;` (issue #57)](https://github.com/xmldom/xmldom/issues/57) 
- [Fix `license` field in `package.json`](https://github.com/jindw/xmldom/pull/178)
- [Conditional converting of HTML entities](https://github.com/jindw/xmldom/pull/80)
- Fix `dom.js` serialization issue for missing document element ([example that failed on `toString()` before this change](https://github.com/xmldom/xmldom/blob/a58dcf7a265522e80ce520fe3be0cddb1b976f6f/test/parse/unclosedcomment.js#L10-L11))
- Add new module `entities.js`

## 0.1.27

Published by @jindw on the 28th of Nov 2016 as 
- `xmldom@0.1.27`
- `xmldom-alpha@0.1.27` 

- Various bug fixes.

## 0.1.26

Published on the 18th of Nov 2016
as `xmldom@0.1.26`

- Details unknown

## 0.1.25

Published on the 18th of Nov 2016 as 
- `xmldom@0.1.25`

- Details unknown

## 0.1.24

Published on the 27th of November 2016 as
- `xmldom@0.1.24`
- `xmldom-alpha@0.1.24`

- Added node filter.

## 0.1.23

Published on the 5th of May 2016 as
- `xmldom-alpha@0.1.23`

- Add namespace support for nest node serialize.
- Various other bug fixes.

## 0.1.22

- Merge XMLNS serialization.
- Remove \r from source string.
- Print namespaces for child elements.
- Switch references to nodeType to use named constants.
- Add nodelist toString support.

## 0.1.21

- Fix serialize bug.

## 0.1.20

- Optimize invalid XML support.
- Add toString sorter for attributes output.
- Add html self closed node button.
- Add `*` NS support for getElementsByTagNameNS.
- Convert attribute's value to string in setAttributeNS.
- Add support for HTML entities for HTML docs only.
- Fix TypeError when Document is created with DocumentType.

## 0.1.19

- Fix [infinite loop on unclosed comment (jindw/xmldom#68)](https://github.com/jindw/xmldom/issues/68)
- Add error report for unclosed tag.
- Various other fixes.

## 0.1.18

- Add default `ns` support.
- parseFromString now renders entirely plain text documents as textNode.
- Enable option to ignore white space on parsing.

## 0.1.17

**Details missing for this and potential earlier version**

## 0.1.16

- Correctly handle multibyte Unicode greater than two byts. #57. #56.
- Initial unit testing and test coverage. #53. #46. #19.
- Create Bower `component.json` #52.

## 0.1.8

- Add: some test case from node-o3-xml(excludes xpath support)
- Fix: remove existed attribute before setting  (bug introduced in v0.1.5)
- Fix: index direct access for childNodes and any NodeList collection(not w3c standard)
- Fix: remove last child bug
