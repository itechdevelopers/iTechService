import unittest
from queue_state import project
from gateway import Denied, LeaseStore


class QueueStateTest(unittest.TestCase):
    def test_busy_waiting_fifo_and_personal_privacy(self):
        text = '\n'.join([
            '1000|1.1|ais-browser-all|NONE|ENTERQUEUE||VDK79146896537|1',
            '1001|1.2|ais-browser-all|NONE|ENTERQUEUE||105|2',
            '1002|1.3|ais-browser-7772|NONE|ENTERQUEUE||HAB79991234567|1',
            '1003|1.4|ais-browser-7773|NONE|ENTERQUEUE||secret|1'])
        result = project(text, '7772', 1010)
        self.assertEqual(['VDK79146896537', '105', 'HAB79991234567'], [c['number'] for c in result['waiting']])
        self.assertEqual([1, 2, 1], [c['position'] for c in result['waiting']])
        self.assertEqual(10, result['waiting'][0]['wait_seconds'])

    def test_answer_cancel_timeout_and_restart_do_not_disappear(self):
        start = '1000|1.1|ais-browser-all|NONE|ENTERQUEUE||105|1\n'
        events = [
            ('1001|1.1|ais-browser-all|Local/7772@ais-browser-queue-member/n|CONNECT|1|2.1|0', 'answered'),
            ('1001|1.1|ais-browser-all|NONE|ABANDON|1|1|1', 'left'),
            ('1001|1.1|ais-browser-all|NONE|EXITWITHTIMEOUT|1|1|1', 'timeout'),
            ('1001|NONE|NONE|NONE|QUEUESTART|', 'unknown')]
        for event, state in events:
            result = project(start + event, '7772', 1010)
            self.assertEqual([], result['waiting'])
            self.assertEqual(state, result['recent'][0]['state'])
        self.assertEqual('7772', project(start+events[0][0], '7772', 1010)['recent'][0]['answered_extension'])

    def test_bounded_malformed_and_stale_projection(self):
        self.assertEqual([], project('bad|1|ais-browser-all|NONE|ENTERQUEUE||105', '7772', 1010)['waiting'])
        self.assertEqual([], project('1000|1.1|ais-browser-all|NONE|ENTERQUEUE||105', '7772', 1200)['waiting'])
        text = '\n'.join(f'1000|1.{n}|ais-browser-all|NONE|ENTERQUEUE||105' for n in range(150))
        self.assertEqual(100, len(project(text, '7772', 1010)['waiting']))

    def test_waiting_requires_current_lease_and_cannot_renew_it(self):
        events = []
        store = LeaseStore(controller=lambda *a, **kw: events.append(a) or {'waiting': [], 'recent': []}, clock=lambda: 1000)
        claims = dict(extension='7772', user_id=1, exp=1060)
        lease = store.enable(claims)
        with self.assertRaises(Denied):
            store.update('waiting', claims, 'wrong')
        with self.assertRaises(Denied):
            store.update('waiting', dict(claims, user_id=2), lease['token'])
        deadline = store.leases['7772']['until']
        self.assertEqual([], store.update('waiting', claims, lease['token'])['waiting'])
        self.assertEqual(deadline, store.leases['7772']['until'])
        self.assertEqual(('waiting', '7772'), events[-1])
        store.update('disable', claims, lease['token'])
        with self.assertRaises(Denied):
            store.update('waiting', claims, lease['token'])


if __name__ == '__main__':
    unittest.main()
