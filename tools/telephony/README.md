# AIS local telephony tooling

Review and activation order: `../../doc/telephony/review-and-rollout.md`.

Gateway Python scripts run in the existing Ubuntu VM; PBX scripts support Python 2.6 on FreePBX. Mac collector requires Python 3.9+ with its standard library only. Never commit private config, keys, passwords or state.

Offline tests:

```
python3 -m unittest discover -s tools/telephony -p 'test_*.py' -v
```

Focused Rails tests (dedicated schema/migration must already be loaded):

```
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 RAILS_ENV=development RBENV_VERSION=2.7.5 \
DB_HOST=127.0.0.1 DB_USERNAME=itech DB_PASSWORD=itech \
DB_NAME=ais_telephony_test DB_NAME_TEST=ais_telephony_test \
SECRET_KEY_BASE=telephony-local-test-secret RUBYOPT=-W0 \
bundle exec ruby test/telephony/run.rb
```

Actual SIP/browser tests require the existing trusted local pilot VM with no calls on temporary endpoints 7798/7799 or 7778/7779. Run them **sequentially**. They add/remove bounded temporary config and reload PJSIP/dialplan; do not run against an activated employee pool using those same numbers. Existing 7771 is preserved. Certificates are checked; tests use synthetic microphones and grant Chrome local-network permission.

```
export AIS_TELEPHONY_PILOT_ROOT=/absolute/path/to/work/webrtc-pilot
node tools/telephony/test-ui.cjs
node tools/telephony/test-sip-control.cjs
node tools/telephony/test-group.cjs
```

Playwright is loaded from that pilot's existing `test-tools/node_modules`, not installed globally. Set `CHROME_EXECUTABLE` to override the Mac Chrome path. The UI test mocks AIS ticket/client and broker HTTP responses; other tests exercise real SIP control and the reviewed group dialplan. None places a paid call or rings an existing employee's phone.

The source JsSIP 3.10.0 vendor bundle preserves its MIT header and is the same checksum-verified dependency used in the tested pilot.
