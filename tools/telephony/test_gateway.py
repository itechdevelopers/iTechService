import base64, hashlib, hmac, json, unittest
from gateway import Denied, LeaseStore, verify_ticket
from collector import browser_answers, call_from_cdr

class GatewayTest(unittest.TestCase):
    def ticket(self, **changes):
        claims = {'v':1,'aud':'ais-telephony-gateway','user_id':1,'extension':'7771','iat':1000,'exp':1060,'jti':'test'}
        claims.update(changes)
        encoded = base64.urlsafe_b64encode(json.dumps(claims).encode()).decode().rstrip('=')
        return encoded+'.'+hmac.new(b's'*48,encoded.encode(),hashlib.sha256).hexdigest()

    def test_signed_ticket_and_tampering(self):
        self.assertEqual('7771',verify_ticket(self.ticket(),'s'*48,1001)['extension'])
        for ticket in [self.ticket()+'x', self.ticket(extension='7781'),self.ticket(exp=999),self.ticket(user_id='1'),None]:
            with self.assertRaises(Denied):verify_ticket(ticket,'s'*48,1001)

    def test_duplicate_session_and_wrong_employee(self):
        events=[];store=LeaseStore(controller=lambda *a,**kw:events.append((a,kw)),clock=lambda:1001)
        claims=verify_ticket(self.ticket(),'s'*48,1001)
        first=store.enable(claims)
        with self.assertRaises(Denied):store.enable(claims)
        with self.assertRaises(Denied):store.update('heartbeat',dict(claims,user_id=2),first['token'])
        with self.assertRaises(Denied):store.update('heartbeat',claims,'wrong')
        store.update('disable',claims,first['token'])
        second=store.enable(claims)
        self.assertNotEqual(first['password'],second['password'])
        self.assertEqual('disable',events[1][0][0])

    def test_expiry_revokes_sip_credential(self):
        now=[1001];events=[]
        store=LeaseStore(controller=lambda *a,**kw:events.append((a,kw)),clock=lambda:now[0])
        store.enable(verify_ticket(self.ticket(),'s'*48,now[0]))
        now[0]=1061;store.expire()
        self.assertEqual({},store.leases)
        self.assertEqual('disable',events[-1][0][0])

    def test_answered_browser_comes_from_actual_channel(self):
        row=['','79991234567','7771','ais-browser-group','','PJSIP/pbx-bridge-1','PJSIP/7774-abcd','Dial','','','','','10','5','ANSWERED','DOCUMENTATION','1791417601.10','ais:1791417600.123:group']
        import csv,io
        stream=io.StringIO();csv.writer(stream).writerow(row)
        answers=browser_answers(stream.getvalue())
        self.assertEqual({'1791417600.123':'7774'},answers)
        row[14]='NO ANSWER';stream=io.StringIO();csv.writer(stream).writerow(row)
        self.assertEqual({},browser_answers(stream.getvalue()))

    def row(self):
        return dict(uniqueid='1791417600.123',calldate='2026-10-08 12:00:00',src='влд79991234567',dst='600',channel='SIP/provider-abcd',dstchannel='Local/7771@ais-pilot-browser-abcd;1',disposition='ANSWERED',recordingfile='test.wav',duration=10,billsec=5)

    def test_call_direction_status_and_recording(self):
        row=self.row();call=call_from_cdr(row,{'1791417600.123':'7774'})
        self.assertEqual('incoming',call['direction']);self.assertEqual('7774',call['answered_extension'])
        self.assertEqual('2026-10-08T12:00:00+10:00',call['started_at'])
        self.assertEqual('/var/spool/asterisk/monitor/2026/10/08/test.wav',call['recording_path'])
        row.update(src='101',dst='79991234567',dstchannel='SIP/trunk-abcd',disposition='NO ANSWER')
        call=call_from_cdr(row,{})
        self.assertEqual('outgoing',call['direction']);self.assertEqual('missed',call['status']);self.assertIsNone(call['answered_extension'])
        row.update(dst='102',dstchannel='SIP/102-abcd',disposition='ANSWERED')
        self.assertEqual('102',call_from_cdr(row,{})['answered_extension'])
        row['channel']='Local/101@from-internal-abcd;1'
        self.assertIsNone(call_from_cdr(row,{}))

    def test_recording_path_injection_and_unknown_caller(self):
        row=self.row();row.update(recordingfile='../secret.wav',src='')
        call=call_from_cdr(row,{})
        self.assertIsNone(call['recording_path']);self.assertEqual('Номер скрыт',call['caller_number'])

if __name__=='__main__':unittest.main()
