"""Read-only loyalty lookup. Receipt facts and register counters are never added together."""
import base64
import json
import os
import re
import sys
import time
from collections import defaultdict
from datetime import datetime
from decimal import Decimal
from pathlib import Path
from zoneinfo import ZoneInfo

PROGRAM = 'a3a42325-d13c-11e9-80db-968d2a071e7d'
REGISTER = 'AccumulationRegister_ПродажиПоКартеЛояльности'
ZERO = '00000000-0000-0000-0000-000000000000'

class InvalidPhone(ValueError): pass

def normalize_phone(value):
    if not isinstance(value, str) or len(value) > 40 or re.search(r'[^0-9+()\s-]', value):
        raise InvalidPhone('Введите российский номер телефона: 10 цифр или 11 цифр с 7/8.')
    digits = re.sub(r'\D', '', value)
    if len(digits) == 10: digits = '7' + digits
    if len(digits) == 11 and digits[0] == '8': digits = '7' + digits[1:]
    if len(digits) != 11 or digits[0] != '7':
        raise InvalidPhone('Введите российский номер телефона: 10 цифр или 11 цифр с 7/8.')
    return digits

def counter(quantity, threshold):
    """1C resets on the NEXT purchase, including an initial -5; retain raw value."""
    value = Decimal(str(quantity)); step = Decimal(str(threshold))
    if value != value.to_integral_value() or step <= 1: return None
    return int(value) % int(step)

def audit_cycles(history, threshold):
    """Validate gifts against quantities per receipt; never infer a missed gift from a reset."""
    by_check = {}
    for entry in history:
        if entry['kind'] != 'sale':
            return False # Return semantics need the original receipt; do not promise eligibility.
        group = by_check.setdefault(entry['document_id'], {'quantity': Decimal(0), 'gifts': Decimal(0)})
        quantity = Decimal(entry['quantity'])
        if quantity <= 0 or quantity != quantity.to_integral_value(): return False
        group['quantity'] += quantity
        if entry['promotional_price']: group['gifts'] += quantity
    accumulated = 0
    for group in by_check.values():
        quantity = int(group['quantity'])
        expected = (accumulated + quantity) // threshold - accumulated // threshold
        if group['gifts'] != expected: return False
        accumulated += quantity
    return True

class Reader:
    def __init__(self, api, client, schema):
        self.api, self.client, self.schema = api, client, schema
        self.started = time.monotonic(); self.requests = 0
    def rows(self, entity, fields, condition, limit=1000, **kwargs):
        self.budget()
        data = self.client.rows(self.schema, entity, fields, condition, top=min(100, limit), limit=limit, **kwargs)
        if self.client.truncated: raise self.api.SafeError('История превышает лимит; частичный результат запрещён.')
        keys = self.schema.keys.get(self.schema.sets.get(entity), [])
        if not kwargs.get('function') and keys:
            ids = [tuple(row.get(key) for key in keys) for row in data]
            if len(ids) != len(set(ids)): raise self.api.SafeError('Повторяющиеся строки ответа.')
        return data
    def budget(self):
        self.requests = len(self.client.stats)
        if self.requests >= 100 or time.monotonic() - self.started > 100:
            raise self.api.SafeError('Превышен бюджет чтения. Частичный ответ запрещён.')
    def refs(self, entity, fields, refs, field='Ref_Key'):
        refs = list(dict.fromkeys(r for r in refs if r and r != ZERO))
        # Batch by URL size, as in the existing connector; no wildcard expansions.
        self.budget()
        result = self.client.rows_by_refs(self.schema, entity, fields, field, refs, limit=1000)
        if self.client.truncated: raise self.api.SafeError('Неполная детализация.')
        return result
    def constant(self, entity):
        # 1C singleton constants reject collection $filter/$orderby with HTTP 500.
        # Exactly one fixed singleton, GET only, no user-controlled URL or redirects.
        assert entity == 'Constant_ЦенаТовараПоЛояльности'
        self.schema.fields(entity); self.budget()
        username, password = self.client.credentials
        request = self.api.http.Request(self.api.BASE + self.api.url.quote(entity) + '?$format=json',
            headers={'Accept': 'application/json', 'Authorization': 'Basic ' + base64.b64encode((username + ':' + password).encode()).decode()}, method='GET')
        with self.client.opener.open(request, timeout=20) as response:
            raw = response.read(4097)
            if len(raw) > 4096: raise self.api.SafeError('Слишком большой ответ константы.')
            self.client.stats.append({'method':'GET','status':response.status,'bytes':len(raw)})
        values = json.loads(raw)['value']
        if len(values) != 1: raise self.api.SafeError('Неоднозначная настройка цены акции.')
        return values[0]['Value']

def phone_filter(api, field, phone):
    # Equality queries use the stored phone index; nested replace() is not supported by this 1C.
    variants = [phone, '8' + phone[1:], '+' + phone,
                '+7 %s-%s-%s-%s' % (phone[1:4], phone[4:7], phone[7:9], phone[9:]),
                '+7 (%s) %s-%s-%s' % (phone[1:4], phone[4:7], phone[7:9], phone[9:])]
    return '(' + ' or '.join(field + ' eq ' + api.literal(v) for v in variants) + ')'

def search(api, client, schema, phone):
    phone = normalize_phone(phone); r = Reader(api, client, schema)
    cards = r.rows('Catalog_КартыЛояльности', ['Ref_Key','Description','Телефон','Партнер_Key','Статус','DeletionMark'],
                   'DeletionMark eq false and ' + phone_filter(api, 'Телефон', phone), limit=10)
    if len(cards) >= 10: raise api.SafeError('Слишком много карт для телефона.')
    for card in cards:
        if normalize_phone(card['Телефон']) != phone: raise api.SafeError('Телефон карты не совпадает.')
    if not cards:
        # Phone can be stored only on the customer, not on the card.
        contacts = r.rows('Catalog_Партнеры_КонтактнаяИнформация', ['Ref_Key','НомерТелефона'],
                         phone_filter(api, 'НомерТелефона', phone), limit=20)
        partners = [v['Ref_Key'] for v in contacts if normalize_phone(v['НомерТелефона']) == phone]
        cards = r.refs('Catalog_КартыЛояльности', ['Ref_Key','Description','Телефон','Партнер_Key','Статус','DeletionMark'], partners, 'Партнер_Key')
        cards = [v for v in cards if not v['DeletionMark']]
        if len(cards) > 10: raise api.SafeError('Слишком много карт для телефона.')
    result = {'cards': [], 'read_at': datetime.now(ZoneInfo('Asia/Vladivostok')).isoformat(timespec='seconds'),
              'complete': True, 'methodology': 'glass-loyalty-v1', 'source': REGISTER, 'warnings': []}
    if not cards: return result
    programs = r.refs('Document_УстановкаЛояльностиПоТовару', ['Ref_Key','Наименование','КоличествоДляАкции','Posted','DeletionMark','Date'], [PROGRAM])
    if len(programs) != 1 or not programs[0]['Posted'] or programs[0]['DeletionMark']: raise api.SafeError('Правило акции недоступно.')
    program = programs[0]; threshold = int(program['КоличествоДляАкции'])
    if threshold != 5: raise api.SafeError('Правило акции изменилось; требуется проверка методики.')
    rule_rows = r.rows('Document_УстановкаЛояльностиПоТовару_Товары', ['Ref_Key','LineNumber','Номенклатура_Key','КоличествоДляАкции'], 'Ref_Key eq '+api.guid(PROGRAM))
    eligible = {v['Номенклатура_Key'] for v in rule_rows}
    gift_price = Decimal(str(r.constant('Constant_ЦенаТовараПоЛояльности')))
    result.update(program=program['Наименование'], threshold=threshold, gift_price=str(gift_price))
    for card in cards:
        r.budget(); card_id = card['Ref_Key']; condition = 'КартаЛояльности_Key eq ' + api.guid(card_id)
        moves = r.rows(REGISTER+'_RecordType', list(schema.fields(REGISTER+'_RecordType')), 'Active eq true and '+condition)
        moves = [v for v in moves if v['ДокументУстановкаЛояльностиПоТовару_Key'] == PROGRAM]
        items = eligible | {v['Номенклатура_Key'] for v in moves}
        documents = {}; lines = []
        for entity, kind in [('Document_ЧекККМ','sale'),('Document_ЧекККМВозврат','return')]:
            headers = r.rows(entity, ['Ref_Key','Number','Date','Posted','DeletionMark','Архивный','Статус','Кассир_Key','Склад_Key'],
                condition+" and DeletionMark eq false and Date ge datetime"+api.literal(program['Date']), limit=500)
            headers = [h for h in headers if h['Posted'] and h['Статус'] == 'Пробит']
            for h in headers: documents[h['Ref_Key']] = dict(h, kind=kind)
            fields = ['Ref_Key','LineNumber','Номенклатура_Key','Количество','Цена','Сумма']
            if 'Продавец_Key' in schema.fields(entity+'_Товары'): fields.append('Продавец_Key')
            entries = r.refs(entity+'_Товары', fields, [h['Ref_Key'] for h in headers])
            lines.extend(v for v in entries if v['Номенклатура_Key'] in items)
        products = {v['Ref_Key']:v for v in r.refs('Catalog_Номенклатура',['Ref_Key','Description','Code'],[v['Номенклатура_Key'] for v in lines]+[v['Номенклатура_Key'] for v in moves])}
        staff_ids = [v.get('Продавец_Key') for v in lines] + [h['Кассир_Key'] for h in documents.values()]
        staff = {v['Ref_Key']:v['Description'] for v in r.refs('Catalog_Пользователи',['Ref_Key','Description'],staff_ids)}
        warehouses = {v['Ref_Key']:v['Description'] for v in r.refs('Catalog_Склады',['Ref_Key','Description'],[h['Склад_Key'] for h in documents.values()])}
        history = []; total = Decimal(0); gifts = Decimal(0); ambiguous = False
        for row in sorted(lines, key=lambda v:(documents[v['Ref_Key']]['Date'],v['Ref_Key'],int(v['LineNumber']))):
            doc = documents[row['Ref_Key']]; qty = Decimal(str(row['Количество'])); amount = Decimal(str(row['Сумма']))
            if qty <= 0 or qty != qty.to_integral_value(): ambiguous = True
            sign = -1 if doc['kind']=='return' else 1
            total += sign*qty
            # Price evidence, not the unrelated gmb_Подарок flag (false on proven fifth glasses).
            promotional_price = qty > 0 and amount == gift_price*qty
            if promotional_price: gifts += sign*qty
            employee = row.get('Продавец_Key')
            if not employee or employee == ZERO: employee = doc['Кассир_Key']
            history.append({'date':doc['Date'],'number':doc['Number'],'document_id':doc['Ref_Key'],'line':row['LineNumber'],
                'kind':doc['kind'],'product':products.get(row['Номенклатура_Key'],{}).get('Description','Название недоступно'),
                'product_id':row['Номенклатура_Key'],'quantity':str(qty),'amount':str(amount),'unit_price':str(row['Цена']),
                'promotional_price':promotional_price,'employee':staff.get(employee,'Не указан в 1С'),
                'employee_source':'Продавец строки' if row.get('Продавец_Key') not in (None,ZERO) else 'Кассир чека',
                'warehouse':warehouses.get(doc['Склад_Key'],'Склад не указан'),'archived':doc['Архивный']})
        raw = sum((Decimal(str(v['Количество'])) * (1 if v['RecordType']=='Receipt' else -1) for v in moves),Decimal(0))
        # Check the independently computed register balance. Concurrent updates fail closed.
        api.SAFE_FUNCTIONS.add((REGISTER,'Balance'))
        balance_rows = r.rows(REGISTER,['КартаЛояльности_Key','ДокументУстановкаЛояльностиПоТовару_Key','КоличествоBalance'],condition,
            function='Balance', parameters={'Condition':condition,'Dimensions':'КартаЛояльности,ДокументУстановкаЛояльностиПоТовару'})
        balance = sum((Decimal(str(v['КоличествоBalance'])) for v in balance_rows if v['ДокументУстановкаЛояльностиПоТовару_Key']==PROGRAM),Decimal(0))
        if raw != balance: raise api.SafeError('Данные акции изменились во время чтения. Повторите поиск.')
        receipts = sum((Decimal(str(v['Количество'])) for v in moves if v['RecordType']=='Receipt'),Decimal(0))
        sales_qty = sum((Decimal(v['quantity']) for v in history if v['kind']=='sale'),Decimal(0))
        # Missing archived receipts or returns not reflected in the register prohibit a promise.
        open_qty = sum((Decimal(v['quantity']) for v in history if v['kind']=='sale' and not v['archived']),Decimal(0))
        pending_qty = sales_qty - receipts
        pending_ok = pending_qty == 0 or (pending_qty == open_qty and pending_qty > 0)
        reconciled = (pending_ok and counter(total,threshold)==counter(balance+pending_qty,threshold)
                      and audit_cycles(history,threshold) and not ambiguous
                      and all(v['RecordType'] in ('Receipt','Expense') for v in moves)
                      and all(Decimal(str(v['Количество'])) == threshold for v in moves if v['RecordType']=='Expense'))
        resets = [{'date':v['Period'],'quantity':str(v['Количество']),'document_id':v['Recorder'],
                   'document_type':v['Recorder_Type'],'line':v['LineNumber'],
                   'product':products.get(v['Номенклатура_Key'],{}).get('Description','Название недоступно')}
                  for v in moves if v['RecordType']=='Expense']
        progress = counter(total,threshold) if reconciled else None
        warnings=[]
        if reconciled and pending_qty > 0: warnings.append('Учтены новые пробитые чеки открытой смены: '+str(pending_qty)+'. Они ещё не вошли в регистр акции; после закрытия смены выполняется повторная сверка.')
        if not reconciled: warnings.append('Чеки и счётчик 1С пока не согласованы: право на подарок не подтверждено. Возможны незакрытая смена, возврат или неполная история чеков.')
        if card['Статус'] != 'Действует': warnings.append('Карта не действует; выдачу подарка нужно проверить в 1С.')
        result['cards'].append({'id':card_id,'name':card['Description'],'status':card['Статус'],
            'history':history,'resets':resets,'raw_balance':str(balance),'receipt_quantity':str(sales_qty),'net_quantity':str(total),
            'promotional_quantity':str(gifts),'progress':progress,'until_gift':threshold-progress if progress is not None else None,
            'reconciled':reconciled,'pending_quantity':str(pending_qty),'warnings':warnings,'movements':moves})
    result['requests'] = len(client.stats)
    result['read_at'] = datetime.now(ZoneInfo('Asia/Vladivostok')).isoformat(timespec='seconds')
    return result

def main():
    try:
        args=json.load(sys.stdin); phone=normalize_phone(args.get('phone'))
        connector=Path(os.environ['AIS_ONE_C_ODATA_CONNECTOR']).resolve(); sys.path.insert(0,str(connector))
        import odata
        schema=odata.Schema((connector/'local/metadata.xml').read_bytes())
        class BoundedClient(odata.Client):
            def __init__(self, *args):
                super().__init__(*args); self.deadline = time.monotonic() + 100
            def request(self, resource, params=None, method='GET'):
                if len(self.stats) >= 100 or time.monotonic() > self.deadline:
                    raise odata.SafeError('Лимит чтения')
                return super().request(resource, params, method=method)
        result=search(odata,BoundedClient(odata.credentials(),schema),schema,phone)
        print(json.dumps(result,ensure_ascii=False)); return 0
    except InvalidPhone as error:
        print(json.dumps({'error':str(error)},ensure_ascii=False)); return 2
    except Exception:
        print(json.dumps({'error':'Не удалось получить полную согласованную историю 1С. Повторите позже.'},ensure_ascii=False)); return 1
if __name__=='__main__': sys.exit(main())
