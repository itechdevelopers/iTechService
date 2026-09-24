import unittest
from datetime import date,datetime
import receipt_counts as counts

class FakeClient:
    def __init__(self):self.truncated=False;self.calls=0
    def rows(self,schema,entity,fields,where,top,limit):
        self.calls+=1
        self.truncated=self.calls==1
        return []

class ReceiptCountsTest(unittest.TestCase):
    def row(self,key='a'):
        return {'Ref_Key':key,'Date':'2026-09-22T23:59:59','Posted':True,'DeletionMark':False,'Статус':'Пробит','Склад_Key':counts.ZERO}
    def test_counts_receipts_not_items_and_publishes_zero_days(self):
        row=self.row();row['Количество']=99
        days=counts.aggregate([row],{},date(2026,9,22),date(2026,9,23))
        self.assertEqual([1,0],[d['quantity'] for d in days])
    def test_duplicates_status_and_date_must_fail(self):
        for rows in [[self.row(),self.row()],[dict(self.row(),Posted=False)],[dict(self.row(),Date='2026-09-24T00:00:00')]]:
            with self.assertRaises(ValueError):counts.aggregate(rows,{},date(2026,9,22),date(2026,9,23))
    def test_truncated_interval_is_split_before_publication(self):
        client=FakeClient()
        self.assertEqual([],counts.collect(client,None,datetime(2026,1,1),datetime(2026,1,2)))
        self.assertEqual(3,client.calls)
    def test_unresolvable_truncation_fails_closed(self):
        with self.assertRaises(ValueError):counts.collect(FakeClient(),None,datetime(2026,1,1),datetime(2026,1,1,0,0,1))

if __name__=='__main__':unittest.main()
