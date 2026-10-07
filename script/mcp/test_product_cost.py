import json
import unittest
from datetime import datetime
from decimal import Decimal
from types import SimpleNamespace
import uuid
import product_cost as pc

P='11111111-1111-1111-1111-111111111111'
C='22222222-2222-2222-2222-222222222222'
U='33333333-3333-3333-3333-333333333333'
A='44444444-4444-4444-4444-444444444444'
B='55555555-5555-5555-5555-555555555555'

class SafeError(Exception): pass

def guid(value): return "guid'"+str(uuid.UUID(value))+"'"
def moment(value):
    dt=datetime.fromisoformat(value)
    if dt.tzinfo: raise ValueError()
    return dt.isoformat(timespec='seconds')
API=SimpleNamespace(SafeError=SafeError,guid=guid,moment=moment,literal=lambda x:"'"+x.replace("'","''")+"'")

class Schema:
    def function(self,e,n,p): return e+'/Balance',{},[]

class FixtureClient:
    def __init__(self):
        self._approved_routes={};self.calls=[];self.matches=1;self.package=False
        self.quantity='4';self.cost='100.50';self.analytics=True;self.fail=False;self.overflow=False
    def request(self,route,params):
        self.calls.append((route,params))
        if self.fail: raise SafeError('HTTP 500')
        if 'ШтрихкодыНоменклатуры' in route:
            rows=[{'Штрихкод':'00123','Номенклатура_Key':P,'Характеристика_Key':C,'Упаковка_Key':B if self.package else pc.ZERO}]*self.matches
        elif route=='Catalog_Номенклатура': rows=[{'Ref_Key':P,'Description':'Товар','ЕдиницаИзмерения_Key':U}]
        elif route=='Catalog_ХарактеристикиНоменклатуры': rows=[{'Ref_Key':C,'Description':'Синий'}]
        elif route=='Catalog_УпаковкиЕдиницыИзмерения':
            rows=[{'Ref_Key':B if B in params['$filter'] else U,'Description':'Упаковка' if B in params['$filter'] else 'шт.', 'Числитель':'6','Знаменатель':'1'}]
        elif route=='Catalog_КлючиАналитикиУчетаНоменклатуры':
            rows=[{'Ref_Key':A,'МестоХранения':U,'МестоХранения_Type':'StandardODATA.Catalog_Склады','Серия_Key':C,'Назначение_Key':pc.ZERO}] if self.analytics else []
        else:
            rows=[{'Организация_Key':U,'Партия':P,'Партия_Type':'Document_ПриобретениеТоваровУслуг','РазделУчета':'ТоварыНаСкладах',
                   'ВидЗапасов_Key':B,'АналитикаУчетаПартий_Key':C,'АналитикаФинансовогоУчета':pc.ZERO,
                   'АналитикаФинансовогоУчета_Type':'Undefined','ВидДеятельностиНДС':'Облагаемая','КоличествоBalance':self.quantity,'СтоимостьBalance':self.cost}]
        if self.overflow: rows=rows*params['$top']
        return json.dumps({'value':rows})

class ProductCostTests(unittest.TestCase):
    def setUp(self): self.client=FixtureClient();self.service=pc.ProductCost(API,self.client,Schema())
    def run_cost(self,**args): return self.service.run({'barcode':'00123',**args})
    def test_success_characteristic_and_leading_zero(self):
        r=self.run_cost();self.assertEqual(r['status'],'ok');self.assertEqual(r['barcode'],'00123')
        self.assertEqual(r['breakdown'][0]['cost_per_unit'],'25.125');self.assertEqual(r['product']['characteristic']['Description'],'Синий')
        self.assertEqual(self.client.calls[0][1]['$filter'],"Штрихкод eq '00123'")
    def test_escaping(self):
        self.run_cost(barcode="00'a");self.assertEqual(self.client.calls[0][1]['$filter'],"Штрихкод eq '00''a'")
    def test_numeric_rejected(self):
        with self.assertRaises(ValueError): self.run_cost(barcode=123)
        self.assertEqual(self.client.calls,[])
    def test_multiple_matches_do_not_read_cost(self):
        self.client.matches=2;r=self.run_cost();self.assertEqual(r['status'],'selection_required')
        self.assertEqual(len(r['variants']),2);self.assertFalse(any('/Balance' in x[0] for x in self.client.calls))
    def test_unknown_selection(self):
        self.assertEqual(self.run_cost(product_id=B)['status'],'selection_required')
    def test_not_found(self):
        self.client.matches=0;self.assertEqual(self.run_cost()['status'],'not_found')
    def test_missing_unit_does_not_compute_cost(self):
        original=self.service.ref
        self.service.ref=lambda entity,ref,extra=(): None if ref==U else original(entity,ref,extra)
        r=self.run_cost();self.assertEqual(r['status'],'unit_unavailable');self.assertNotIn('breakdown',r)
    def test_package_factor(self):
        self.client.package=True;r=self.run_cost();self.assertEqual(r['package_factor'],'6');self.assertEqual(r['breakdown'][0]['cost_per_unit'],'150.750')
    def test_missing_cost_is_not_zero(self):
        self.client.cost=None;r=self.run_cost();self.assertEqual(r['status'],'cost_unavailable');self.assertIsNone(r['breakdown'][0]['cost_per_unit'])
    def test_zero_quantity_not_divided(self):
        self.client.quantity='0';self.assertIsNone(self.run_cost()['breakdown'][0]['cost_per_unit'])
    def test_no_balance(self):
        self.client.analytics=False;r=self.run_cost();self.assertEqual(r['status'],'cost_unavailable');self.assertEqual(r['breakdown'],[])
    def test_1c_error(self):
        self.client.fail=True
        with self.assertRaises(SafeError): self.run_cost()
    def test_incomplete_data_fails_closed(self):
        self.client.overflow=True
        with self.assertRaises(SafeError): self.run_cost()
    def test_scope_and_party(self):
        r=self.run_cost(organization_id=U,warehouse_id=U,party_id=B);self.assertEqual(r['status'],'cost_unavailable')
        self.assertTrue(any("cast(guid'" in q['$filter'] for _,q in self.client.calls))
    def test_future_and_invalid_uuid(self):
        with self.assertRaises(ValueError): self.run_cost(as_of='2999-01-01')
        with self.assertRaises(ValueError): self.run_cost(product_id="' or true")

if __name__=='__main__': unittest.main()
