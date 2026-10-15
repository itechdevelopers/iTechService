# Native AIS phone workspace

AIS uses ordinary full document navigation (no Turbolinks runtime). Moving the SIP
client into the application layout would disconnect a call when following a link
or submitting a form. `/telephony/workspace` therefore keeps a same-origin phone
frame alive alongside a separate application frame. Application links, forms and
reports continue to use their original controllers and authorization.

The existing application toolbar opens this workspace at the current URL. The
phone panel opens on demand, on incoming calls, or on errors. The toolbar shows
the assigned extension and off/checking/registered/call/error state. Registration,
not merely microphone permission or HTTPS availability, turns the status green.
Client/entity links from the phone navigate the application frame. The phone
continues when its panel is collapsed. Browser Back navigates the application
frame without replacing the phone. The workspace uses replaceState to mirror the child
URL; it does not add duplicate joint-history entries or navigate on popstate. Reloading or closing the entire workspace
still disconnects the call and prompts before leaving an active call.

The phone frame reports UI state only to the same-origin parent. The parent accepts
messages only from that exact phone frame. SIP credentials and signed tickets
remain in the phone frame. Gateway leases remain the authority for exclusive
registration across tabs and the standalone fallback; a second activation is
rejected without interrupting the first. The fallback remains available after
turning off the integrated phone. Disabling during a call requires confirmation.

Enabling checks microphone access, a TLS broker request and SIP registration.
A failed broker connection provides its current HTTPS check URL. Browser APIs
cannot tell which Wi-Fi is selected or install certificate trust automatically.
The existing ticket heartbeat rechecks AIS permission and expires the lease if
permission/session is revoked. Redirect to sign-in in the application frame also
requests shutdown and leaves the workspace.

## Verification

- Isolated `ais_telephony_test`: 29 tests / 161 assertions, including workspace
  authorization, local navigation URL validation, recursive workspace rejection,
  and actual rendered frame permissions/extension. No production data changes.
- Chrome: `tools/telephony/test-workspace.cjs` uses actual generated Rails HTML,
  an unused 7779 gateway lease and synthetic microphone. AIS content/ticket/caller
  routes are test fixtures; broker, SIP, ICE/TURN and echo audio are real.
- Confirmed outgoing echo survives full GET navigation, POST form, Back and hidden
  panel; second tab cannot claim its lease; incoming test call opens the panel;
  client link preserves the phone; accepting incoming receives audio; disable
  confirmation can cancel; confirmed disable unregisters; broker failure is red.
- TLS in this automated Chrome test pins exactly the office leaf SPKI. It does not
  verify user-device installation of certificate trust.
- Safari WebDriver on this Mac rejects session creation until Develop > Allow
  Remote Automation is enabled. Safari support is **not yet verified**. The
  existing standalone Safari phone was previously confirmed by the user; that is
  not evidence for this new iframe workspace.

Run Rails tests with UTF-8 locale, test-only SECRET_KEY_BASE and DB_NAME explicitly
set to `ais_telephony_test`. Set AIS_PHONE_BROWSER_FIXTURES to a writable directory
so the test exports workspace.html / phone.html. Then run the Node test with the
same fixture directory and AIS_TELEPHONY_PILOT_ROOT pointing to the local gateway
runtime. The test never uses employee 7772 and releases 7779 on completion.

## Review regressions (PR 767)

`tools/telephony/test-workspace-review.cjs` uses the actual JsSIP 3.10.0 UA and its
stop/unregistration timers with a stubbed Socket registrar. It confirms delayed
stop events and old-UA events after re-enable do not alter the current phone,
unchanged errors do not reopen a dismissed panel, explicit permission denial
stops the phone and retains the original error, broker activation timeouts mark
the correct check, AIS failure does not reuse an old gateway diagnosis, deferred
workspace initialization observes a frame that already loaded, and the named
standalone window is reused with its opener.

The real-gateway test additionally holds an AIS ticket response for 16 seconds
while echo audio continues and checks that renewals do not overlap. It traverses
two Back and two Forward entries twice without growing history, and observes the
status for 3.5 seconds after stopping to catch JsSIP's delayed disconnection.
Renewals have no activation timeout; only explicit AIS/gateway access denial
terminates the phone. Transient failure warns and retries, while the existing
server lease deadline still applies. Shutdown cancels an outstanding renewal.

Workspace paths share one server-defined pattern rendered into the client. Both
raw and decoded pathname are checked, including dot segments and /telephony.html.
Client-card navigation uses validated postMessage rather than parent DOM access.

### Printing reports

Browser Ctrl/Cmd+P in the workspace can print the shell and only the visible part
of its application frame. Use **Открыть страницу для печати** in the toolbar,
then print that separate AIS page. This does not reload the phone workspace.
The workspace itself is not a full-document print surface.

## Phone directory and direct transfer

The phone fetches existing PhoneLabel entries from GET /telephony/directory, protected by TelephonyPolicy.use?. The directory is grouped by office/address and searchable by number, label and group. Selecting an entry fills the dial or transfer input; it never calls automatically. Incoming calls show the exact SIP caller number above the normalized number and client context. Directory captions are also shown for recognized internal callers. VLD/VDK, SAH/SAKH, USS, KHD and existing Cyrillic routing prefixes are handled for client lookup.

The transfer button is available during established conversations and accepts internal numbers of 3–4 digits. It sends JsSIP RTCSession.refer with progress/failure/acceptance handlers and guards against duplicate requests and stale sessions. This is a direct transfer without a consultation call. Asterisk handles recipient routing and any unavailable-recipient behavior.

The gateway installs ais-browser-transfer as TRANSFER_CONTEXT. Incoming Dial uses U(ais-browser-transfer-identity) to capture the actual answering browser extension on the original channel; outgoing Dial inherits the authenticated browser extension. Transfer routes require a currently active 7771–7780 lease before forwarding via pbx-bridge. Apply gateway-dialplan.conf with a backup and dialplan reload, without restarting Asterisk.

Validation: test/telephony/run.rb covers directory authorization and internal caller labels. tools/telephony/test-directory-transfer.cjs uses three unassigned leases (7779, 7778, 7776), real Chrome, broker, gateway and PBX to verify incoming/outgoing transfer and two-way RTP. It also covers directory search/selection, literal HTML labels, raw caller display, invalid transfer input and confirmation cancellation. AIS API/HTML in this test is fixture-backed.

## Hold and incoming destination captions

Incoming raw SIP caller IDs keep their full prefix and number. VDK/VLD/влд is captioned as Владивосток, SAH/SAKH/сакх as Южно-Сахалинск, USS/USSF as Уссурийск, HAB/KHD as Хабаровск. Unknown prefixes remain visible without guessing a city. HAB and USSF also normalize for client lookup.

The established call has an Удержать / Вернуться к разговору toggle. Hold/unhold uses SIP renegotiation, guarded by an in-flight operation and the active session; pending negotiation blocks transfer and another hold request. The gateway generates music on hold from its default class. Tests in tools/telephony/test-hold.cjs verify Asterisk MOH start/stop alongside incoming RTP/audio at the held caller, repeated hold/resume and disconnect while held on two unassigned test extensions. The phone permits the client call plus one outgoing internal consultation call. The consultation starts only after a confirmed hold; per-dialog microphone clones prevent mute/hold from affecting the other dialog or the next call. Only the active consultation audio is played. Return ends the consultation and resumes the client; attended transfer uses REFER with Replaces to connect the two other parties. Ending the client call cleans up the consultation too.
