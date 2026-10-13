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
frame without replacing the phone. Reloading or closing the entire workspace
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

- Isolated `ais_telephony_test`: 29 tests / 146 assertions, including workspace
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
