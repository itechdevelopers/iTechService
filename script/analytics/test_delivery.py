import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import types
import unittest
from unittest.mock import patch
import deliver_receipt_counts as delivery
import refresh_receipt_counts as refresh


class DeliveryTest(unittest.TestCase):
    def snapshot(self, root):
        raw = json.dumps({'schema_version': 'activity-counts-1.0', 'metric': 'receipts',
                          'checks': {'all_pages_received': True}}).encode()
        report = root / 'report.json'
        report.write_bytes(raw)
        identity = hashlib.sha256(raw).hexdigest()
        (root / '2025-01.latest.json').write_text(json.dumps({'file': report.name, 'sha256': identity}))
        return report, identity

    def test_checksum_mismatch_fails_before_credentials_or_network(self):
        with tempfile.TemporaryDirectory() as directory:
            report, identity = self.snapshot(Path(directory))
            report.write_bytes(report.read_bytes() + b' ')
            with self.assertRaisesRegex(ValueError, 'checksum'):
                delivery.deliver(report, Path(directory) / 'missing-connector', identity)

    def test_saved_snapshot_delivered_even_if_collection_fails_and_not_redelivered(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            _, identity = self.snapshot(root)
            argv = ['refresh', '--output', directory, '--connector', directory]
            response = {'delivery_id': identity, 'status': 'created', 'import_id': 1}
            with patch.object(sys, 'argv', argv), patch.object(refresh, 'deliver', return_value=response) as send, \
                    patch.object(refresh.subprocess, 'run', side_effect=subprocess.CalledProcessError(1, 'collector')):
                with self.assertRaises(RuntimeError):
                    refresh.run()
                self.assertEqual(1, send.call_count)
                with self.assertRaises(RuntimeError):
                    refresh.run()
                self.assertEqual(1, send.call_count)
                self.assertTrue((root / (identity + '.delivered')).exists())

    def test_wrong_confirmation_does_not_mark_snapshot_delivered(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.snapshot(root)
            with patch.object(refresh, 'deliver', return_value={'delivery_id': 'wrong'}):
                self.assertTrue(refresh.deliver_pending(root, root))
            self.assertEqual([], list(root.glob('*.delivered')))

    def test_delivery_hashes_exact_utf8_and_requires_matching_server_confirmation(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            report, identity = self.snapshot(root)
            connector = types.SimpleNamespace(secure_env=lambda: {'ICE_WEEKLY_MARKUP_TOKEN': 'synthetic-test'})
            class Response:
                status = 201
                def __enter__(self): return self
                def __exit__(self, *args): pass
                def read(self): return json.dumps({'ok': True, 'delivery_id': identity, 'status': 'created', 'id': 1}).encode()
            with patch.dict(sys.modules, {'deliver_to_ice': connector}), patch.object(delivery.urllib.request, 'build_opener') as build:
                build.return_value.open.return_value = Response()
                result = delivery.deliver(report, root, identity)
                envelope = json.loads(build.return_value.open.call_args.args[0].data)
                self.assertEqual(identity, hashlib.sha256(envelope['report_json'].encode('utf-8')).hexdigest())
                self.assertEqual(identity, result['delivery_id'])


if __name__ == '__main__':
    unittest.main()
