# Demo modules

One section per module in `StemJSON/Sources/StemJSON/Resources/`. Each names what the module demonstrates, what's out of scope, and any external setup required.

Modules are registered in `StemJSON/Sources/StemJSON/JSONCatalog.swift`; the showcase apps pick them up from there.

---

## hello

The smallest possible StemJSON module: a title that greets a name from state, and a textfield that edits the name. Under 30 lines.

**Demonstrates**

- Module shape — `id`, `type: "module"`, `state`, `children`.
- Two-way state binding — textfield reads and writes `${name}`.
- Inline expression + string concatenation — `{{ 'Hello, ' + ${name} + '!' }}`.
- Nothing else. No events, no repos, no styling beyond font + layout.

**Setup.** None.

---

## booking

Restaurant reservation form. A single module, entirely modal.

**Demonstrates**

- Form + section layout — `form` component with grouped sections.
- Input components — `textfield`, `datepicker`, `picker`, `toggle`.
- `conditional` component — swaps UI between the booking form and the confirmation view.
- `condition` action — branches on whether required fields are filled before confirming.
- Modal pattern — host observes `onClose`, module self-dismisses.
- System literals — `#{today}`, `#{tomorrow}` drive the date picker's allowed range.

**Not covered.** No network. No localization.

**Setup.** None.

---

## calculator

Three-tab utility: arithmetic calculator, tip calculator, unit converter. Each tab is a `module` sub-tree.

**Demonstrates**

- Tab-based root — top-level `tab` component with three child modules.
- Templates and dependency components (`dp://`) — heavy use of reusable button definitions to keep the keypad concise.
- Context parameters — template consumers pass style knobs (`fg`, `bg`, `fs`, `lbl`, `op`) as context into the reusable button.
- `cast()` expression function — converts textfield strings to doubles for arithmetic.
- `??` null-coalesce operator — for safe defaults on empty input.
- Numeric keyboards — `decimalPad` textfields with scroll-based dismissal (`style.scroll.dismissesKeyboard`, see spec §7.16).
- Live computed state — tip and total amounts derived from expressions in `_text`.

**Not covered.** No navigation. No network.

**Setup.** None.

---

## gallery

Device photo browser with favorites. The `+` opens the native photo picker; double-tapping an image toggles its favorite status.

**Demonstrates**

- Photos repository — spec §5.3 "photo library" kind. Pull images out of the device library via a repo action, store resulting URLs in state.
- `onDoubleTap` event — on each grid cell to toggle favorites. Coexists with single-tap; the runtime disambiguates.
- `grid` component — adaptive columns via `style.grid`.
- `dynamic` + `conditional` — each cell renders a heart overlay when the image is in the favorites set.
- `~` contains operator — `${favorites} ~ @{item}` checks set membership against the current item.
- `zstack` — layering the heart overlay on top of the image.
- Empty state — `conditional` renders an instructional view when no photos have been imported.

**Not covered.** No persistence across launches (favorites live in module state only).

**Setup.** Grants Photos read permission on first use. No external service.

---

## messenger

Real-time chat backed by Firebase Firestore. The heaviest module in the repo — demonstrates most of the DSL's service and dependency surface.

**Demonstrates**

- Firebase repository kind — collection read / write / live subscription.
- `listen` action — streams new messages in real time; updates module state on each delivery.
- Secured repository — Firebase project ID / API key live in the iOS keychain, not the JSON.
- `service` actions — audio (message-received chime), haptic (send confirmation), push notification (message preview).
- Bubble shape component — styled outgoing / incoming message bubbles.
- `onCustom` event — module's `firebaseReady` custom event; fires after async service bootstrap.
- Modal sheet — settings presented via `style.modal.sheet`.
- System literals — `#{user}` (device-vendor ID) and `#{now}` (message timestamps).
- Scroll auto-anchor — new messages scroll into view via `style.scroll.anchor`.

**Setup.**

1. Create a Firebase project at https://console.firebase.google.com.
2. Drop the generated `GoogleService-Info.plist` into `StemSwiftUI/StemSwiftUI/` (it is `.gitignore`d).
3. Enable Firestore; open the rules for testing.
4. Launch the showcase app, open the messenger demo, paste your project ID + API key into the settings sheet. Stored to the keychain via the secured repo.

Without steps 1–3, the module still renders — the settings sheet points you at the missing configuration.

---

## shop

Product catalog against a live REST API with offline fallback. Demonstrates the read-through caching pattern.

**Demonstrates**

- Remote repository — `GET https://dummyjson.com/products`, no auth.
- Local repository — products cached locally; read order is local-first, then network, then state update.
- Search-as-you-type — `onChange` on a textfield drives a **path-level filter predicate** `${web[title ~ ${search}]}` (spec §6.2.1).
- Pull-to-refresh — `onRefresh` event on the list wired to the remote repo action.
- Swipe actions — `style.swipe.trailing` with an `allowsFullSwipe` delete.
- Skeleton loading — `_isLoading` on `dynamic` shows skeleton rows while the first fetch runs.
- Navigation — embedded navigation via `link` to a product detail screen.
- `interval` action — ephemeral toast dismissed after a few seconds.

**Setup.** None. `dummyjson.com` is public.

---

## weather

City search + weather forecast using two chained public APIs.

**Demonstrates**

- Two remote repositories in one module — Open-Meteo's geocoding endpoint, then its forecast endpoint.
- Action chaining via `output.success` — the geocoding result is fed into the forecast request.
- Debounced `onChange` — the search textfield uses `_debounce: 0.3` so typing doesn't flood requests.
- Embedded navigation — tapping a city pushes a detail screen inside the host's nav stack.
- Date + number formatters — `_format` descriptors on `text` for daily high/low, sunrise/sunset, humidity %.
- `format()` function — inline expression-level formatting.
- `style.scroll.dismissesKeyboard` — keyboard dismisses on scroll.
- `onChange` re-fetch — toggling `°C / °F` in the detail view refires the forecast request with the new unit.

**Setup.** None. Open-Meteo is public.

---

## skeletons

Loading-state showcase. Every input and output component rendered twice — real content and skeleton — with a global toggle to flip between them.

**Demonstrates**

- `_isLoading` context key — uniform API for skeleton rendering across `text`, `image`, `textfield`, `texteditor`, `toggle`, `picker`, `slider`, `datepicker`, `progress`, `label`, `button`, and `dynamic` rows.
- Adaptive skeletons — shapes match the final content's layout (circle for avatars, pill for tags, multi-line block for paragraphs).
- Global state toggle — one boolean flips every skeleton on the screen.
- Shimmer animation — the SDK's built-in shimmer, no JSON animation wiring required.
- `onFocus` / `onBlur` events — attached to the textfield with a live focus-event counter below it.

Copy any cell into your own feature, swap the source context, and the skeleton is ready.

**Setup.** None.

---

## instagram (.zip package)

Instagram-style feed with photo + video posts from the Pexels API. Packaged as a ZIP module to demonstrate StemJSON's distribution format.

```
instagram.zip
├── main.json
├── assets/
│   └── instagram_stem.png
└── localization/
    ├── en.strings
    └── uk.strings
```

**Demonstrates**

- ZIP packaging — the spec's §14.1 distribution format.
- Localization — every display string is a `l10n://ig.*` source; `en.strings` and `uk.strings` live inside the package.
- `localize()` function — used when a single source string isn't enough, e.g. `${liked} ? localize('ig.liked.you', 'Liked by you') : localize('ig.liked.others', 'Liked by others')`.
- Secured repository — the user's Pexels API key is stored in the keychain.
- Mixed photo + video feed — two `dynamic` lists with different prototypes.
- Like toggles and heart animations — state-driven UI.

**Setup**

1. Get a free API key at https://www.pexels.com/api.
2. Launch the module, paste the key into the setup sheet. Stored securely in your device keychain.

Without a key the module renders a "connect" screen with instructions.

---

## recipes (.zip package)

Recipe cards with localized content and embedded navigation. Companion to `instagram.zip` — shows the distribution format with heavy l10n.

```
recipes.zip
├── main.json
├── <nested recipe JSONs>
├── assets/
└── localization/
    ├── en.strings
    └── uk.strings
```

**Demonstrates**

- `.navigationEmbedded()` rendering — recipe detail pushes onto the host's `NavigationStack`; back button works natively.
- `file://` navigation destinations — each recipe is a separate packaged JSON, pushed by id via `navigate` with `source: "file://<name>.json"`.
- Heavy `l10n://` usage — titles, ingredient lists, step-by-step instructions are all localization keys; every recipe renders in the active locale.
- `list` component with sections — ingredient sections grouped by kind.
- `media` component — hero image with caption overlay.

**Setup.** None. Localization swaps based on device language (en / uk).

---

## functions

Live reference for every built-in function in the StemJSON expression language (spec §8.6). Each card edits a state value on the left and shows one or more functions applied to it on the right.

**Demonstrates**

- String transforms — `upper`, `lower`, `trim`, `replace`, `prefix`, `suffix`.
- Inspection — `count`, `length`, `empty`, `notEmpty`, `hasPrefix`, `hasSuffix`, `contains`.
- Collections — `sort` (asc + desc + by key), `first`, `last`, `min`, `max`, `sum`, `map`.
- Data transforms — `strtojson`, `cast`, the `|>` pipe operator.
- Postfix member access — `strtojson(...).name`, `strtojson(...).tags`.
- `_debug` overlay — the last card sets `_debug: { "context": "_text" }` and explains what that surfaces in the console.

Use this as a live sandbox to check what any built-in actually returns for your inputs.

**Setup.** None.

---

## system

Live readout of every StemJSON system literal (spec §6.3 — the `#{…}` form). Each row names the literal, describes what it returns, and shows its current value.

**Demonstrates**

- Date literals — `#{now}`, `#{today}`, `#{yesterday}`, `#{tomorrow}`, `#{endofweek}`, `#{startofmonth}`, `#{endofmonth}`.
- Locale / region literals — `#{locale}`, `#{language}`, `#{currency}`, `#{timezone}`.
- Device literals — `#{device_type}`, `#{device}`, `#{systemname}`, `#{systemversion}`, `#{user}`.
- UI-context literals — `#{orientation}`, `#{horizontal_size_class}`, `#{is_split_view}`. Values change when you rotate the device or enter Split View on iPad.

**Setup.** None. Launch on iPad to see the Split View / size-class rows vary.

---

## media

Heavy-media components in one module: `video`, `pdf`, `map`, and the universal `media` viewer. The map card doubles as a demo of extending StemJSON with a host-registered external service.

**Demonstrates**

- `video` component — looping, muted, with controls, backed by AVKit.
- `pdf` component — opens full-screen in a pushed detail view via `link` + embedded navigation.
- `map` component — interactive MapKit view with a custom pin annotation, two-way `_position` and `_region` bindings, and a "Use my location" button that fetches device coordinates via an external `LocationService`, then rewrites both the camera and the pin.
- `media` component — universal viewer that inspects the URL extension (or `_kind` override) and delegates to image / video / pdf.
- `style.video`, `style.pdf`, `style.map` — three style blocks that only apply to media components.
- **External service extensibility** — `LocationService` lives in `StemDependencies` (not in StemRuntimeSDK). Each host registers it at startup via `.register(LocationService.self, as: AppServiceType.location)`. The module declares the service as a dependency and invokes it through a `service` action; the return payload (`{latitude, longitude, altitude, accuracy, timestamp}`) flows into state. This is the canonical pattern for adding native capabilities to StemJSON that the SDK doesn't ship.

**Setup.**

- All sample URLs are public, no API keys required.
- The "Use my location" button prompts for location permission on first tap. Host apps already declare `NSLocationWhenInUseUsageDescription` in their Info.plist. If the user denies, an error is surfaced inline.

---

## splitview

Two-column iPad layout using `splitview` (spec §4.5). Sidebar with a selectable list; detail pane with a profile card for the selected row.

**Demonstrates**

- `splitview` component — positional children: `children[0]` sidebar, `children[1]` detail. Runtime infers two- vs three-column from children count.
- `style.splitView` — `preferred: "balanced"`, explicit `sidebarWidth: { min, ideal, max }`.
- `_columnVisibility: "automatic"` — collapses to single column on iPhone / Slide Over, keeps both panes on iPad regular width.
- Navigation titles per column — `style.navigation.navigationTitle` on sidebar and detail, with the detail title driven live off the selected row's name.
- Filter predicate in path — the detail pane reads `first(${items[id ~ ${selectedId}]})` to pluck the selected record.
- Active-row highlight — each row's background is a ternary on `${selectedId} == @{item.id}`.
- Close button in sidebar's `toolbarTrailing` — iOS-standard placement for a modal split view.

**Setup.** None. Launch on an iPad or iPad simulator for the two-column behavior.
