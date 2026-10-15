from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import activate_queues
import provision_gateway


class QueueRolloutTest(unittest.TestCase):
    def test_activation_rejects_nonzero_including_multiples_of_ten_before_mutation(self):
        for count in [1, 2, 10, 20, 30]:
            with self.subTest(count=count), patch('sys.argv', ['activate_queues.py', '--activate']), \
                    patch.object(activate_queues, 'run', return_value=f'{count} active channels\n5 active calls\n') as run:
                with self.assertRaisesRegex(AssertionError, 'Finish calls first'):
                    activate_queues.main()
                self.assertEqual(1, run.call_count)

    def test_fresh_provision_rejects_ten_channels_before_writing_configs(self):
        with patch('sys.argv', ['provision_gateway.py', '--activate']), \
                patch.object(Path, 'read_text', return_value='{"shared_secret":"' + 's'*48 + '"}'), \
                patch.object(provision_gateway.subprocess, 'check_output', return_value=b'10 active channels\n5 active calls\n'):
            with self.assertRaisesRegex(AssertionError, 'Finish active calls first'):
                provision_gateway.main()

    def test_zero_channels_passes_to_lease_check(self):
        with patch('sys.argv', ['activate_queues.py', '--activate']), \
                patch.object(activate_queues, 'run', side_effect=['0 active channels\n0 active calls\n', RuntimeError('lease checkpoint')]) as run:
            with self.assertRaisesRegex(RuntimeError, 'lease checkpoint'):
                activate_queues.main()
            self.assertEqual('database show ais-telephony', run.call_args.args[-1])

    def test_fresh_provision_installs_queues_and_include_once(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root/'queues.conf').write_text('[general]\npersistentmembers=yes\n')
            source = Path(provision_gateway.__file__).with_name('gateway-queues.conf')
            with patch.object(provision_gateway.os, 'chown'), patch.object(provision_gateway.grp, 'getgrnam'):
                provision_gateway.install_queues(root, source)
                provision_gateway.install_queues(root, source)
            self.assertEqual(source.read_text(), (root/'ais-telephony-queues.conf').read_text())
            self.assertEqual(1, (root/'queues.conf').read_text().count('#include ais-telephony-queues.conf'))
            self.assertIn('persistentmembers=yes', (root/'queues.conf').read_text())
            self.assertIn('[ais-browser-all]', (root/'ais-telephony-queues.conf').read_text())
            self.assertIn('[ais-browser-7778]', (root/'ais-telephony-queues.conf').read_text())
