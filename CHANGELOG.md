# Changelog

## [1.5.0](https://github.com/rootless-dev/MyPasteApp/compare/v1.4.0...v1.5.0) (2026-08-05)


### Features

* **color:** read, convert and write colour codes ([5ffc46a](https://github.com/rootless-dev/MyPasteApp/commit/5ffc46aac2ade93c8f2c2cccdbc80966a4fe89e7))
* **color:** sample a colour from the screen into the history ([ef60232](https://github.com/rootless-dev/MyPasteApp/commit/ef60232b320642e2fc6ecca6bce49a282a038f65))
* **color:** show recognised colours and convert between formats ([d4921b1](https://github.com/rootless-dev/MyPasteApp/commit/d4921b14ebcca1056fe2cd29c93ce0c506003075))
* **drag:** decide what each card hands over, and what to clean up ([954cf04](https://github.com/rootless-dev/MyPasteApp/commit/954cf041e6815eb277cb5d98de5d46625184f7a1))
* **drag:** drag any card out of the drawer ([4385e3a](https://github.com/rootless-dev/MyPasteApp/commit/4385e3a2827d3b651304e951614425daf5a650e2))
* **editor:** count characters, words and lines ([4ded4ec](https://github.com/rootless-dev/MyPasteApp/commit/4ded4ec9cc305a1f4e3dc809263596c9e81fcfd7))
* **editor:** format text from a toolbar ([6771af2](https://github.com/rootless-dev/MyPasteApp/commit/6771af2515416abdd1321f674067ba49af1ef992))
* **image:** read the colour of a pixel from the original data ([e236ed8](https://github.com/rootless-dev/MyPasteApp/commit/e236ed895ed5bf8c5ed8bb434ced74cd8e41a163))
* **image:** rotate image data by quarter turns ([9e00139](https://github.com/rootless-dev/MyPasteApp/commit/9e001391d49c65ae1d5721abf57b68709d369832))
* **image:** rotate images in the item editor ([9c64291](https://github.com/rootless-dev/MyPasteApp/commit/9c642913bd9e832cb90e6fbfc5863a04cd84fe93))
* **image:** sample a colour from the preview panel ([7aad17c](https://github.com/rootless-dev/MyPasteApp/commit/7aad17cec971c1fd8d1d5e10b60955932a81db66))
* **image:** select text inside an image with Live Text ([8424f6c](https://github.com/rootless-dev/MyPasteApp/commit/8424f6cac875c301b91f7c6d1c6b796ef743f1bb))
* **live-text:** turn on the data detectors the spec promised ([20dbe5b](https://github.com/rootless-dev/MyPasteApp/commit/20dbe5bc376d4a2dd9707f6e1203ee1f93a95471))
* **open:** open files and links in another app ([09dd5bd](https://github.com/rootless-dev/MyPasteApp/commit/09dd5bdc16ffae35f2f84d89b9749bfa99946665))
* **overlay:** select on click, paste on double click ([1a576ab](https://github.com/rootless-dev/MyPasteApp/commit/1a576ab5e4b61ca6ab02460b5df72af8a8bba697))
* **overlay:** slide the drawer back down on the way out ([173dbe9](https://github.com/rootless-dev/MyPasteApp/commit/173dbe96a28af2540b9b4fa7f6297048244cfc45))
* **preview:** add pure zoom geometry for the image preview panel ([a6b7a69](https://github.com/rootless-dev/MyPasteApp/commit/a6b7a696c040f84aa457f7fae98e63f012810ffd))
* **preview:** drag the panel off the drawer into its own window ([b2624ea](https://github.com/rootless-dev/MyPasteApp/commit/b2624ea4775c08ed053de33a3d201a4496972250))
* **preview:** draw the panel's own shape on a transparent window ([98dddb8](https://github.com/rootless-dev/MyPasteApp/commit/98dddb898f519d263f54e0e7cfdf71ccab55429c))
* **preview:** give detached panels a life cycle of their own ([11e3796](https://github.com/rootless-dev/MyPasteApp/commit/11e3796aecd17c0959e434964ac121c493e8fbac))
* **preview:** o preview vira janela — bico ancorado e soltar ao arrastar ([3fda9df](https://github.com/rootless-dev/MyPasteApp/commit/3fda9df5ea609884f257b3fd1a916e4ff15c1ec6))
* **preview:** pinch/button zoom and pan on the image preview panel ([32d9ca1](https://github.com/rootless-dev/MyPasteApp/commit/32d9ca1e2784eaebcc284ba348da61f0e5641a29))
* **preview:** point the panel's beak at the card it is showing ([c32ec57](https://github.com/rootless-dev/MyPasteApp/commit/c32ec57b767244076303ef4e1960f7b2949f0574))


### Bug Fixes

* **color:** file the colour sampled in the preview, like the other two ([20e6323](https://github.com/rootless-dev/MyPasteApp/commit/20e632322781e1b83d29dc62621128b7dad640f3))
* **color:** judge swatch text contrast against the composited colour ([2262aed](https://github.com/rootless-dev/MyPasteApp/commit/2262aedeac6ae9de4f1879e123636dee37dc93b6))
* **colors:** credit converted colours to this app, and only file them once ([ff2f308](https://github.com/rootless-dev/MyPasteApp/commit/ff2f3089f195f7dda24f377adfae79f21deb4820))
* **colors:** wrap negative hues, cap parse length, read the appearance ([d7d1b09](https://github.com/rootless-dev/MyPasteApp/commit/d7d1b097aa8b599029d45b4d2c8a9e3c983d84c9))
* **drag:** carry whichever rich format the source offered, and pin the fallback file-name clock ([765a11f](https://github.com/rootless-dev/MyPasteApp/commit/765a11f74b93245c922e08c32df1ae7c0081b428))
* **drag:** make the fallback file-name test independent of the runner's zone ([20c5c08](https://github.com/rootless-dev/MyPasteApp/commit/20c5c08b3172a49e339bb726a9bb11155e2595ff))
* **drag:** stop N file registrations from clobbering each other, isolate temp writes ([306f220](https://github.com/rootless-dev/MyPasteApp/commit/306f220ba7ea99db16ba3adfb04ed21030007355))
* **editor:** defer command state publish and fix uniform toggle for underline/strikethrough ([ce425cb](https://github.com/rootless-dev/MyPasteApp/commit/ce425cbe7954110fae6cbd2a95af355a766fe0f5))
* **editor:** fit rotated images to the frame instead of overflowing it ([81fa0a5](https://github.com/rootless-dev/MyPasteApp/commit/81fa0a5fcea78a6c2b2e9c40a0b1d020b59737dd))
* **editor:** give format commands identity and defer the whole apply ([c054d00](https://github.com/rootless-dev/MyPasteApp/commit/c054d006d6e7fdf10f5d8db89c14768145667dbc))
* **editor:** give the formatting toolbar an undo ([3d85ba0](https://github.com/rootless-dev/MyPasteApp/commit/3d85ba0caa90b0b1b5e074e5bf9783a2dfe9bea8))
* **editor:** stop clearing formatting from raising on a shorter document ([135ab57](https://github.com/rootless-dev/MyPasteApp/commit/135ab57d9844cba86f0bc181d18fdaf19067c1bc))
* **image:** cancel in-flight Live Text analysis on view teardown ([e236fb3](https://github.com/rootless-dev/MyPasteApp/commit/e236fb32ba8f5c16d25918e66e63abb4ac87e137))
* **image:** replace cursor push/pop with onContinuousHover + set() ([3e3a44a](https://github.com/rootless-dev/MyPasteApp/commit/3e3a44a34b10a0477c2be916eaa4d026ddbdb916))
* **image:** sample the preview colour silently, per spec ([96bac6a](https://github.com/rootless-dev/MyPasteApp/commit/96bac6aebb49f79c37cefa0fe8717f45d4a07f9a))
* **open-with:** let contact-card schemes open again ([1c6c390](https://github.com/rootless-dev/MyPasteApp/commit/1c6c39094c951794ef312cc516b58889a4693a03))
* **open-with:** only hand http, https and mailto to NSWorkspace ([9b7cab0](https://github.com/rootless-dev/MyPasteApp/commit/9b7cab0078a485ab7f4324997db2835214487514))
* **overlay:** select on the click, not half a second after it ([5a7ecd5](https://github.com/rootless-dev/MyPasteApp/commit/5a7ecd55a19b931baba2f7c17d8cb331c43a483b))
* **preview:** give the panel back its drop shadow ([41b9b23](https://github.com/rootless-dev/MyPasteApp/commit/41b9b23b495ab85ddde61accc3b06f4658135077))
* **preview:** point the panel's close button at its own window ([ebd2ce9](https://github.com/rootless-dev/MyPasteApp/commit/ebd2ce9a9fd88b75ebdb41b7c15a100474ee015c))
* **preview:** quantise zoom's decode requests to a handful of steps ([7e77acc](https://github.com/rootless-dev/MyPasteApp/commit/7e77acce71c5e35f0cadc7ed1c11d0c2f0d56427))
* **preview:** render rich text in the preview panel instead of plain ([4024dac](https://github.com/rootless-dev/MyPasteApp/commit/4024dac23dbe8595e3251d5feafeb20bf58aa01e))
* **preview:** reset zoom when an edit rewrites the same item's image ([4db42a0](https://github.com/rootless-dev/MyPasteApp/commit/4db42a0961f1a9b7a16adb5c7439aaf5b4c42276))
* **preview:** stop a click on a detached panel from closing the drawer ([115c8d6](https://github.com/rootless-dev/MyPasteApp/commit/115c8d6dbd152d9d2dfd84dad7a1c7d8b0c1dc10))
* **preview:** stop pinch/pan from mutating zoom while Live Text is armed ([7028c6f](https://github.com/rootless-dev/MyPasteApp/commit/7028c6f2b925e616ebd7da4d720b3533454aed01))
* **preview:** stop the window drag from eating the zoom pan ([5e6efcb](https://github.com/rootless-dev/MyPasteApp/commit/5e6efcbe639ea2d9019bb777a198babe9a6d4b18))
* **rich-text:** drop attachment placeholders when clearing formatting ([0ad7f0d](https://github.com/rootless-dev/MyPasteApp/commit/0ad7f0d22a297b89c9d04e7a438bdb670e3264b9))
* **sampler:** stop using a pixel buffer past its lifetime ([d298535](https://github.com/rootless-dev/MyPasteApp/commit/d298535bacf78afa7e0922c5014abc3fac144f5f))
* **thumbnails:** let a rotated image look different to the card ([a72cdc7](https://github.com/rootless-dev/MyPasteApp/commit/a72cdc7c1d737994b12fe3138275bb7cc5adebf3))


### Performance

* **editor:** stop recounting a 2 MB log on every keystroke ([f73c807](https://github.com/rootless-dev/MyPasteApp/commit/f73c807a802db250ba0c51f5a15a05e9928c37c0))


### Refactoring

* **preview:** extract panel placement as a tested pure function ([ab2209a](https://github.com/rootless-dev/MyPasteApp/commit/ab2209a438a36588f7f7a7d288e2f1e500922a26))
* **preview:** move panel management into PreviewPanelController ([49539c3](https://github.com/rootless-dev/MyPasteApp/commit/49539c3496b4cc2e05f134280b7c019d993b5047))


### Documentation

* **editor:** don't claim O(1) for a length this call site can't give ([77bb239](https://github.com/rootless-dev/MyPasteApp/commit/77bb239517e3fc607461075af86e5d7623cf353e))
* **fase-6:** design and plan for content tools ([980ed39](https://github.com/rootless-dev/MyPasteApp/commit/980ed399a164286c845bad846ece9594dbc369f4))
* **phase-6.5:** spec and plan for turning the preview into a window ([6fa3073](https://github.com/rootless-dev/MyPasteApp/commit/6fa3073273386a924b1f96581534e2056e275b2f))
* **preview:** add A7b, the drawer state the A3 click leaves behind ([3e4571c](https://github.com/rootless-dev/MyPasteApp/commit/3e4571c7697ef1d242d19e9a5237c6efe53b7016))
* **preview:** scope the hosting-view rule to hosting views ([4efe9e5](https://github.com/rootless-dev/MyPasteApp/commit/4efe9e55d109c70ac8d8cfb512810a779843a683))
* **verify:** script the manual checks for phase 6 ([6ac1954](https://github.com/rootless-dev/MyPasteApp/commit/6ac19548c6e2430eebb58f2510f1d0d0646cac18))

## [1.4.0](https://github.com/rootless-dev/MyPasteApp/compare/v1.3.0...v1.4.0) (2026-08-04)


### Features

* **items:** file items into pinboards and set per-item retention from the menu ([ab13ddb](https://github.com/rootless-dev/MyPasteApp/commit/ab13ddbf11908da35d6f1e25d6edb944d870a081))
* **pinboards:** add the navigation scope and give escape its step ([24f40d8](https://github.com/rootless-dev/MyPasteApp/commit/24f40d87476b778dd853b9ae29ad758103ee450d))
* **pinboards:** add the Pinboard model, its palette and the item fields ([f6577ea](https://github.com/rootless-dev/MyPasteApp/commit/f6577eaddfc402d95739446140eb3b31c09ce712))
* **pinboards:** add the scope strip to the overlay's top bar ([d6efee6](https://github.com/rootless-dev/MyPasteApp/commit/d6efee6d7528cf478c75420f6c07f56b6a56dcbc))
* **pinboards:** colour card headers by board and mark membership in the history ([4260df7](https://github.com/rootless-dev/MyPasteApp/commit/4260df708ae54b804e88a1eb6c1551351b1f1f8b))
* **pinboards:** create, rename, recolour and delete boards ([7a16140](https://github.com/rootless-dev/MyPasteApp/commit/7a161404c2c306a7b7cf06dd3fc616a6d8dcf734))
* **pinboards:** scope the card list, wire the strip and cycle with ctrl-tab ([2bdd295](https://github.com/rootless-dev/MyPasteApp/commit/2bdd295c3935cc5b4b8bdb8c0850b6e280d8fdd9))
* **pinboards:** tell a rename click from a scope click ([4f9d319](https://github.com/rootless-dev/MyPasteApp/commit/4f9d31939f220e68a2ec9a5b627da23c12ec8d91))
* **privacy:** add per-app capture rules with migration from the ignored-apps list ([1f9776a](https://github.com/rootless-dev/MyPasteApp/commit/1f9776ab74536c7b3491d1f432c8ce5f8cfb1b9e))
* **privacy:** reject banned apps before reading, and filter the rest by type ([e9fd9c5](https://github.com/rootless-dev/MyPasteApp/commit/e9fd9c5538c9c25d4cf024c174bb6019b7489afd))
* **retention:** honour per-item retention and protect pinboards from pruning ([fe704bd](https://github.com/rootless-dev/MyPasteApp/commit/fe704bd702521fe8ac0bcddd71aa1d655084322a))
* **retention:** let a future expiry date protect an item ([21a6221](https://github.com/rootless-dev/MyPasteApp/commit/21a6221cee12ea6e9f64720278cc7a22ab327044))
* **retention:** prune every five minutes, not only at launch ([feaff6f](https://github.com/rootless-dev/MyPasteApp/commit/feaff6f8e273a4d4a321c21a9935b6f7bb4e9fca))
* **settings:** replace the bundle-ID editor with an app rules list ([39b0117](https://github.com/rootless-dev/MyPasteApp/commit/39b0117c935c60df80a9ecdae409b718a016d01b))


### Bug Fixes

* **capture:** drop a stale expiry when an item is copied again ([d251c14](https://github.com/rootless-dev/MyPasteApp/commit/d251c148c66cff39ee394dafb1c0afe6c89e9bfc))
* **overlay:** stop ctrl-tab and the empty state from lying ([ef9ff4e](https://github.com/rootless-dev/MyPasteApp/commit/ef9ff4e0a31489cf1488662e246763eacd2ad670))
* **pinboards:** give the rename field the keyboard, and the overlay a gate ([e3282f2](https://github.com/rootless-dev/MyPasteApp/commit/e3282f2cd0c23f216f4103dbf5388862beb9c65d))
* **pinboards:** hand the keyboard back when the rename field leaves ([b373b6b](https://github.com/rootless-dev/MyPasteApp/commit/b373b6bf8a5526e834a0ed77c966ca44d5367b2d))
* **pinboards:** keep the preview-close path alive and sync scope selection ([28edcb2](https://github.com/rootless-dev/MyPasteApp/commit/28edcb270f056ce3105c3205c74c32c8af3218a4))
* **pinboards:** reset the inline rename when the drawer reopens ([f758512](https://github.com/rootless-dev/MyPasteApp/commit/f7585129276f55fc3abe88c5d7422e5c6a1af8c8))
* **privacy:** match the legacy separator set when migrating ignored apps ([76d5985](https://github.com/rootless-dev/MyPasteApp/commit/76d59857742b1892a14cff05509c1a678339a118))
* **tests:** register Pinboard on the six containers still missing it ([3954b6b](https://github.com/rootless-dev/MyPasteApp/commit/3954b6b7df79bb75b431f1f4b0f74c263188896b))


### Refactoring

* **privacy:** make the pre-read gate a function the suite can hold ([b690128](https://github.com/rootless-dev/MyPasteApp/commit/b6901280b9eff2a14371b596e14868bb926f0c79))
* **privacy:** retire the legacy per-app ignore list parser ([dbaaddf](https://github.com/rootless-dev/MyPasteApp/commit/dbaaddf0e055da9241f0db8c5228d09e4b496907))


### Documentation

* **fase-5:** add the design spec and implementation plan ([8a6f113](https://github.com/rootless-dev/MyPasteApp/commit/8a6f113f2a504042e74de4ffdb5c4e7510637cde))
* **fase-5:** add the manual verification script ([b3f31aa](https://github.com/rootless-dev/MyPasteApp/commit/b3f31aa954653460336634f755cb95bf9805c01d))
* **fase-5:** say what was measured, and finish the four protections ([7200005](https://github.com/rootless-dev/MyPasteApp/commit/720000544bec6503c3a1cb2b30e0c8d123b61f8e))
* **verify:** cover task 7, the filing menus and the new retention rules ([61bcbab](https://github.com/rootless-dev/MyPasteApp/commit/61bcbab563625fba594d0208907b1101eeaa4bf8))

## [1.3.0](https://github.com/rootless-dev/MyPasteApp/compare/v1.2.0...v1.3.0) (2026-08-03)


### Features

* **multi-paste:** add the ordered marked selection ([9e2ac8e](https://github.com/rootless-dev/MyPasteApp/commit/9e2ac8ee57379afd0babb305d9b739cfcd3506f3))
* **multi-paste:** add the separator options ([75512b4](https://github.com/rootless-dev/MyPasteApp/commit/75512b488336752321fef1c03c47f6f8de788ded))
* **multi-paste:** add the separator preference ([a434d6f](https://github.com/rootless-dev/MyPasteApp/commit/a434d6fc8c7d058e024998463a7db1f86437c23f))
* **multi-paste:** add the type gate, id resolution and joining ([8d0bc84](https://github.com/rootless-dev/MyPasteApp/commit/8d0bc84945e422614f9892cf03a9b6086544f876))
* **multi-paste:** clear marks before escape closes the drawer ([b92c3cf](https://github.com/rootless-dev/MyPasteApp/commit/b92c3cf2e23766f203b30155f3723dc25ef66e76))
* **multi-paste:** mark with ⌘M or ⌘-click and paste the block with ↵ ([49b21bb](https://github.com/rootless-dev/MyPasteApp/commit/49b21bb7ffcd27589eb2592c0beac43948f66c18))
* **multi-paste:** read rich text per item and record use without promoting ([831d8af](https://github.com/rootless-dev/MyPasteApp/commit/831d8af515a1a28ff8012bfb8d9e2775f1d19de5))
* **multi-paste:** show the mark order on the card ([0c51027](https://github.com/rootless-dev/MyPasteApp/commit/0c5102769e0c2cea05eb3eb9668932001d76f8a8))
* **multi-paste:** show the marked count and add the context menu entry ([0c5021c](https://github.com/rootless-dev/MyPasteApp/commit/0c5021c78689cbaa6514375207170ce3be53a0bd))
* **multi-paste:** write several items to the pasteboard as one block ([1b185c9](https://github.com/rootless-dev/MyPasteApp/commit/1b185c9688b437166d54797b88c40a59f5f865e3))
* **ocr:** add a serial low-priority queue with backlog support ([e36b8e1](https://github.com/rootless-dev/MyPasteApp/commit/e36b8e17c76fecc83881f4115c5f4b48c4f997ec))
* **ocr:** add ocrText/ocrProcessedAt fields and the scheduling rule ([2c41890](https://github.com/rootless-dev/MyPasteApp/commit/2c418902635defff567420343175a4d5a89cd669))
* **ocr:** recognise text in images with Vision, on device ([8895cb0](https://github.com/rootless-dev/MyPasteApp/commit/8895cb0904ec73ae1d75085b2fe4a080bf35541a))
* **ocr:** run OCR on capture and backfill, behind a privacy toggle ([6362855](https://github.com/rootless-dev/MyPasteApp/commit/63628551ac38049e5573f931289f240f71e56654))
* **search:** add SearchState with the keyboard and token rules ([e77fdd9](https://github.com/rootless-dev/MyPasteApp/commit/e77fdd93fac2253137831bacc26c01495b58b015))
* **search:** add Show in History (⌘J) ([339727e](https://github.com/rootless-dev/MyPasteApp/commit/339727ec872bdaff112b122a8c3433ac19c0f47c))
* **search:** collapse the search field into a magnifier at rest ([836c408](https://github.com/rootless-dev/MyPasteApp/commit/836c408c248593095f546c882e9d34466d49e35e))
* **search:** filter by type, source app and date ([6dec751](https://github.com/rootless-dev/MyPasteApp/commit/6dec751c2dd3e8f92c196530bfa8ef13b4a23a55))
* **search:** put the search field in AppKit so the caret can be placed ([5830665](https://github.com/rootless-dev/MyPasteApp/commit/58306657bf2670fb57f4e9991db177ab39167d7e))
* **search:** replace the search bar with a token field ([8d1bd50](https://github.com/rootless-dev/MyPasteApp/commit/8d1bd502d3d767ca164b5a9dde7ef88bbd1a3071))


### Bug Fixes

* **cards:** hide the selection border once a block is being marked ([b5c739d](https://github.com/rootless-dev/MyPasteApp/commit/b5c739dbba84eaa65736b7438d2670b94ce094b5))
* **cards:** pin thumbnails against cache eviction and restore text fallback ([b89597e](https://github.com/rootless-dev/MyPasteApp/commit/b89597ef1b7fc70c1c02bb381b31134c4048f565))
* **links:** stop a re-copy from wiping stored link metadata ([4a6eac2](https://github.com/rootless-dev/MyPasteApp/commit/4a6eac204770a9ccde3ccbabbf4c7f9172f56fe4))
* **multi-paste:** anchor the marked-count pill as an overlay, not a stack sibling ([f180cf6](https://github.com/rootless-dev/MyPasteApp/commit/f180cf6db02d5ab54e6cd3bb5a40547651b36b6b))
* **multi-paste:** don't paste on ⌘-click of a non-markable item ([683fe91](https://github.com/rootless-dev/MyPasteApp/commit/683fe915e360f8785d30e12cb2c841e5a1e1554f))
* **ocr:** read the injected defaults and refresh metadata on the stored item ([240eb48](https://github.com/rootless-dev/MyPasteApp/commit/240eb48fd629c342f2a78342e2adb3878654af74))
* **overlay:** route context-menu delete through OverlayView's delete(_:) ([e89403d](https://github.com/rootless-dev/MyPasteApp/commit/e89403d8cb71d6f29a598f4fe2ddba621a66218c))
* **overlay:** stop backspace from deleting while a block is marked ([1c9c87e](https://github.com/rootless-dev/MyPasteApp/commit/1c9c87ef5546bb7519255da3357e04c553196f99))
* **overlay:** unmark an item when it is deleted ([ba8f109](https://github.com/rootless-dev/MyPasteApp/commit/ba8f1094f347e16f080b81423a12185e97c95f39))
* **paste:** drop the newline the HTML importer appends to each piece ([9329c1b](https://github.com/rootless-dev/MyPasteApp/commit/9329c1b500e1f9adb9f905cf72da71276c03681b))
* **paste:** hand over the captured plain text for a plain block ([4d20e52](https://github.com/rootless-dev/MyPasteApp/commit/4d20e5257224ceb437db7e8d0312ae74570dbc9e))
* **preview:** fix three memory/fallback bugs from the whole-branch review ([f9a361c](https://github.com/rootless-dev/MyPasteApp/commit/f9a361c9810dd01ad10ea4dfc579bbd77c113632))
* **search:** clear the pending selection once the jump settles ([d0470c1](https://github.com/rootless-dev/MyPasteApp/commit/d0470c11f982c36b30dfb9174922719fd78c7623))
* **search:** defer focus to the field and reset search state on open ([1c2c895](https://github.com/rootless-dev/MyPasteApp/commit/1c2c8959082c0552ce21d1e4c5507ebeaa062abf))
* **search:** keep the first character typed into the search ([7f8d6de](https://github.com/rootless-dev/MyPasteApp/commit/7f8d6de278ba6e46c722d4dac5836a283103014d))
* **search:** keep type, date and clear visible while the app list scrolls ([a5a79bc](https://github.com/rootless-dev/MyPasteApp/commit/a5a79bc2cb67a7e2da1117da84e341f5e0db5dea))
* **search:** reveal the selection esc keeps ([2d5a48c](https://github.com/rootless-dev/MyPasteApp/commit/2d5a48cc2aefdd56a95c186972e0e32bec90c78b))
* **search:** scope the field-editor scan to the overlay panel ([9a5209f](https://github.com/rootless-dev/MyPasteApp/commit/9a5209f4a3773a1cea0e7bb1ab3992006c16cf56))
* **search:** size token labels, rescue ⌫ and ␣, tie the stroke to focus ([17ddf30](https://github.com/rootless-dev/MyPasteApp/commit/17ddf30d0bdabbc40ec605777df122f01a226527))


### Performance

* **cards:** decode images at draw size and cache them with a ceiling ([87f150e](https://github.com/rootless-dev/MyPasteApp/commit/87f150e28622bdb2d3905ee7d0d57988c201fc4a))
* **cards:** read image dimensions from the header instead of decoding ([e090fac](https://github.com/rootless-dev/MyPasteApp/commit/e090facbf26a1574e0b095e16bdc375e3c317e98))
* **overlay:** stop invalidating every card when a frame changes ([4fe25aa](https://github.com/rootless-dev/MyPasteApp/commit/4fe25aac6212da0f9a6aa8257cc082e2de50eae5))
* **preview:** lay out long text by viewport instead of rasterizing it whole ([ee0b215](https://github.com/rootless-dev/MyPasteApp/commit/ee0b21575746223cc193331be72758c794f628f4))
* **preview:** release the panel's hosted content when it closes ([7847503](https://github.com/rootless-dev/MyPasteApp/commit/7847503c092ff4942528eaefaa84b045f5f8bbd6))
* **search:** cache app lookups that resolve to nothing ([720f1a7](https://github.com/rootless-dev/MyPasteApp/commit/720f1a7e396f33fef991a03675853e05bf623192))


### Refactoring

* **overlay:** fold the two pick closures into one path ([c7cdde0](https://github.com/rootless-dev/MyPasteApp/commit/c7cdde03e9fe4c2b6a9c00c9e522e45868bedf27))
* **preview:** unify FaviconBadge into ThumbnailImage's chrome switch ([6dac8e1](https://github.com/rootless-dev/MyPasteApp/commit/6dac8e19b62b22e59c26244aff424ecd7cb04a38))
* **search:** extract matching into a pure ItemSearch with filters ([a7f2df7](https://github.com/rootless-dev/MyPasteApp/commit/a7f2df700b59495541cc845dd5777f02530a2717))
* **search:** give the canonical type order one home ([e8bc773](https://github.com/rootless-dev/MyPasteApp/commit/e8bc7738b159a608c0a94c371e363f6306cdfe98))


### Documentation

* add project instructions with the Obsidian board rule ([4812848](https://github.com/rootless-dev/MyPasteApp/commit/48128488658dd15b138b6505db92b00562043ba2))
* **fase-4:** add manual step for delete-via-menu unmark regression ([67db6ee](https://github.com/rootless-dev/MyPasteApp/commit/67db6ee46babeb1cc4eb469c19cc96438873fdc8))
* **multi-paste:** add the manual verification script ([18e99f9](https://github.com/rootless-dev/MyPasteApp/commit/18e99f9b2f2468243076b5d8a75813402e2a4f4b))
* **multi-paste:** add the Phase 4 spec and plan ([cf9c4ba](https://github.com/rootless-dev/MyPasteApp/commit/cf9c4ba08c076eee5499d3a64d00e6911fbea5db))
* **multi-paste:** give E2 and D9 binary pass/fail criteria ([1ffd858](https://github.com/rootless-dev/MyPasteApp/commit/1ffd858bee4b8c73597fb1206f6d7a51d587490a))
* **plan:** authorize commits and drop a tautological test ([5a50b81](https://github.com/rootless-dev/MyPasteApp/commit/5a50b81d94180113a0a15f6a9eeb1bb8758e783e))
* **plan:** split the pixel conversion so the scale can be pinned ([df3bda6](https://github.com/rootless-dev/MyPasteApp/commit/df3bda69cbd32055db347b56b764e3332a0f3577))
* **preview:** fix stale comment and two wrong manual-check lines ([2f3c301](https://github.com/rootless-dev/MyPasteApp/commit/2f3c301ee29543b1c6512df8cd9a3c937239fd28))
* **search:** add the Phase 3 spec, plan and manual verification script ([1592663](https://github.com/rootless-dev/MyPasteApp/commit/1592663006007105f49e9047cba9fa0a962e4e87))
* **search:** correct comments describing the removed workarounds ([8baf194](https://github.com/rootless-dev/MyPasteApp/commit/8baf194c28a182176d90dcb9ee417d7e73844de1))
* spec and implementation plan for roadmap phase 2.5 ([5efc400](https://github.com/rootless-dev/MyPasteApp/commit/5efc4003cc6e4c42a536ce30d53a29c85e1fb666))
* **verify:** add manual steps for the mark/border/backspace fix ([16fb478](https://github.com/rootless-dev/MyPasteApp/commit/16fb4782b3bee9be0bb3590f7532d691d3006b12))

## [1.2.0](https://github.com/rootless-dev/MyPasteApp/compare/v1.1.0...v1.2.0) (2026-07-31)


### Features

* **clipboard:** keep the formatted version of copied text ([deaf145](https://github.com/rootless-dev/MyPasteApp/commit/deaf14582a7405c59edee58aba84a7cee63e4096))
* **editor:** edit an item without leaving the app ([3028802](https://github.com/rootless-dev/MyPasteApp/commit/30288025c331bb19321dcf2a25806c508221a9b3))
* **editor:** wrap NSTextView for SwiftUI ([69fc8a0](https://github.com/rootless-dev/MyPasteApp/commit/69fc8a00c1924659b7def8baa92707ade2728725))
* fase 1 do roadmap — ganhos rápidos ([2c8662b](https://github.com/rootless-dev/MyPasteApp/commit/2c8662bc36fdbe2d56427262eacf368884e5e797))
* **items:** create an item from scratch ([3d0b726](https://github.com/rootless-dev/MyPasteApp/commit/3d0b726f9aedf1bdd6553774e099cbf7a7cb478e))
* **items:** name an item and find it by that name ([890b07b](https://github.com/rootless-dev/MyPasteApp/commit/890b07b15fe34ec35da9f885f036fc058a2237e6))
* **menu:** timed pause with status bar feedback and its own hotkey ([cf68311](https://github.com/rootless-dev/MyPasteApp/commit/cf68311e4dd4f5e82824b2480b66fe3b498646c8))
* **monitor:** pause and resume clipboard capture ([107f30a](https://github.com/rootless-dev/MyPasteApp/commit/107f30afb2ed4d0b2cb16151a63d14dc56b3600c))
* **overlay:** add ⌘C copy shortcut and menu shortcut glyphs ([46af4ea](https://github.com/rootless-dev/MyPasteApp/commit/46af4ead10dd526fede39a6d6d13ba495a02a5ca))
* **overlay:** add a context menu to the card ([97e267f](https://github.com/rootless-dev/MyPasteApp/commit/97e267ff76fa1fba30f3349f3c7240df7393cc26))
* **overlay:** quick paste with ⌘1–⌘9 ([c31bb5e](https://github.com/rootless-dev/MyPasteApp/commit/c31bb5e6bea3aa096d73db1694c9a411d93e7840))
* **paste:** paste formatted text, with ⇧ for plain ([8ae8071](https://github.com/rootless-dev/MyPasteApp/commit/8ae8071a7b411e4c586fa6b3447f09ae46aa2ac9))
* **preview:** let Space close the panel it opened ([951e083](https://github.com/rootless-dev/MyPasteApp/commit/951e0830e894df531fda07b97f060541b57bb439))
* **preview:** open with Space, close with Escape ([081f4ce](https://github.com/rootless-dev/MyPasteApp/commit/081f4cec7b23488af4c64d6be792aec035c135e2))
* **preview:** show the full item in an anchored panel ([abeb65f](https://github.com/rootless-dev/MyPasteApp/commit/abeb65f5b2044b7fab8957ae9c6e49fcd7bba595))
* **privacy:** hide windows from screen sharing ([e0f6eba](https://github.com/rootless-dev/MyPasteApp/commit/e0f6eba0fe73065b778635b54f3fee417533b578))
* **privacy:** skip concealed and transient pasteboard content ([807dfac](https://github.com/rootless-dev/MyPasteApp/commit/807dfacf47e8045873df60540d5ca0274bb31f26))
* **retention:** add the named stops of the retention slider ([769e024](https://github.com/rootless-dev/MyPasteApp/commit/769e024804aebc390a42d1dc929c3b266c9abaf7))
* **retention:** let the history be kept forever ([8fe59e1](https://github.com/rootless-dev/MyPasteApp/commit/8fe59e16023b0de9e24a0247d69aac2c5a896387))
* **richtext:** decide what goes on the pasteboard when pasting ([1c58fa5](https://github.com/rootless-dev/MyPasteApp/commit/1c58fa5898b5aa729375001c58c1d806d71bd9b6))
* **richtext:** pick which rich format to keep from the pasteboard ([1418691](https://github.com/rootless-dev/MyPasteApp/commit/1418691e5d39a2d4e90399f8a83641af32bcfec0))
* **settings:** move general, history and appearance into the sidebar ([f8c0743](https://github.com/rootless-dev/MyPasteApp/commit/f8c074309025d0ea95ff78240dcfce77904f681b))
* **settings:** move shortcuts and privacy over, drop the old view ([2a90928](https://github.com/rootless-dev/MyPasteApp/commit/2a909286381cd57c15140ec242ec62201fb99ef0))
* **settings:** rebuild the window around a sidebar ([6f4210d](https://github.com/rootless-dev/MyPasteApp/commit/6f4210d9dd4b8683ec1457fa8c30d71a1f432e04))


### Bug Fixes

* **appdelegate:** skip pause hotkey on launch conflict; menu/window fixes ([0cadd72](https://github.com/rootless-dev/MyPasteApp/commit/0cadd725d2a601316c16146711315950343df0fe))
* **editor:** decode rich text by its stored format, not always as RTF ([e5712ee](https://github.com/rootless-dev/MyPasteApp/commit/e5712ee9186af0b6e54c7ef99fd9c67e5b29696d))
* **hotkeys:** re-check both shortcuts on any hotkey change, hide dead one from menu ([dbf8841](https://github.com/rootless-dev/MyPasteApp/commit/dbf884152b98c0e266ab2d4930e5ab570abaea8d))
* **hotkeys:** report registration failures to the caller ([aaa2278](https://github.com/rootless-dev/MyPasteApp/commit/aaa227823864e7e2cd8d88f5e34958efce57fb11))
* **menu:** hide the overlay shortcut when it isn't registered ([bd62fe4](https://github.com/rootless-dev/MyPasteApp/commit/bd62fe4e56b45b8f5a6050dbfe7e5e404bf08d2f))
* **menu:** honor "always paste plain text" in the context menu's Paste entry ([95358fd](https://github.com/rootless-dev/MyPasteApp/commit/95358fdc1ed88fcdaedcf0839b9531199e5d9d89))
* **overlay:** let the panel receive keyboard input at all ([1317143](https://github.com/rootless-dev/MyPasteApp/commit/1317143e3af45eb763b6fd5a986f62bc8f6c0b30))
* **paste:** stop quick paste from leaking global shift into plain text ([58099a4](https://github.com/rootless-dev/MyPasteApp/commit/58099a465094a81e39b5e341464a15bd82b6bd55))
* **pause:** stale timer no longer overrides a newer pause ([6a8706a](https://github.com/rootless-dev/MyPasteApp/commit/6a8706a74a9857e10107d7df06eeeb142835b7d6))
* **preferences:** un-stick hotkey banner; drop fragile revert flag; resizable frame ([f969780](https://github.com/rootless-dev/MyPasteApp/commit/f96978095da0eef66a181329cef4d3e17dbd81b2))
* **preview:** scale images to fit the panel instead of showing them full size ([b8c7e7e](https://github.com/rootless-dev/MyPasteApp/commit/b8c7e7ea712ab5b12d4f69434dbb2480e6877a72))
* **preview:** stop rebuilding the preview panel on every scroll frame ([0a40219](https://github.com/rootless-dev/MyPasteApp/commit/0a402193d073e226e7975de022f209265db89579))
* **spike:** make the preview panel actually reachable and sized ([b02177c](https://github.com/rootless-dev/MyPasteApp/commit/b02177c8efd28681be26209b4348ed6c547d2365))


### Refactoring

* **hotkey:** support more than one global hotkey ([f28ab5c](https://github.com/rootless-dev/MyPasteApp/commit/f28ab5ca99e9accfc1f55abbecbc7ef56c9ce450))
* **overlay:** move item actions out of the view ([2a4b16f](https://github.com/rootless-dev/MyPasteApp/commit/2a4b16f29625723dfbb099cce7ee55dbb37fadcc))
* **preferences:** centralize UserDefaults keys in one type ([fc07fc7](https://github.com/rootless-dev/MyPasteApp/commit/fc07fc75f868eebcbd8bb5b7ef4abb4c9e0fd491))


### Documentation

* **clipboard-monitor:** restore the lastChangeCount ordering rationale ([303a5ac](https://github.com/rootless-dev/MyPasteApp/commit/303a5acdbbf4b3c9276e8fe1aee775db02518ae6))
* **privacy:** say which apps the pasteboard markers don't cover ([bc5705f](https://github.com/rootless-dev/MyPasteApp/commit/bc5705f49222e93cac2149cedd2ee77a511a4555))
* spec and implementation plan for roadmap phase 1 ([71adfb6](https://github.com/rootless-dev/MyPasteApp/commit/71adfb6163baf8a0a61adad3099288d3782b553d))
* spec and implementation plan for roadmap phase 2 ([7aaa563](https://github.com/rootless-dev/MyPasteApp/commit/7aaa563973664974f7f32e745d993e24b90e587c))

## [1.1.0](https://github.com/rootless-dev/MyPasteApp/compare/v1.0.0...v1.1.0) (2026-07-30)


### Features

* add dynamic footer with type-specific metadata to clipboard tiles ([b511d65](https://github.com/rootless-dev/MyPasteApp/commit/b511d65e5d7fd2c38c7e38fdd4828eb12ff909c7))
* delete a history item from its card ([448edc6](https://github.com/rootless-dev/MyPasteApp/commit/448edc660b691fbbdf174abc8e5789f8e694b352))
* initial clipboard manager MVP ([9348df0](https://github.com/rootless-dev/MyPasteApp/commit/9348df0be759ba765e076d4a7e2fa83ae10f194e))
* left/right click status item and auto-hide overlay on outside click ([9f4111f](https://github.com/rootless-dev/MyPasteApp/commit/9f4111fbcd50f55f0c0f27c6628ef8cfecb70d5c))
* play sound feedback when new clipboard item is captured ([35bfcac](https://github.com/rootless-dev/MyPasteApp/commit/35bfcac085e9409ef83f27ca924348349a8bf564))
* promote clicked tile to top and keep overlay open ([ad58a00](https://github.com/rootless-dev/MyPasteApp/commit/ad58a0079ff21144aec1d2bf01a768e7c1936cf6))
* redesign clipboard tiles with Paste-style colored header ([4e108ce](https://github.com/rootless-dev/MyPasteApp/commit/4e108ced4f57a97e71ae5b76d7704a0f7a9e32d9))
* rich type-specific previews for files and links ([b71e251](https://github.com/rootless-dev/MyPasteApp/commit/b71e251c91c57f987e886455b8161935d29b1517))
* user preferences, unit test target and per-card delete ([1971cf3](https://github.com/rootless-dev/MyPasteApp/commit/1971cf3f21ab592558c56703f2a3a65bf2dc0439))
* user-configurable preferences for hotkey, paste, privacy and layout ([f11d65c](https://github.com/rootless-dev/MyPasteApp/commit/f11d65cfe5d54ab9dcf6540c6b87ec002b420486))


### Bug Fixes

* clip overlay scroll content to rounded window shape ([4a85065](https://github.com/rootless-dev/MyPasteApp/commit/4a8506581501bf511eab0af1d071dcb555b56082))
* prevent overlay teleport across displays in multi-monitor setups ([c6a79ca](https://github.com/rootless-dev/MyPasteApp/commit/c6a79ca3fba2881eda808dc5af5a2fc9f58d1471))
* render image thumbnails for file-type clipboard tiles ([0acf583](https://github.com/rootless-dev/MyPasteApp/commit/0acf58379cf4b8328bcaf4df7d24fbe009f11626))
* silence Swift 6 warnings in ClipboardMonitor and HotkeyManager ([4846e34](https://github.com/rootless-dev/MyPasteApp/commit/4846e34bfca4290d62355b560c1c686cd1024bd9))


### Performance

* smoother overlay slide-up with spring, rasterization and prewarm ([f26ede0](https://github.com/rootless-dev/MyPasteApp/commit/f26ede0857d25000c8b285776809db71b5f3c2e5))


### Documentation

* add README and MIT LICENSE, translate code to English ([de32179](https://github.com/rootless-dev/MyPasteApp/commit/de32179c6cd1cdd83ba5824493d92c261125e263))
