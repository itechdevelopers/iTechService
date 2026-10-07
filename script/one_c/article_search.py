"""Bounded GET-only stock lookup through the existing protected connector."""
import json, os, sys
from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
class InvalidArticle(ValueError):
    pass

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
        token = (entity, key)
        if token not in cache:
            result = rows(entity, list(fields), 'Ref_Key eq ' + api.guid(key), 2)
            if len(result) != 1:
                raise api.SafeError('Связанная запись недоступна.')
            cache[token] = result[0]
        return cache[token]
    products = rows(api.ITEMS, ['Ref_Key', 'Description', 'Артикул', 'Code', 'ЕдиницаИзмерения_Key'],
                    'DeletionMark eq false and IsFolder eq false and (Артикул eq ' + api.literal(article) +
                    ' or Code eq ' + api.literal(article) + ')', 11)
    result = []
    stamp = datetime.now(ZoneInfo('Asia/Vladivostok')).replace(tzinfo=None).isoformat(timespec='seconds')
    for product in products:
        condition = 'Номенклатура_Key eq ' + api.guid(product['Ref_Key'])
        barcodes = rows('InformationRegister_ШтрихкодыНоменклатуры',
                        ['Штрихкод', 'Характеристика_Key', 'Упаковка_Key'], condition, 100)
        balances = rows(api.STOCK, ['Склад_Key', 'Характеристика_Key', 'ВНаличииBalance', 'КОтгрузкеBalance'],
                        'ВНаличииBalance gt 0', 100, 'Balance',
                        {'Condition': condition, 'Period': stamp, 'Dimensions': 'Номенклатура,Характеристика,Склад'})
        locations = []
        for balance in balances:
            characteristic = balance['Характеристика_Key']
            locations.append({
                'warehouse': ref(api.WAREHOUSES, balance['Склад_Key']),
                'characteristic': ref('Catalog_ХарактеристикиНоменклатуры', characteristic),
                'quantity': balance['ВНаличииBalance'], 'reserved': balance['КОтгрузкеBalance'],
                'barcodes': [{'barcode': row['Штрихкод'],
                              'package': ref('Catalog_УпаковкиЕдиницыИзмерения', row['Упаковка_Key'])}
                             for row in barcodes if row['Характеристика_Key'] == characteristic]})
        result.append(dict(product, unit=ref('Catalog_УпаковкиЕдиницыИзмерения', product['ЕдиницаИзмерения_Key']), locations=locations))
    return {'article': article, 'products': result, 'as_of': stamp,
            'read_at': datetime.now(ZoneInfo('Asia/Vladivostok')).isoformat(timespec='seconds'),
            'source': 'AccumulationRegister_ТоварыНаСкладах/Balance', 'origin': 'direct_1c_odata'}

def main():
    try:
        args = json.load(sys.stdin)
        connector = Path(os.environ['AIS_ONE_C_ODATA_CONNECTOR']).resolve()
        sys.path.insert(0, str(connector))
        import odata
        schema = odata.Schema((connector / 'local/metadata.xml').read_bytes())
        result = search(odata, odata.Client(odata.credentials(), schema), schema, args.get('article'))
        print(json.dumps(result, ensure_ascii=False))
        return 0
    except InvalidArticle as error:
        print(json.dumps({'error': str(error)}, ensure_ascii=False)); return 2
    except Exception:
        print(json.dumps({'error': 'Не удалось получить полный ответ 1С. Попробуйте позже.'}, ensure_ascii=False)); return 1
if __name__ == '__main__':
    sys.exit(main())
