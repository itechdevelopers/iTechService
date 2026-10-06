"""Fixed read-only barcode operation using the installed, inspected OData client."""
import json
import os
from pathlib import Path
import sys
from datetime import datetime
from decimal import Decimal, InvalidOperation
from zoneinfo import ZoneInfo

ZERO = '00000000-0000-0000-0000-000000000000'
COST = 'AccumulationRegister_СебестоимостьТоваров'
LIMITATIONS = ['Балансовая стоимость остатка, не закупочная или розничная цена.',
               'Стоимость может измениться после расчёта себестоимости и закрытия периода; закрытие периода не подтверждено.',
               'Остаток регистра себестоимости может отличаться от физического остатка склада.',
               'СтоимостьBalance используется без добавления отдельных ресурсов ДопРасходы, как в ранее проверенной оценке запасов.']

class ProductCost:
    def __init__(self, api, client, schema):
        self.api, self.client, self.schema = api, client, schema

    def rows(self, entity, fields, condition, maximum=100, parameters=None):
        route = entity
        if parameters is not None:
            route, types, _ = self.schema.function(entity, 'Balance', parameters)
            self.client._approved_routes[route] = types
        payload = json.loads(self.client.request(route, {
            '$select': ','.join(fields), '$filter': condition, '$top': maximum, '$format': 'json'
        }), parse_float=Decimal)
        body = payload.get('d', payload)
        rows = body.get('results', body.get('value'))
        if not isinstance(rows, list) or any(not isinstance(row, dict) for row in rows):
            raise self.api.SafeError('Некорректный ответ 1С.')
        if len(rows) >= maximum or any(body.get(k) for k in ('__next', 'odata.nextLink', '@odata.nextLink')):
            raise self.api.SafeError('Результат превышает безопасный лимит; уточните товар, организацию или склад.')
        return rows

    def ref(self, entity, ref, extra=()):
        if not ref or ref == ZERO:
            return None
        rows = self.rows(entity, ['Ref_Key', 'Description', *extra], 'Ref_Key eq ' + self.api.guid(ref), 2)
        if len(rows) != 1:
            raise self.api.SafeError('Связанная запись 1С недоступна.')
        return rows[0]

    def run(self, args):
        barcode = args.get('barcode')
        if not isinstance(barcode, str) or not barcode or len(barcode) > 128 or any(ord(c) < 32 for c in barcode):
            raise ValueError('barcode должен быть непустой строкой до 128 символов; ведущие нули сохраняются.')
        stamp = args.get('as_of') or datetime.now(ZoneInfo('Asia/Vladivostok')).replace(tzinfo=None).isoformat(timespec='seconds')
        stamp = self.api.moment(stamp)
        if datetime.fromisoformat(stamp) > datetime.now(ZoneInfo('Asia/Vladivostok')).replace(tzinfo=None):
            raise ValueError('Будущая дата не разрешена.')
        for key in ('product_id', 'characteristic_id', 'package_id', 'organization_id', 'warehouse_id'):
            if args.get(key):
                self.api.guid(args[key])
        matches = self.rows('InformationRegister_ШтрихкодыНоменклатуры',
                            ['Штрихкод', 'Номенклатура_Key', 'Характеристика_Key', 'Упаковка_Key'],
                            'Штрихкод eq ' + self.api.literal(barcode), 21)
        variants = []
        for row in matches:
            item = self.ref('Catalog_Номенклатура', row['Номенклатура_Key'], ['ЕдиницаИзмерения_Key'])
            characteristic = self.ref('Catalog_ХарактеристикиНоменклатуры', row['Характеристика_Key'])
            package = self.ref('Catalog_УпаковкиЕдиницыИзмерения', row['Упаковка_Key'], ['Числитель', 'Знаменатель'])
            variants.append({'product_id': item['Ref_Key'], 'name': item['Description'],
                             'characteristic_id': row['Характеристика_Key'], 'characteristic': characteristic,
                             'package_id': row['Упаковка_Key'], 'package': package, 'base_unit_id': item['ЕдиницаИзмерения_Key']})
        result = {'barcode': barcode, 'as_of': stamp, 'timezone': 'Asia/Vladivostok',
                  'read_at': datetime.now(ZoneInfo('Asia/Vladivostok')).isoformat(timespec='seconds'),
                  'source': COST + '/Balance', 'data_origin': 'direct_1c_odata', 'currency': 'RUB',
                  'definition': 'СтоимостьBalance / КоличествоBalance в каждой полной группе учёта; за упаковку умножается на Числитель / Знаменатель.',
                  'limitations': LIMITATIONS}
        if not variants:
            return dict(result, status='not_found', message='Товар с таким штрихкодом не найден.')
        selected = [v for v in variants if all(not args.get(k) or args[k] == v[k] for k in ('product_id', 'characteristic_id', 'package_id'))]
        if len(selected) != 1:
            return dict(result, status='selection_required', variants=variants, message='Выберите товар, характеристику и упаковку по ID из вариантов.')
        product = selected[0]
        base_unit = self.ref('Catalog_УпаковкиЕдиницыИзмерения', product['base_unit_id'])
        package = product['package']
        if not base_unit:
            return dict(result, status='unit_unavailable', product=product, message='Единица товара не установлена; стоимость не вычислена.')
        factor = Decimal(1)
        if package:
            try:
                numerator, denominator = Decimal(str(package['Числитель'])), Decimal(str(package['Знаменатель']))
                if not numerator.is_finite() or not denominator.is_finite() or numerator <= 0 or denominator <= 0:
                    raise ValueError()
                factor = numerator / denominator
            except (InvalidOperation, ValueError, ZeroDivisionError):
                return dict(result, status='unit_unavailable', product=product, message='Коэффициент упаковки не установлен; стоимость не вычислена.')
        condition = 'Номенклатура_Key eq ' + self.api.guid(product['product_id']) + ' and Характеристика_Key eq ' + self.api.guid(product['characteristic_id'])
        if args.get('warehouse_id'):
            condition += " and МестоХранения eq cast(" + self.api.guid(args['warehouse_id']) + ", 'Catalog_Склады')"
        analytics = self.rows('Catalog_КлючиАналитикиУчетаНоменклатуры',
                              ['Ref_Key', 'МестоХранения', 'МестоХранения_Type', 'Серия_Key', 'Назначение_Key'], condition, 21)
        breakdown = []
        for analytic in analytics:
            filt = 'АналитикаУчетаНоменклатуры_Key eq ' + self.api.guid(analytic['Ref_Key'])
            if args.get('organization_id'):
                filt += ' and Организация_Key eq ' + self.api.guid(args['organization_id'])
            # Omit Dimensions: 1C returns the full native accounting groups.
            # A long Dimensions argument exceeds this publication's URL segment limit.
            parameters = {'Condition': filt, 'Period': stamp}
            # Select all grouping dimensions and both resources in one bounded read.
            fields = ['Организация_Key', 'Партия', 'Партия_Type', 'РазделУчета', 'ВидЗапасов_Key',
                      'АналитикаУчетаПартий_Key', 'АналитикаФинансовогоУчета', 'АналитикаФинансовогоУчета_Type',
                      'ВидДеятельностиНДС', 'КоличествоBalance', 'СтоимостьBalance']
            rows = self.rows(COST, fields, 'КоличествоBalance ne 0 or СтоимостьBalance ne 0', parameters=parameters)
            for row in rows:
                if args.get('party_id') and row['Партия'] != args['party_id']:
                    continue
                quantity, amount = row.get('КоличествоBalance'), row.get('СтоимостьBalance')
                cost = None
                if quantity is not None and amount is not None:
                    quantity, amount = Decimal(str(quantity)), Decimal(str(amount))
                    if quantity.is_finite() and amount.is_finite() and quantity > 0 and amount >= 0:
                        cost = str(amount / quantity * factor)
                breakdown.append({'organization_id': row['Организация_Key'], 'storage_id': analytic['МестоХранения'],
                                  'storage_type': analytic['МестоХранения_Type'], 'series_id': analytic['Серия_Key'],
                                  'purpose_id': analytic['Назначение_Key'], 'analytics_id': analytic['Ref_Key'],
                                  'accounting_dimensions': row, 'cost_per_unit': cost,
                                  'status': 'ok' if cost is not None else 'cost_unavailable'})
        result['read_at'] = datetime.now(ZoneInfo('Asia/Vladivostok')).isoformat(timespec='seconds')
        return dict(result, status='ok' if any(r['cost_per_unit'] is not None for r in breakdown) else 'cost_unavailable',
                    product=product, unit=package or base_unit, base_unit=base_unit, package_factor=str(factor),
                    breakdown=breakdown, message='Стоимость дана отдельно по группам учёта.' if breakdown else 'В регистре нет стоимости для выбранного товара и параметров.')


def main():
    try:
        args = json.load(sys.stdin)
        connector = Path(os.environ['AIS_MCP_ODATA_CONNECTOR']).resolve()
        sys.path.insert(0, str(connector))
        import odata
        schema = odata.Schema((connector / 'local/metadata.xml').read_bytes())
        odata.SAFE_FUNCTIONS.add((COST, 'Balance'))
        client = odata.Client(odata.credentials(), schema)
        print(json.dumps(ProductCost(odata, client, schema).run(args), ensure_ascii=False, default=str))
    except ValueError as error:
        print(json.dumps({'error': str(error), 'status': 'invalid_arguments'}, ensure_ascii=False))
        return 2
    except Exception:
        # Do not emit credentials, response bodies, internal paths or connection URLs.
        print(json.dumps({'error': 'Чтение 1С недоступно или результат неполный; стоимость не определена.', 'status': 'upstream_error'}, ensure_ascii=False))
        return 1
    return 0

if __name__ == '__main__':
    sys.exit(main())
