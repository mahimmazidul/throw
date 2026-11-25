# Changelog

All notable changes to Throw are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.6] — 2026-11-26

The row that asks you to accept an incoming connection was broken on a phone.
It is a 360dp-wide window and the row needed 464.

### Fixed — the accept row overflowed off the screen

The name and both buttons were on one line. The buttons lived in `FlatRow`'s
trailing slot, which caps itself at 40% of the window — 144dp on a 360dp phone —
while "Reject" and "Accept" together need roughly 248. The row overflowed by
104dp: **Accept was pushed off the right edge entirely** and Reject was clipped
into it, with the debug build's striped overflow marker drawn over both. That is
the "no name nothing" row — the label was there, off-screen, and what remained
visible was two clipped fragments of button.

The name now has its own full-width line and may wrap to two, and the buttons sit
below it, right-aligned. There is no width at which "Reject" and "Accept" belong
on the same line as a device name on a phone, so they no longer try.

Widths are now checked rather than assumed: `connection_request_layout_test.dart`
renders the row at 360dp and fails on any overflow, asserts both labels are
inside the window bounds, and covers a nameless peer (which gets a short token
such as "Nearby device · 1122" rather than a blank or a raw UUID).
`narrow_layout_test.dart` sweeps Home, Discover and Transfers at 360dp and 392dp
so the same class of bug cannot appear on another screen unnoticed.

### Fixed — the depth button had no Material ancestor

`DepthButton` renders a `FilledButton`, which is ink-aware and requires a
`Material` above it. It only worked because every call site happened to sit under
a `Scaffold`; rendering a button on its own failed with "No Material widget
found". It now owns a transparent `Material`, which also scopes the ink splash to
the button so a splash can never paint outside its own pill.

## [1.3.5] — 2026-11-26

Discovery was listing the same phone twice and could sit spinning with a red
"Scanning failed" banner at the same time. The UI was fine; the state machine
underneath it was not.

### Fixed — one phone is one row again

An endpoint id is a WiFi Direct P2P address, and one phone can advertise on more
than one — a second network interface, a stale session that was never torn down,
or a re-advertise after its group formed. Devices were keyed by endpoint id, so
each address became its own row: the same phone listed twice, each copy with its
own **Connect** button, and picking either one was a coin toss over which address
was actually live.

Rows now match on the advertised device name, which is what a person uses to tell
two phones apart anyway. The newest endpoint wins, because its address is the one
that reported most recently, and a row that was already connected stays connected
through the collapse — dropping that silently disconnected the device someone was
about to send to. Two different phones with different names still get two rows,
and nameless peers never merge, since matching those would fold unrelated devices
together.

### Fixed — "scanning" and "scanning failed" can no longer both be true

`stopDiscovery()` cleared the scanning flag only if the native call *succeeded*.
When it threw — which WiFi Direct does when the radio is busy — the flag stayed
`true`, so the screen kept advertising "Scanning… keep Throw open on both
devices" while a red "Scanning for devices failed" banner appeared underneath it
and the switch visibly read off. Three statements contradicting each other, from
one `catch` block with no `finally`. The flag is now cleared regardless, and
stopping no longer raises an error at all: the scan is over either way, and a
complaint about tearing down the radio is not something anyone can act on.
`stopAdvertising()` had the identical bug and got the identical fix.

### Fixed — the scan is re-armed when it dies

Android stops WiFi Direct discovery on its own: when the app goes to the
background, when another app takes the radio, when a connection tears the group
down. The plugin reports endpoints appearing and disappearing but **never** that
discovery itself stopped, and Throw had no lifecycle handling at all. So the app
went on believing it was scanning while the radio did nothing — the forever
"Scanning…" with zero results, cured only by toggling the switch by hand.

Two things now re-arm it:

* **On resume.** Returning to the foreground restarts whichever of advertising
  and discovery the user had switched on, and only those — a scan that was
  switched off stays off.
* **On a watchdog.** A self-rescheduling timer re-issues the scan every 20
  seconds while one is meant to be running. `startDiscovery` is idempotent at the
  plugin level, so a healthy scan is unaffected, while a dead one recovers
  without the user knowing anything happened. The watchdog never raises a banner:
  a background retry is not a user action.

### Fixed — a 3-second stall on the first advertise

`resolvedDeviceName()` awaited the name lookup whenever it was still pending,
including before the lookup had even started, so the first advertise could wait
out the full three-second timeout for nothing. It now returns immediately when
there is no lookup in flight. Two smaller things surfaced with it: constructing
the provider threw outright when no Flutter binding existed, which made it
impossible to unit-test, and the watchdog's `Timer.periodic` outlived the object
that owned it — it is now a self-rescheduling one-shot that stops when the scan
stops.

## [1.3.4] — 2026-11-25

The swipe was re-creating every tab three times a change, which is why the text
appeared to fall into place two or three times over itself. The release page
buried its own downloads under half a thousand lines. And the buttons were flat
rectangles that only changed colour.

### Fixed — the swipe no longer rebuilds the app

Every screen in the tab strip was being destroyed and rebuilt **three times per
tab change**. The motion was fine; the content underneath it was restarting from
scratch, so the staggered entrance fade replayed twice or three times while a
screen was sliding, and the text visibly dropped into place over and over. Worse
for anyone mid-task: a scan in progress, a typed draft, a scroll position — all
of it was thrown away on every swipe, even though this widget exists specifically
to keep tabs alive.

The cause was structural. The transition was assembled from two separate stacks,
one per screen on stage, so a tab lived at a different position in the widget
tree depending on what the transition was doing. Flutter cannot move an element
between positions; when the type or position at a slot changes it discards the
subtree and builds a new one. Each swipe moved every tab once on the way in and
once on the way out.

Now all tabs are built in one stack, in index order, every frame — the same
children at the same positions, whatever is moving. Only visibility and
translation change. A tab mounts once and stays mounted until the app closes.
Two tests in `tab_lifecycle_test.dart` assert the count directly: a tab's state
must be created exactly once across a walk through all four tabs and back, and a
tab must still show its original contents when the user returns to it.

### Fixed — the download page is a download page again

The release body was the entire CHANGELOG: 530 lines, 26,757 characters, every
change since 1.0. Getting to the actual files meant scrolling past all of it.

`tool/release_notes.py` now extracts only the current version's section and
writes it with a one-line header pointing at the downloads. The v1.3.4 page is
that section, and nothing else.

### Fixed — the site updates on every release again

The site sat on v1.0.15 through a dozen releases while every build was green.
There were two separate causes, and the first one was not the interesting one.

*A `500` is not a decision.* The last deploy attempt died on `Failed to create
deployment (status: 500)` from the Pages service during an outage, and the
workflow treated that as final. It now retries once and fails the run if both
attempts fail, so a stale site is red instead of silent.

*The deploy was never asked for.* Underneath that: GitHub does not start
workflows for a push made with `GITHUB_TOKEN`, to stop loops. The release job
pushes its own docs commit, so `Deploy Pages` — which triggers on `paths:
docs/**` — has never once been triggered by a release. Every deploy to date was
someone running it by hand. Retrying the *deployment* cannot fix a run that does
not exist, so the release job now asks for the run explicitly and the site is
current.

### Added — filled buttons have depth

Borrowed from `taka`, the reference app: a two-stop gradient fill and a soft
shadow tinted with the button's own colour rather than black.

The palette documented "no gradient, no glow, no tinted elevation". That rule was
written about *surfaces* — the radiant background washes the home and discover
headers used to carry — and applying it to the control in your hand was the wrong
reading. The doc now says so explicitly: the page stays flat, the things on it
have depth. The gradient is tonal, two cuts of the app's own moss, and lives
inside the button's own bounds, so nothing radiates onto the page.

It is deliberately narrow rather than a showy ramp, and the range is checked
instead of assumed. The first attempt used a top stop of `#14887C`, which
measured **4.13:1** against the button's white label — below AA, on the largest
control in the app. My own comment claimed every stop cleared 4.5:1; the test
said otherwise, so the range was narrowed. It now runs 4.89 / 6.12 / 8.35 in dark
mode and 5.32 / 6.42 / 8.80 in light, and `depth_test.dart` recomputes every stop
in both themes so it cannot drift below AA later.

A disabled button drops its shadow and takes a muted surface for the theme in
play — the first version fell back to the dark surface in light mode and painted
a near-black pill on sage paper.

## [1.3.3] — 2026-11-25

The tab change was still wrong, the update check could hang forever on a working
network, and a release could publish with no assets and still be marked failed.

### Changed — the tab change is now a moving pair, like iOS

Two failed attempts preceded this one, in opposite directions. The first slid the
incoming screen across the whole window — "it overlays the whole second screen".
The second dissolved the two screens in place, which put both screens' text at
partial opacity in the same place — the "transparent, overlapping" complaint,
arrived at from the other side.

Neither is what a tab change wants. The two screens now move **together as one
rigid pair**: the outgoing tab is pushed out along the axis of travel while the
incoming tab arrives from the opposite edge, always exactly one window width
apart, with nothing fading. The boundary sweeps across and no two pieces of text
are ever legible in the same place. This is the `UIPageViewController` scroll
transition, which is what "make it like iOS" describes.

A test asserts the invariant directly: mid-transition the two screens must be
one window width apart (the rejected cross-fade measured **0.0 px**).

### Fixed — the update check could hang forever on a connected network

`client.connectionTimeout` covers only the TCP handshake. Once connected, reading
the response had **no deadline at all**, so on a slow or captive network — a
hotel portal, a tether, mobile data that accepted the connection and then went
quiet — the spinner never stopped. That is "update is broken even when
connected".

The check is now a testable `UpdateService` instead of forty lines inside the
settings screen:

* a deadline wraps the **whole** exchange, not just the connect — reproduced in
  a test with a client that opens a connection and never answers; without the
  fix that test hangs until the runner kills it;
* transient faults (5xx, 429, timeouts) are retried three times with backoff —
  GitHub's API 502'd during this project's own release, so a single blip being
  reported as a permanent defect was always wrong;
* a 404 and an unreadable body are *not* retried, and a tag that is not a
  version is rejected rather than silently read as "up to date" forever;
* offline is reported as offline, once — an answer, not a failure.

The error copy is unchanged: `AppError` and its classifications still stand, and
the new service maps onto them, so an offline check reads exactly as it did.

### Changed — presses spring like an iOS control

`Pressable` used one duration and one curve for both directions, which is why the
feedback read as a colour flicker. The press now lands in 90 ms and the release
springs back over 260 ms with a slight overshoot past 1.0, and the press scale
deepens from 0.97 to 0.955. Navigation icons grow 8% when selected instead of
hard-cutting between two glyphs.

### Fixed — a release could publish with zero assets and still read as failed

v1.3.2's `Create Release` died on `Error 502: Server Error` after creating the
release, leaving it with no downloadable files, and the re-run then failed
because the release already existed. The step now uses `allowUpdates` so it can
update an existing release in place, retries asset uploads five times, and a new
job asserts the number of published assets equals the number built — so a silent
partial release fails loudly instead of shipping nothing.

## [1.3.2] — 2026-11-24

The tab change was a full-screen slide, and it stuttered on release. It is now
a transition: a short directional ease with a staggered dissolve.

### Changed — swiping slides a whole screen, and it should not

Requested plainly: *"swipe ain't smooth, it overlays the whole second screen,
just make it like transition rather than whole swiping."* The incoming tab
arrived translated from a full screen width away, so every pixel of one screen
travelled over every pixel of the other — a page-turn, not a tab change. On a
wide window that is a long way to watch for something as small as moving one tab
to the right.

The outgoing tab now eases back 28 px, dims to 58% and settles; the incoming tab
arrives from a 34 px offset in the direction of travel, on a faster easing curve
than its own fade so it settles almost at once and the rest of the move is pure
dissolve. Measured: the incoming screen travels **34 px of an 800 px window** and
is in place within 200 ms, versus a full 800 px before. The gesture still drives
it — a drag cross-dissolves under the finger — but the travel never exceeds a
short nudge regardless of how far the finger goes.

### Fixed — the transition jumped backwards when the finger lifted

On a committed drag the animation restarted with `forward(from: 0)`, snapping
the incoming screen from wherever the gesture had taken it (57.9% opacity in the
measured case) all the way back to **0.0** — fully transparent, off its offset —
and then replayed the entire move. That backwards jump is what read as "not
smooth". Progress is now carried from the gesture into the animation, so release
continues from under the finger.

The commit threshold drops from 28% of the width to 18% (a modest flick), since
the transition no longer needs a screen's worth of travel to feel deliberate.

## [1.3.1] — 2026-11-24

Three defects in the v1.3.0 motion layer, all found by using the app rather than
by running its tests. One of them — the swipe showing the wrong screen — was
introduced while fixing the first two.

### Fixed — swiping left or right made the whole app look transparent

Every screen paints onto a clear canvas: the ambient backdrop is a translucent
layer and the page itself has no background, so a tab only *looked* opaque
because it sat directly on the shell's `Scaffold`. The swipe stacked two tabs
and faded the outgoing one to 28% opacity, which meant both layers were
see-through at once and the window showed through both. It read as the app
going transparent, with two screens' text legibly overlapping.

Tabs are now backed by the canvas colour inside the transition, so "in front"
means something, and the outgoing screen is no longer faded at all — a slide
between two opaque surfaces needs no cross-fade.

### Fixed — the next screen did not appear until the finger was lifted

The owner is only told about a tab change on drag *release*, so during a live
drag `index` still pointed at the current tab and the incoming screen was never
built. A swipe produced no visual feedback whatsoever until it was let go. The
incoming screen is now inferred from the gesture itself and slides in under the
finger.

### Fixed — a drag previewed the wrong screen from the wrong side

`_from` was set when a move started and never cleared when one finished, so it
stayed latched at a stale index. After the first completed move, every later
drag slid an unrelated screen in from the wrong edge. The transition now names
both of its ends and clears them on completion, with a test that moves 0→1 and
then asserts a fresh drag offers 2 (and, reversed, 0 again).

### Fixed — Discover pushed its text sideways and off the screen

The radar halo was a 220dp `CustomPaint` inside a `Row`'s 22dp leading slot, so
it reserved 220dp of width and shoved the row's title out of view — the text
"went sideways" exactly while discovery was running, because that is when the
halo animates. It is now painted through an `OverflowBox` inside a 22dp box:
the halo bleeds over the background as a glow and participates in no layout at
all. Verified by diffing glyph bounding boxes with discovery off and on —
`223x31+9+8` in both.

## [1.3.0] — 2026-11-25

Two transport bugs, an honesty pass on what the app tells you about its network,
and the motion layer the interface was missing.

### Fixed — text sent between desktop peers arrived as an unusable file

`BluetoothService.sendText` framed its text with `FrameEncoder.text` and then
handed that frame to `_writeAll`, which re-wraps whatever it is given in
`fileChunk` frames. The receiver therefore got a *file* whose body happened to
contain a text frame, and the decoder never emitted a `TextFrame`. Text sent
laptop-to-laptop was silently unreadable. It now writes the text frame once,
directly, and a regression test asserts that the double-wrapped byte stream
can never yield a text frame.

### Fixed — Bluetooth transfers were throttled by acknowledged writes

Every BLE write used `withResponse`: the sender stalled until the peripheral
acknowledged each packet before sending the next. At the 20-byte ATT payload a
stock phone negotiates, that is roughly 2–6 KB/s — a 5 MB photo took about
twenty minutes. Writes now use `withoutResponse`, which lets the stack send
back-to-back within a connection interval, with an automatic per-characteristic
fallback to acknowledged writes for peripherals that do not support it. This is
the single biggest throughput lever available without changing transports.

### Fixed — checking for updates online failure showed a raw exception

`updateFailed` was rendered as `l10n.updateFailed(e.toString())`, so a phone
with no connectivity showed `Could not check updates: SocketException: Failed
host lookup 'api.github.com'`. There is now an explicit `offline` classification
with a human message, and a detector that separates "no network" from a real
fault (a 404 from the releases API still reads as a fault — blaming the user's
connection for a broken release would be worse than saying nothing).

### Fixed — a desktop with no Bluetooth adapter raised an error on every launch

The BlueZ stack throws `Bad state: No element` out of `adapters.first` when the
machine has no radio, and that surfaced as a red "Scanning for devices failed"
banner on a perfectly healthy device. `AppErrorCode.noRadio` now covers it, is
not marked severe, does not offer a settings shortcut that cannot help, and
reads as a hardware fact rather than a failure. The empty-collection match is
scoped to discovery so an unrelated `.first` crash is still treated as a crash.

### Changed — honest speed figures, and the WiFi question answered in-app

"WiFi Direct · ~250 Mbps" was the PHY ceiling, not anything an app transfer
reaches; "Bluetooth · ~3 Mbps" was not either. Both now state a realistic range
and, more importantly, state that **no WiFi network is required and no hotspot
is created** — the single most-asked question about how this app connects.

### Added — swipe between tabs, with the buttons

The shell keeps tabs alive in a stack, so swiping that stack directly was not
possible. Swiping now slides the *incoming* screen over the outgoing one instead
of shifting all four in lockstep, which is what a `PageView` does and why it
feels loose with four tabs. Direction comes from the gesture, a small drag
springs back, the first and last tabs are inert at their edges, and vertical
drags are never claimed — lists still scroll.

### Added — the atmosphere layer

The app had motion only in response to touch, so a screen at rest was a still
image. Three primitives, taken from the project's own web page and rebuilt for
Flutter:

* **ambient drift** — two soft accent fields moving on long, unequal periods
  behind the canvas, so the surface reads as depth rather than a flat fill;
* **radar pulse** — expanding rings while discovery is actually running, which
  gives the one state with nothing to look at something to look at;
* **shimmer** — a light band sweeping an active transfer row, so "moving" is
  visible in peripheral vision without reading the percentage.

All three animate transform and opacity only (compositor work, never layout),
stop completely under the OS reduce-motion setting, and are switched off behind
content that needs to be read — ambient motion behind an error message is noise
competing with the message.

### Added — send a received file on to another app

Receiving a share is registered for any MIME type, but a file that arrived could
only be opened or its path copied. Every received item now also has a share
action, so a photo that came off a phone can go straight into a chat without
being hunted down in the filesystem first.

### Changed — the developer's location reads "Bangladesh"

It said "Khulna, Bangladesh". The request was for something broader; a person's
city in a shipped app is more detail than the About row needs.

### Tests

245 passing (up from 225). New coverage: the text-frame regression, offline and
no-radio classification with negative cases, ambient motion scheduling no frames
when disabled or when reduce-motion is on, swipe gestures committing in both
directions and springing back under threshold, edge tabs refusing to move,
vertical drags surviving, and press feedback scaling.

## [1.2.1] — 2026-11-24

Reported as "works but failed transfer consumes sender storage of app". It was
not the transfer — it was the copy the transfer was reading.

### The leak

Neither way of choosing a file gives Throw the file the user picked:

* the Android share sheet (`receive_sharing_intent`) copies the shared file into
  the app's cache directory before handing over a path — its own documentation
  says "All files are copied to a temp cache folder";
* the File Picker copies picks into `cacheDir/file_picker/<millis>/<name>` and
  exposes `clearTemporaryFiles()` for cleaning them up.

Throw never called either cleanup path. Every shared photo or picked file left a
second full-size copy in the app's cache for the life of the install, whether the
transfer succeeded, failed, was cancelled, or was never started. A phone that
shared a 200 MB video five times was a gigabyte down with nothing to show for it.
A failed transfer looked worse than a successful one only because the user was
also left with no file to show for the space.

### Fixed — copies are released at the end of every transfer

`TempFileRegistry` (`lib/core/temp_files.dart`) owns the copies. A path is
registered when a share or pick is accepted and deleted when the transfer that
needed it reaches **any** terminal state — completed, failed, cancelled or
rejected. There is deliberately no success-only branch to get wrong.

Ownership is reference-counted, which fixes two cases a naive delete would have
turned into data loss:

* sending one file to three devices: the first device to fail no longer deletes
  the bytes the other two are still streaming;
* the share inbox holding a file while the user picks a device: the send ending
  no longer pulls the file out from under the inbox that is still showing it.

### Safety — the user's own files are never touched

A path is only registered if it resolves inside a cache directory. The real
`DCIM/Camera/x.jpg` the desktop pickers return, or a file in Documents, can never
be deleted by this code path — deleting a user's original would be a far worse
bug than the leak it fixes. Paths that merely share the cache prefix
(`cache_backup/` next to `cache/`) are rejected too.

### Fixed — upgrading reclaims what earlier builds left behind

Whatever is still registered at launch is debris: nothing can be mid-transfer
before the process has started. Startup releases everything registered and
sweeps the picker's cache directory, so an install that leaked across several
versions gets its space back without clearing app data.

### Added — a Storage row in Settings

The fix is invisible by nature, so Settings now reports what Throw is holding in
temporary copies and offers to clear it. The honest steady state reads "Nothing
held"; a user who just lost a large file to a failed send can confirm the space
came back instead of taking it on faith.

### Tests

31 new tests (224 total, up from 193) cover the registry, the transfer provider
and the share inbox against a real filesystem: a failed send deletes its copy,
a successful one does too, a copy still being read survives, the user's original
is never deleted, a corrupt registry file is not fatal, and a restart reclaims
what a previous run stranded. Removing the release call turns six of them red,
which is how they were checked.

## [1.2.0] — 2026-11-24

Everything below came from using the built app and reporting what broke. The
common thread: the previous round made the UI *look* right, but several flows
had no answer at the end of them — a file arrived and you could not find it, a
phone appeared and you could not tell which one it was, a transfer ran and it
never said how fast.

### Fixed — transfer rows broke on narrow screens

`TransferProgressTile` laid its bottom line out as a `Row` with
`mainAxisAlignment: spaceBetween` and two unbounded `Text`s. At 320–360 dp the
peer string and the "12.4 MB / 51.1 MB" counter together exceeded the row, the
Row overflowed, and its children painted outside the card — the "name or size
goes outside the box" report.

The row is rebuilt as a flat list row: the title is inside an `Expanded` with
ellipsis, the counters sit in a `Wrap` so they break to a second line instead of
painting out of bounds, and the trailing slot is capped at 40% of the width.
`test/transfer_row_test.dart` renders it at 320, 360 and 411 dp with a
200-character file name and asserts no overflow.

### Added — transfer speed and time remaining

`AppUtils.formatSpeed` existed and was never called; `TransferModel` had no
rate at all. `TransferRateTracker` (`core/transfer_stats.dart`) keeps an
exponentially smoothed bytes/second over a short window and an ETA, with an
injectable clock. It clamps negative byte counts (a transport that restarts a
payload used to be able to produce a negative speed), folds samples taken under
250 ms instead of dividing by ~0, and refuses to show an ETA longer than twelve
hours.

Active rows show `2.4 MB/s · 25 s left`. Finished rows show the average over the
whole transfer, which is the number that means something once it is over.

### Fixed — the other phone showed "Throw", not the device name

Two independent causes:

1. `DeviceProvider` resolved the real device name in an async constructor task
   while `startAdvertising` could run first, so the advertisement carried the
   placeholder. Advertising and discovery now await the name, and renaming a
   device while visible re-advertises under the new name immediately.
2. BLE cannot tell the receiver anything about the sender's name before a
   connection exists. Peers are now named by a HELLO frame sent on connect and
   by a `from` field carried on every payload, and a name learned that way is
   never overwritten by a later nameless discovery event.

Any peer that still has no name is rendered as `Nearby device · A1B2` — the
last four hex characters of its address — instead of a 36-character UUID.

### Fixed — "received, but saved where?"

Both services wrote into `getApplicationDocumentsDirectory()`. On Android that
is `/data/user/0/<package>/app_flutter`: a directory no file manager can open
without root. Files arrived, the list said "received", and there was no route to
the file.

`IncomingStore` now probes for a folder the user can actually reach — public
`Downloads/Throw` first, then an external-storage root, then the app folder as a
last resort — and only announces one it has written a probe file into. Every
receipt states its folder and offers open / copy-location, the Transfers list
shows the folder on finished rows, and the empty state names the folder before
anything has arrived, so the answer exists in advance.

A second file with the same name is saved as `IMG_0001 (1).jpg` rather than
silently replacing the first.

### Added — send to several devices at once

Selection was a single nullable device. Home now selects any number of
connected devices and `TransferProvider.sendTextTo` / `sendFileTo` fan out, one
transfer per device, so each has its own progress and its own failure. One
unreachable phone reports on its own row and does not abort the other two.

A device that has just connected is selected automatically, because connecting
is the reason someone opened the screen; an explicit untick is remembered and
respected.

### Changed — the boxes are actually gone

1.1 replaced bordered cards with a rounded *filled* rectangle per section —
better, but still a rectangle drawn around content, and every section had one.
`PanelGroup` is now `Section`: an uppercase label, the rows, and a hairline
between them, on the bare canvas. No fill, no radius, no border. The only filled
shapes left are pills that are genuinely pressable and the progress track, which
is a gauge rather than a container.

Coincidentally this is also how the references do it: LocalSend's tiles are
flush on the canvas, Musify's settings are divider-separated runs.

### Added — About, developer and links

A real About screen: version and build, what the app is, the developer and their
location, and working links to GitHub, the website, the source, releases, the
issue tracker and the MIT licence. Every URL resolves; no handles were invented.

The old "About" row's subtitle repeated the version printed one row above it.
That is gone.

### Fixed — the send controls read as two competing buttons

Text sending had a "Send" button and the row below it had a "Pick" button; at
narrow widths the two labels wrapped to two lines inside a fixed `Row`. The
composer and its primary action are now one unit, and "Send files" is a single
icon+label control with the whole row to itself, so nothing can be squeezed.

### Fixed — a separate "Received" tab nobody could find

Received items now appear directly under the send area on Home with the folder
they landed in, and the full history lives on one screen. Needing to know that a
second tab existed in order to find a file was the actual bug.

---

## [1.1.0] — 2026-11-24

### Changed — the UI no longer looks like a dashboard of boxes

The first pass of this audit shipped correct, but it corrected *within* the
card stack: a header band, then three bordered 28dp cards per screen. Every
section was a rectangle on a rectangle, which is the generic widget-kit look
the reference apps avoid.

What changed, and what it was compared against:

- **The app icon is gone from inside the app.** It sat on all five headers
  (Home, Discover, Transfers, Settings) and two of them drew a filled band
  behind it. A logo repeated on every screen adds nothing over the window
  chrome — neither LocalSend nor Musify does it.
- **No more card-per-idea.** Grouping now comes from one tinted surface per
  section with hairline separators (Musify's flush `CustomBar` runs,
  LocalSend's `margin: EdgeInsets.zero` tiles). New `PanelGroup` + `FlatRow`
  replace five stacked cards. Settings went from two bordered cards to two
  flush groups; Home from four cards to one.
- **No more nested boxes.** Home's header band held the peer picker which held
  a form field. The band is gone; the composer is a soft writing area inside
  the panel instead of a filled pill that read as a button.
- **One send path.** The composer and the "Send" row below it were the same
  action twice; the row is now the button that belongs to the composer.
- **Transfers empty state is typographic**, not a circled glyph on a card.
- **Surface ramp instead of outlines.** `containerLow` / `containerHigh` /
  `raised` plus a `hairline` separator, all measured: every text token clears
  AA on all three (muted ink 4.52–6.23:1).

### Added — motion

- `Pressable`: press-down scale on every actionable control, built on
  `Listener` so it never competes with a button's own gestures.
- `Entrance` / `StaggeredEntrance`: sections fade and lift in with a 45 ms
  stagger, ported from LocalSend's `InitialFadeTransition`.
- Peer pills animate between selected and unselected states and slide their
  check in rather than popping (`AnimatedContainer` + `AnimatedSize`).
- Device rows carry an animated connection dot; Discover shows a real spinner
  while scanning, and visibility is a switch that states the current
  condition instead of a button that reads "Make visible" forever.
- Transfer progress animates to its new value instead of jumping in BLE-sized
  steps, and its glyph reflects status.
- Every duration collapses to zero when the OS asks for reduced motion.

### Fixed

- A peer pill lost its 48dp touch target in the redesign: an
  `AnimatedContainer` with `alignment` set fills the incoming constraints, so
  a lone pill became a full-width button. Pinned by tests for intrinsic width,
  shared row, and 48dp height.
- `Pressable` silently never fired on content that does not paint an opaque
  box; it now hit-tests `translucent`.
- The composer's hint duplicated the row below it and wrapped mid-sentence.
- A duplicate version string in the About row.
- `AppConstants.appVersion` is now checked against `pubspec.yaml` in CI.

### Tests

107 total (was 88). Every new widget has behaviour tests, including the two
layout regressions above and reduced-motion handling.

## [1.0.10]

- Change Android/Linux application ID to `com.mahimmazidul.throwapp` (namespace, applicationId, MainActivity package).

## [1.0.9]

- Fix Android release build by enforcing compileSdk 37 across app/plugins and consolidating Gradle config.
- Fix Bluetooth file sharing: add framed transfer protocol with file metadata, reassembly, and disk save on receive.
- Add Android share-sheet intake (SEND/SEND_MULTIPLE) via receive_sharing_intent, with pending shared-items UI in Home.
- Stabilize screenshot smoke test to avoid CI flakiness from late font/system callbacks.

## [1.0.8]

- Restore the Android app label resource and align the app version with the release tag.
- Update payload tests and run screenshot rendering as a smoke test in CI.

## [Unreleased]

### Added

- Project scaffolding: pubspec, localization config, lint rules
- CI, CD, and Pages workflows
- Issue templates, PR template, dependabot, CODEOWNERS
- Community docs
- App logo and social preview
- GitHub Pages landing page with FAQ, responsive and zero-JS
- Soothing blue-slate palette for web and app theme
- Responsive breakpoints and app constants
- Material 3 theme with bundled Hind Siliguri (dark first, light ready)
- English and Bengali localization strings
- App entry point with offline-safe font loading
- Icon, splash, and MSIX packaging configuration
- Android manifest (share sheet included, no INTERNET permission), ProGuard
  rules, and release signing config
- Device, payload, transfer, and connection-request models
- Permission flow for nearby devices and Bluetooth
- Abstract transfer service and platform factory
- Nearby service for Android (WiFi Direct via nearby_connections)
