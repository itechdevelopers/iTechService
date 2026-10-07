"""Bounded GET-only stock lookup through the existing protected connector."""
import json, os, sys
from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
class InvalidArticle(ValueError):
    pass

RESERVATIONS = 'AccumulationRegister_ТоварыКОтгрузке'


def protected_client(api, schema):
    # This process adds one metadata-confirmed read-only function, not a public query API.
    api.SAFE_FUNCTIONS.add((RESERVATIONS, 'Balance'))

    class ArticleClient(api.Client):
        def request(self, resource, params=None):
            if resource.startswith(RESERVATIONS + '/Balance(') and params and '$orderby' in params:
                # Polymorphic 1C references are scalar strings, without the GUID suffix.
                params['$orderby'] = params['$orderby'].replace('ДокументОтгрузки_Key', 'ДокументОтгрузки').replace('Получатель_Key', 'Получатель')
            return super().request(resource, params)

    return ArticleClient(api.credentials(), schema)


ZERO = '00000000-0000-0000-0000-000000000000'

def search(api, client, schema, article):
    if not isinstance(article, str) or not article.strip() or len(article) > 128 or any(ord(c) < 32 for c in article):
        raise InvalidArticle('Введите артикул длиной от 1 до 128 символов.')
    article = article.strip()
    def rows(entity, fields, condition, maximum=100, function=None, parameters=None):
        data = client.rows(schema, entity, fields, condition, top=min(100, maximum), limit=maximum,
                           **({'function': function, 'parameters': parameters} if function else {}))
        if client.truncated or len(data) >= maximum:
            raise api.SafeError('Результат превышает лимит.')
        return data
    cache = {}
    def ref(entity, key, fields=('Ref_Key', 'Description')):
        if not key or key == ZERO:
            return None
        token = (entity, key, tuple(fields))
        if token not in cache:
            result = rows(entity, list(fields), 'Ref_Key eq ' + api.guid(key), 2)
            if len(result) != 1:
                raise api.SafeError('Связанная запись недоступна.')
            cache[token] = result[0]
        return cache[token]
    def phones(entity, key):
        if not key or key == ZERO:
            return []
        token = (entity, key, 'phones')
        if token not in cache:
            contacts = rows(entity, ['Тип', 'НомерТелефона', 'Представление'],
                            'Ref_Key eq ' + api.guid(key) + " and Тип eq 'Телефон'", 20)
            cache[token] = list(dict.fromkeys(contact['НомерТелефона'] or contact['Представление']
                                             for contact in contacts if contact['НомерТелефона'] or contact['Представление']))
        return cache[token]

    def reservation(group):
        result = {'quantity': group['ВРезервеBalance'], 'order_id': group['ДокументОтгрузки'],
                  'number': None, 'customer_name': None, 'phones': [], 'notice': None}
        if group['ДокументОтгрузки_Type'] != 'StandardODATA.Document_ЗаказКлиента':
            result['notice'] = 'Резерв связан с другим видом документа 1С; реквизиты заказа клиента не определены.'
            return result
        order = ref('Document_ЗаказКлиента', group['ДокументОтгрузки'],
                    ('Ref_Key', 'Number', 'Date', 'Партнер_Key', 'КонтактноеЛицо_Key', 'Posted', 'DeletionMark'))
        if not order:
            result['notice'] = 'Реквизиты заказа клиента отсутствуют.'
            return result
        result.update(number=order['Number'], date=order['Date'])
        if order['DeletionMark'] or not order['Posted']:
            result['notice'] = 'В регистре есть резерв, но заказ удалён или не проведён. Требуется проверка в 1С.'
        contact = ref('Catalog_КонтактныеЛицаПартнеров', order['КонтактноеЛицо_Key'])
        partner = ref('Catalog_Партнеры', order['Партнер_Key'], ('Ref_Key', 'Description', 'НаименованиеПолное'))
        result['customer_name'] = contact['Description'] if contact else ((partner['НаименованиеПолное'] or partner['Description']) if partner else None)
        if contact:
            result['phones'] = phones('Catalog_КонтактныеЛицаПартнеров_КонтактнаяИнформация', contact['Ref_Key'])
        if not result['phones'] and partner:
            result['phones'] = phones('Catalog_Партнеры_КонтактнаяИнформация', partner['Ref_Key'])
            result['phone_source'] = 'телефон клиента в 1С'
        return result

    products = rows(api.ITEMS, ['Ref_Key', 'Description', 'Артикул', 'Code', 'ЕдиницаИзмерения_Key'],
                    'DeletionMark eq false and IsFolder eq false and (Артикул eq ' + api.literal(article) +
                    ' or Code eq ' + api.literal(article) + ')', 11)
    result = []
    stamp = datetime.now(ZoneInfo('Asia/Vladivostok')).replace(tzinfo=None).isoformat(timespec='seconds')
    for product in products:
        condition = 'Номенклатура_Key eq ' + api.guid(product['Ref_Key'])
        barcodes = rows('InformationRegister_ШтрихкодыНоменклатуры',
                        ['Штрихкод', 'Характеристика_Key', 'Упаковка_Key'], condition, 100)
        barcodes = list({(row['Штрихкод'], row['Характеристика_Key'], row['Упаковка_Key']): row for row in barcodes}.values())
        balances = rows(api.STOCK, ['Склад_Key', 'Характеристика_Key', 'ВНаличииBalance', 'КОтгрузкеBalance'],
                        '(ВНаличииBalance gt 0 or КОтгрузкеBalance gt 0)', 100, 'Balance',
                        {'Condition': condition, 'Period': stamp, 'Dimensions': 'Номенклатура,Характеристика,Склад'})
        reserved = rows(RESERVATIONS,
                        ['Склад_Key', 'Характеристика_Key', 'ДокументОтгрузки', 'ДокументОтгрузки_Type', 'ВРезервеBalance'],
                        'ВРезервеBalance gt 0', 100, 'Balance',
                        {'Condition': condition, 'Period': stamp,
                         'Dimensions': 'Склад,Номенклатура,Характеристика,ДокументОтгрузки,Получатель'})
        by_location = {(row['Склад_Key'], row['Характеристика_Key']): row for row in balances}
        for row in reserved:
            by_location.setdefault((row['Склад_Key'], row['Характеристика_Key']),
                                   {'Склад_Key': row['Склад_Key'], 'Характеристика_Key': row['Характеристика_Key'],
                                    'ВНаличииBalance': None, 'КОтгрузкеBalance': None})
        locations = []
        for balance in by_location.values():
            characteristic = balance['Характеристика_Key']
            locations.append({
                'warehouse': ref(api.WAREHOUSES, balance['Склад_Key']),
                'characteristic': ref('Catalog_ХарактеристикиНоменклатуры', characteristic),
                'quantity': balance['ВНаличииBalance'], 'reserved': balance['КОтгрузкеBalance'],
                'reservations': [reservation(row) for row in reserved
                                 if row['Склад_Key'] == balance['Склад_Key'] and row['Характеристика_Key'] == characteristic],
                'barcodes': [{'barcode': row['Штрихкод'],
                              'package': ref('Catalog_УпаковкиЕдиницыИзмерения', row['Упаковка_Key'])}
                             for row in barcodes if row['Характеристика_Key'] == characteristic]})
        result.append(dict(product, unit=ref('Catalog_УпаковкиЕдиницыИзмерения', product['ЕдиницаИзмерения_Key']), locations=locations))
    stores = {}
    for product in result:
        for location in product['locations']:
            warehouse = location['warehouse']
            if not warehouse:
                raise api.SafeError('Склад не определён.')
            store = stores.setdefault(warehouse['Ref_Key'], {'warehouse': warehouse, 'items': []})
            store['items'].append(dict(location, product={key: value for key, value in product.items() if key != 'locations'}))
    return {'article': article, 'products': result,
            'stores': sorted(stores.values(), key=lambda store: store['warehouse']['Description'].casefold()),
            'reservation_source': RESERVATIONS + '/Balance.ВРезервеBalance', 'as_of': stamp,
            'read_at': datetime.now(ZoneInfo('Asia/Vladivostok')).isoformat(timespec='seconds'),
            'source': 'AccumulationRegister_ТоварыНаСкладах/Balance', 'origin': 'direct_1c_odata'}

def main():
    try:
        args = json.load(sys.stdin)
        connector = Path(os.environ['AIS_ONE_C_ODATA_CONNECTOR']).resolve()
        sys.path.insert(0, str(connector))
        import odata
        schema = odata.Schema((connector / 'local/metadata.xml').read_bytes())
        result = search(odata, protected_client(odata, schema), schema, args.get('article'))
        print(json.dumps(result, ensure_ascii=False))
        return 0
    except InvalidArticle as error:
        print(json.dumps({'error': str(error)}, ensure_ascii=False)); return 2
    except Exception:
        print(json.dumps({'error': 'Не удалось получить полный ответ 1С. Попробуйте позже.'}, ensure_ascii=False)); return 1
if __name__ == '__main__':
    sys.exit(main())
