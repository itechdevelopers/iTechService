import json, tempfile, unittest
from pathlib import Path
from unittest.mock import patch
import sip_control

class SessionRecoveryControlTest(unittest.TestCase):
    def payload(self):
        return dict(action='recover',extension='7776',password='p'*43,until=2000,contact_user='7776-'+'a'*32)

    def test_live_primary_consultation_or_queue_leg_prevents_recovery(self):
        for channel in ['PJSIP/7776-000abc','Local/7776@ais-browser-queue-member-0001;2']:
            with self.subTest(channel=channel), patch.object(sip_control.subprocess,'check_output',return_value=(channel+'!'+'!'.join(['x']*12)).encode()), patch.object(sip_control,'rotate') as rotate, patch.object(sip_control,'cli') as cli:
                self.assertEqual({'busy':True},sip_control.handle(self.payload()))
                rotate.assert_not_called();cli.assert_not_called()

    def test_other_staff_call_does_not_block_target_recovery(self):
        with tempfile.TemporaryDirectory() as directory:
            state=Path(directory)/'auth.json';state.write_text(json.dumps({'contacts':{}}))
            with patch.object(sip_control,'STATE',state),patch.object(sip_control.subprocess,'check_output',side_effect=[('PJSIP/7775-abc!'+'!'.join(['x']*12)).encode(),b'Value: 2000',b'']),patch.object(sip_control,'rotate') as rotate,patch.object(sip_control,'cli') as cli:
                sip_control.handle(self.payload())
                rotate.assert_called_once_with('7776','p'*43)
                self.assertEqual('7776-'+'a'*32,json.loads(state.read_text())['contacts']['7776'])
                self.assertEqual(2,cli.call_count)
                cli.assert_called_with('database put ais-telephony 7776/active 0')

    def test_call_starting_during_recovery_restores_admission_and_keeps_auth(self):
        call=('PJSIP/7776-abc!'+'!'.join(['x']*12)).encode()
        with patch.object(sip_control.subprocess,'check_output',side_effect=[b'',b'Value: 2000',call]),patch.object(sip_control,'rotate') as rotate,patch.object(sip_control,'cli') as cli:
            self.assertEqual({'busy':True},sip_control.handle(self.payload()))
            rotate.assert_not_called()
            self.assertEqual(['database put ais-telephony 7776/active 0','database put ais-telephony 7776/active 2000'],[c.args[0] for c in cli.call_args_list])

    def test_invalid_recovery_credentials_cannot_change_admission(self):
        for field,value in [('password','bad'),('contact_user','7775-'+'a'*32),('until',True)]:
            payload=self.payload();payload[field]=value
            with patch.object(sip_control,'cli') as cli:
                with self.assertRaises(ValueError):sip_control.handle(payload)
                cli.assert_not_called()

    def test_unknown_channel_output_refuses_without_mutation(self):
        with patch.object(sip_control.subprocess,'check_output',return_value=b'Unable to connect to remote asterisk'),patch.object(sip_control,'rotate') as rotate:
            with self.assertRaises(RuntimeError):sip_control.handle(self.payload())
            rotate.assert_not_called()

if __name__=='__main__':unittest.main()
