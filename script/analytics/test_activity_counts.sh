#!/usr/bin/env bash
# Each standalone harness owns a process; never changes Rails test's connection.
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${ACTIVITY_TEST_PORT:?Set ACTIVITY_TEST_PORT=55438 for the isolated test database}"
bundle exec ruby script/analytics/tests/period_counts_test.rb
bundle exec ruby script/analytics/tests/import_test.rb
bundle exec ruby script/analytics/tests/view_test.rb
python3 -m unittest discover -s script/analytics -p 'test_*.py'
