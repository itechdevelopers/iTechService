import json,tempfile,unittest
from unittest.mock import patch
from pathlib import Path
from live_history import Reducer,Outbox
class LiveHistoryTest(unittest.TestCase):
    def incoming(self):
        r=Reducer();r.event({'Event':'Newchannel','Uniqueid':'1791800000.1','Channel':'SIP/trunk-a','CallerIDNum':'79991234567','Exten':'600'})
        r.event({'Event':'Newchannel','Uniqueid':'1791800000.2','Channel':'SIP/101-b','CallerIDNum':'79991234567','Exten':'101'})
        r.event({'Event':'Dial','UniqueID':'1791800000.1','Channel':'SIP/trunk-a','Destination':'SIP/101-b','DestUniqueID':'1791800000.2','SubEvent':'Begin'})
        return r
    def test_group_dial_collapses_children_and_answer_identifies_employee(self):
        r=self.incoming();self.assertEqual(1,len(r.rows()));self.assertEqual('ringing',r.rows()[0]['status'])
        r.event({'Event':'Bridge','Bridgestate':'Link','Uniqueid1':'1791800000.1','Uniqueid2':'1791800000.2','Channel2':'SIP/101-b'})
        self.assertEqual('101',r.rows()[0]['answered_extension']);self.assertEqual('talking',r.rows()[0]['status'])
        for uid in ('1791800000.1','1791800000.2'):r.event({'Event':'Hangup','Uniqueid':uid})
        self.assertEqual('ended',r.rows()[0]['status'])
    def test_second_call_remains_independent(self):
        r=self.incoming();r.event({'Event':'Newchannel','Uniqueid':'1791800001.3','Channel':'SIP/trunk-c','CallerIDNum':'79990000000'})
        self.assertEqual(2,len(r.rows()))
    def test_snapshot_recovery_marks_missing_legs_uncertain(self):
        r=self.incoming();r.event({'Event':'SnapshotStart'});r.event({'Event':'StatusComplete'})
        self.assertEqual('interrupted',r.rows()[0]['status'])
    def test_no_unrelated_calls_merged_by_bridge(self):
        r=self.incoming();r.event({'Event':'Newchannel','Uniqueid':'1791800001.3','Channel':'SIP/102-c'})
        r.event({'Event':'Bridge','Uniqueid1':'1791800000.1','Uniqueid2':'1791800001.3'})
        self.assertEqual(2,len(r.rows()))
    def test_durable_outbox_survives_failure_and_does_not_starve_after_ack(self):
        with tempfile.TemporaryDirectory() as temp:
            box=Outbox(str(Path(temp)/'state.sqlite'));r=self.incoming();box.save(r)
            with patch('live_history.post',side_effect=IOError):
                self.assertRaises(IOError,box.send,{},True)
            self.assertEqual(1,box.db.execute('SELECT COUNT(*) FROM outbox').fetchone()[0])
            with patch('live_history.post') as post:
                box.send({},True);self.assertEqual(1,len(json.loads(post.call_args[0][1])['calls']))
            box.save(r);self.assertEqual(0,box.db.execute('SELECT COUNT(*) FROM outbox').fetchone()[0])
            self.assertEqual(r.calls,box.restore())
    def test_local_routing_halves_and_late_authoritative_linkedid(self):
        r=Reducer()
        r.event({'Event':'Newchannel','Uniqueid':'1791800000.1','Channel':'Local/101@group-abc;1'})
        r.event({'Event':'Newchannel','Uniqueid':'1791800000.2','Channel':'Local/101@group-abc;2'})
        r.event({'Event':'LocalBridge','Channel1':'Local/101@group-abc;1','Channel2':'Local/101@group-abc;2'})
        self.assertEqual(1,len(r.calls))
        r.event({'Event':'Status','Uniqueid':'1791800000.2','Channel':'Local/101@group-abc;2','Variable':'CHANNEL(linkedid)=1791799999.9'})
        self.assertEqual(['1791799999.9'],list(r.calls))
    def test_actual_asterisk_11_status_extension_and_linkedid(self):
        r=Reducer();r.event({'Event':'Status','Uniqueid':'1791800000.2','Channel':'SIP/101-a','CallerIDNum':'101','Extension':'101','ChannelStateDesc':'Up','Variable':'CHANNEL(linkedid)=1791800000.1'})
        r.event({'Event':'Status','Uniqueid':'1791800000.1','Channel':'SIP/trunk-b','CallerIDNum':'79990000000','Extension':'600','ChannelStateDesc':'Up','Variable':'CHANNEL(linkedid)=1791800000.1'})
        self.assertEqual(1,len(r.rows()));self.assertEqual('talking',r.rows()[0]['status']);self.assertEqual('79990000000',r.rows()[0]['caller_number'])
    def test_local_only_channels_are_not_calls(self):
        r=Reducer();r.event({'Event':'Newchannel','Uniqueid':'1791800000.1','Channel':'Local/101@routing-a'})
        self.assertEqual([],r.rows())
if __name__=='__main__':unittest.main()
