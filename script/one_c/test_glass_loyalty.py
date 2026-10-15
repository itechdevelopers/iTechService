import unittest
from types import SimpleNamespace
import glass_loyalty as g

class GlassLoyaltyTest(unittest.TestCase):
    def test_phone_variants_and_injection(self):
        for value in ['+7 (999) 123-45-67', '89991234567','9991234567']:
            self.assertEqual(g.normalize_phone(value),'79991234567')
        for value in [None, '', "79991234567' or true", '1234','19991234567', '7'*100]:
            with self.assertRaises(g.InvalidPhone):g.normalize_phone(value)
    def test_negative_balance_and_next_cycle(self):
        self.assertEqual([g.counter(x,5) for x in [-5,-4,-3,-2,-1,0,1]],[0,1,2,3,4,0,1])
        self.assertIsNone(g.counter('1.5',5))
    def entry(self, number, qty, gift=False, kind='sale'):
        return {'document_id':number,'quantity':str(qty),'promotional_price':gift,'kind':kind}
    def test_gift_then_paid_next_cycle_is_not_a_missed_gift(self):
        rows=[self.entry('a',1),self.entry('b',1),self.entry('c',2),self.entry('d',1,True),self.entry('e',1)]
        self.assertTrue(g.audit_cycles(rows,5))
    def test_fourth_and_fifth_in_same_receipt_can_be_in_either_line_order(self):
        rows=[self.entry('a',3),self.entry('b',1,True),self.entry('b',1)]
        self.assertTrue(g.audit_cycles(rows,5))
    def test_paid_fifth_or_early_gift_or_return_does_not_confirm_eligibility(self):
        for rows in [[self.entry('a',5)],[self.entry('a',1,True)],[self.entry('a',1,False,'return')]]:
            self.assertFalse(g.audit_cycles(rows,5))
    def test_partial_and_duplicate_pages_fail_closed(self):
        class SafeError(Exception):pass
        api=SimpleNamespace(SafeError=SafeError)
        schema=SimpleNamespace(keys={'T':['Ref_Key']},sets={'E':'T'})
        client=SimpleNamespace(stats=[],truncated=True,rows=lambda *a,**kw:[{'Ref_Key':'a'}])
        with self.assertRaises(SafeError):g.Reader(api,client,schema).rows('E',['Ref_Key'],'true')
        client.truncated=False;client.rows=lambda *a,**kw:[{'Ref_Key':'a'},{'Ref_Key':'a'}]
        with self.assertRaises(SafeError):g.Reader(api,client,schema).rows('E',['Ref_Key'],'true')
if __name__=='__main__':unittest.main()
