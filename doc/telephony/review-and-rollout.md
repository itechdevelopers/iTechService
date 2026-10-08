# Browser telephony: review and rollout

This branch adds the AIS phone window and an authoritative CDR history. Production AIS has **not** been deployed. The existing working 7771 pilot remains available. Developer approval is required before activating this branch, outgoing production routes or the new gateway broker.

## Accepted behavior

- Browser extensions 7771–7780 are assigned individually in employee profiles. The separate ability is «Может работать с телефонией». Admins may assign both, ordinary employees cannot change them. No employees receive new rights automatically.
- The optional «Номер обычного телефона АТС» field maps desk extensions such as 101 to employees for the call history. It does not change call routing. Browser and desk extensions cannot overlap.
- Calls targeting 101, 102 and 103 also enter the **shared browser group**. All employees with an active authorized browser registration ring. Answering cancels the other legs. Declining/busy/unavailable on one browser leaves the remaining devices available. A second call can ring a free employee while another talks.
- Asterisk controls the group. Permissions authorize an employee's phone session; they do not originate or distribute calls by themselves.
- The AIS button opens a separate 460×740 phone window. The employee enables it with a user gesture and grants microphone/local-network access. Calls survive navigation in the main window. Links to clients/orders/repairs open in the main AIS window when it is available.
- Inbound caller lookup strips only `влд`, `сакх`, `vld`, `sakh`, normalizes Russian 8/+7 numbers to 7, preserves internal numbers, and never invents a client number. Active device orders, pending service jobs and unfinished quick jobs appear before client cards. Multiple matching clients are shown rather than arbitrarily choosing one. Existing entity policies apply.
- «Сервис → История вызовов» lists at most 100 rows per page, including unanswered calls. It shows caller, destination, actual answering number, employee names when mapped, result and talk time. Employee names are snapshotted when imported; retries preserve that snapshot even if numbers are reassigned.
- Audio is served through an authenticated AIS endpoint and the existing SFTP connection. Admins / `listen_all_transcriptions` holders may hear all recordings; a telephony employee may hear calls they answered. Recording paths are constrained to the monitor root, written atomically into cache, and support HTTP byte ranges.

## Current production PBX change

On 2026-10-08 the already authorized parallel routes were persisted in FreePBX's `devices.dial` as well as AstDB:

```
101 → SIP/101&Local/7771@ais-pilot-browser/n
102 → SIP/102&Local/7771@ais-pilot-browser/n
103 → SIP/103&Local/7771@ais-pilot-browser/n
```

FreePBX 12's `core_devices2astdb` reads that column when rebuilding AstDB. Other AMPUSER devices, ring groups, inbound routes and timers are preserved. Editing an extension's Dial field manually can change this value; do not replace it with the original default inadvertently.

Backup: `/root/ais-pilot-backup-20261008-175820`. `rollback-destinations.sh` now invokes a guarded rollback of **both** the FreePBX column and AstDB. It stops if someone has independently changed the destination. The independent SIP bridge is registered and qualified from Mac 192.168.1.109. Its outgoing context currently remains blocked.

## Authentication and registration

AIS issues a 60-second HMAC ticket containing employee ID and assigned extension; no SIP password is stored in the AIS user table. A second secret protects machine CDR imports. Both must be random and provisioned outside Git.

The local broker checks AIS Origin/Host, ticket signature, audience, lifetime and extension range. Only one lease may exist per extension. A new lease rotates that extension's SIP password and gives it a unique Contact URI. The root control helper only accepts bounded commands on a Unix socket from the asterisk UID. Ringing is enabled only after the registrar contains the new lease's complete Contact URI; stale contacts from a previous employee do not ring. Heartbeats obtain fresh AIS authorization every 15 seconds. Expiry/disable rotates credentials, clears availability and ends that extension's active channels. New calls stop at the absolute deadline; helper cleanup runs every five seconds.

The old unrestricted local pilot page is disabled during activation. Contacts expire in at most 60 seconds, and the broker invalidates old leases on restart. Finish active calls before restarting or provisioning the gateway.

## Rollout after developer approval

1. Merge the reviewed PR into current `origin/master`. Follow `AGENTS.md` and `doc/production-releases.md`: deploy only a clean checkout at current master, preserve shared uploads/env/data, and use the normal production safety tasks. Keep `TELEPHONY_ENABLED=false` during provisioning. Do not run the migration down on production: it would delete the new history.
2. In the shared AIS env configure `TELEPHONY_SHARED_SECRET` and `TELEPHONY_INGEST_SECRET` as distinct random secrets of at least 32 bytes. Retain existing SFTP env values. The import service requires the ingest secret; phone tickets also require `TELEPHONY_ENABLED=true`.
3. On this working Mac, reserve 192.168.1.109 in DHCP. Employees on other computers must use its LAN/VPN address, not their own `localhost`. Use `tools/telephony/config.lan.example.json`; configure AIS `TELEPHONY_GATEWAY_ORIGIN=https://192.168.1.109:18444` and AIS Origin `https://ise.itech.pw`.
4. Inside VM `p`, install the reviewed gateway files under `/opt/ais-telephony`; install service units under `/etc/systemd/system`, then `systemctl daemon-reload`. Store the private gateway JSON in `/etc/ais-telephony/config.json`, root:asterisk 0640. Set its shared secret to the AIS ticket secret; copy the existing TURN HMAC secret privately from `/etc/ais-pilot-phone/turn-secret`.
5. Issue a separate CA:FALSE LAN leaf with `issue-lan-certificate.sh 192.168.1.109`. It includes SANs for the LAN IP and localhost. Trust **that leaf only** on employee Macs through local OS confirmation; do not broaden trust in the CA. Verify Safari and Chrome accept it before activating. This preserves the current pilot certificate until the switch. Leaves expire after 90 days and renewal requires renewed leaf trust.
6. Merge `lima-lan-port-forwards.yaml` into VM `p`'s Lima config, preserving its existing VZ network, disks and other settings. Restart the VM in a call-free window if required. Bind HTTPS 18444, WSS 18089 and TURN TCP 3478 on the Mac; restrict them to office/VPN clients in the firewall. Do not expose these ports on the public Internet. Validate the config before restarting. The new broker's default local development origin is **18444**, not the old pilot UI on 18443.
7. With zero active gateway channels run `sudo python3 /opt/ais-telephony/provision_gateway.py --activate`. It backs up owned config, provisions endpoints/auth 7771–7780, updates WSS certificate paths, reserves enough RTP ports, enables CDR correlation, disables the old pilot UI, restarts Asterisk and starts the broker/helper. It rejects a repeated activation; inspect existing state rather than applying it twice.
8. On FreePBX copy `configure_pbx.py` and `pbx-dialplan.conf` into one root-owned directory. With no active pilot conversation run `python configure_pbx.py --activate`. It backs up only custom files, adds a root call-ID header for CDR correlation, preserves parallel routes, and enables restricted 3/4-digit internal or 7-prefixed Russian outgoing numbers through **existing** FreePBX routing/trunks. It does not pick a carrier or change groups. Unknown caller extension / feature-code requests are rejected. Test internal calls before trying an external outgoing call.
9. Assign browser numbers and the ability in AIS profiles. Optionally assign desk numbers for history labels. Then enable `TELEPHONY_ENABLED=true`. Keep Softphone.Pro available. Disconnection does not transfer an active conversation to Softphone.
10. Install `pbx_export.py` root-owned on FreePBX. For the Mac collector create a dedicated SSH key restricted by `from=192.168.1.109`, forced command `/usr/bin/python /PATH/pbx_export.py`, no PTY/forwarding/agent/X11. Preserve all existing authorized keys. The exporter only executes validated date/page SELECTs and reads active channel metadata; it cannot change the PBX. It was exercised read-only on the actual Python 2.6 PBX.
11. Store private collector config root/user 0600 outside the repository. Use `collector.example.json`, strict known host verification, the separate ingest secret, and the actual `vm.sh` absolute path. `start_day` is an explicit backfill boundary; its example starts at rollout day, so change it if earlier history is required. Do not silently claim older calls were imported. The collector reads PBX CDR and gateway CSV, sends signed batches up to 100, uses private durable state + a singleton lock, retries on its next scheduled run, and keeps open days for late CDRs. Browser answer correlation comes from the actual answered PJSIP leg, not a browser's own report.
12. Install the two Mac LaunchAgent templates with real paths: start the existing VM at login and prevent idle system sleep while serving phones; run the collector once per minute. Manual sleep, shutdown, loss of LAN/VPN or logout can still make this Mac unavailable. Ordinary PBX phones continue to work when the browser path is unavailable.

## Acceptance after activation

Use Safari and Chrome with real headsets on two employee computers. Check direct 101/102/103 and group 600, answer on browser and desk phone, reject one browser, close one browser, place a new call while another employee talks, and revoke a user's ability. Test internal outgoing calls and existing authorized external routing. Echo 779 remains a local authenticated audio test.

Confirm history imports a real answered and missed call, uses the true answering employee/number, shows caller 7 without routing prefixes, and serves an existing WAV through SFTP in both browsers. Verify pagination at 100 and permissions for other people's recordings. Verify active orders/repairs and unknown clients. Then verify dashboard, iPhone detail, KPI, prior transcription audio/import counts and the deployed master SHA per the production release instructions.

Disable the feature flag to stop issuing new leases; disable/stop the broker to revoke current registrations. Restore the gateway/PBX custom-file backups if reverting routing. Use the guarded parallel rollback only when intentionally removing the browser leg from 101/102/103. Preserve the phone_calls table and imported history.

## Verification completed before review

- Migration up/down/up on dedicated `ais_telephony_test`, not production; schema regenerated.
- Rails direct tests: permissions, unique/range constraints, ticket endpoint/current employee, protected profile fields, normalized/unknown/active client lookup, signed and atomic imports, stale signatures, retry snapshots, desk/outgoing employee attribution, 100-row HTTP history, audio byte ranges and traversal checks.
- Python tests: signed-ticket validation, duplicate lease, wrong owner/token, expiry, actual answering-leg correlation, CDR directions/statuses, recording paths and anonymous callers.
- Actual Asterisk 20 tests on isolated temporary endpoints: SIP password rotation/revocation; new Contact gates availability; simultaneous group ringing, cancel-on-answer, another incoming call while the first employee talks, rejection preserving the first conversation.
- Chrome 155: new AIS UI with mocked AIS/broker responses but real WSS authentication, TURN, RTP/echo, microphone/remote meters, incoming answer and prioritized client entities. Local-network permission was granted to the test browser; certificate validation was enabled throughout.
- JS production Uglifier compilation and Python/Ruby syntax checks.
- Read-only exporter on actual Asterisk 11 / FreePBX Python 2.6 returned 248 CDR rows for 2026-10-08. No actual CDRs were sent to production AIS.

Full production CDR ingestion/SFTP playback, outbound business routing, multi-workstation certificate trust and Safari on the new AIS origin remain rollout acceptance checks. The older working pilot's Safari/headset and production parallel ringing were confirmed by the user.

The repository's existing `capybara-selenium` helper fails against its pinned Selenium 4 (`driver_path=`). The focused Rails tests boot development against the guarded dedicated test DB and do not load that unrelated legacy driver helper. The full legacy suite was not claimed to pass.

Primary implementation references: [Asterisk 20 PJSIP](https://docs.asterisk.org/Asterisk_20_Documentation/API_Documentation/Module_Configuration/res_pjsip/), [PJSIP_HEADER](https://docs.asterisk.org/Latest_API/API_Documentation/Dialplan_Functions/PJSIP_HEADER/), [Chrome local-network permission](https://developer.chrome.com/blog/local-network-access?hl=en).
