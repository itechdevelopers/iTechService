#!/usr/bin/env python3
"""Deliver aggregate snapshots to AIS; never sends a write request to 1C."""
import argparse
import hashlib
import json
from pathlib import Path
import ssl
import sys
import urllib.parse
import urllib.request

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        raise ValueError('redirect_refused')

def deliver(path, connector, expected_sha256):
    raw = Path(path).read_bytes()
    identity = hashlib.sha256(raw).hexdigest()
    if identity != expected_sha256:
        raise ValueError('snapshot_checksum_mismatch')
    report = json.loads(raw)
    if report.get('schema_version') != 'activity-counts-1.0' or report.get('metric') != 'receipts' or report.get('checks', {}).get('all_pages_received') is not True:
        raise ValueError('invalid_report')
    sys.path.insert(0, str(Path(connector).resolve()))
    from deliver_to_ice import secure_env
    values=secure_env()
    base=values.get('ICE_BASE_URL','https://ise.itech.pw')
    parsed=urllib.parse.urlsplit(base)
    if parsed.scheme!='https' or parsed.hostname!='ise.itech.pw' or parsed.path not in ('','/') or parsed.username or parsed.query or parsed.fragment:
        raise ValueError('invalid_destination')
    token=values.get('ICE_WEEKLY_MARKUP_TOKEN')
    if not token:raise ValueError('missing_import_token')
    # Hash exact UTF-8 bytes on both sides; JSON key order/escaping is not reconstructed.
    body=json.dumps({'delivery_id':identity,'report_json':raw.decode('utf-8')},ensure_ascii=False).encode()
    context=ssl.create_default_context(cafile='/etc/ssl/cert.pem')
    opener=urllib.request.build_opener(NoRedirect(),urllib.request.HTTPSHandler(context=context))
    req=urllib.request.Request(base.rstrip('/')+'/api/activity_count_imports',data=body,
        headers={'Authorization':'Bearer '+token,'Content-Type':'application/json'},method='POST')
    with opener.open(req,timeout=60) as response:
        result=json.load(response)
        if response.status not in (200,201) or result.get('ok') is not True or result.get('delivery_id') != identity or result.get('status') not in ('created', 'duplicate'):raise ValueError('delivery_rejected')
    return {'delivery_id':identity,'status':result.get('status'),'import_id':result.get('id')}

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--connector',required=True,type=Path)
    parser.add_argument('--sha256', required=True, help='Expected checksum from the saved snapshot state')
    parser.add_argument('report',type=Path)
    args=parser.parse_args()
    try:print(json.dumps(deliver(args.report,args.connector,args.sha256)))
    except Exception as exc:
        print('Delivery failed: '+type(exc).__name__,file=sys.stderr)
        raise SystemExit(1)
