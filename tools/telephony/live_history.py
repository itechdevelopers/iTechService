#!/usr/bin/env python3
"""Asterisk 11 AMI reducer + durable coalescing outbox. No PII in logs."""
import datetime,fcntl,hashlib,hmac,json,os,re,selectors,sqlite3,subprocess,time,urllib.request
from pathlib import Path
from zoneinfo import ZoneInfo
UID=re.compile(r'^\d{10}\.\d+$')
PHONE=re.compile(r'(?:SIP|PJSIP)/(\d{3,4})-')
def stamp():return datetime.datetime.now(datetime.timezone.utc).isoformat()
def number(channel):
    match=PHONE.match(channel or '')
    return match[1] if match else ''
def direction(caller,called):
    a=bool(re.fullmatch(r'\d{3,4}',caller));b=bool(re.fullmatch(r'\d{3,4}',called))
    return 'internal' if a and b else 'outgoing' if a else 'incoming'
class Reducer:
    def __init__(self,calls=None):
        self.calls=calls or {};self.owner={};self.snapshot=None
        for root,call in self.calls.items():
            for uid in call['channels']:self.owner[uid]=root
    def touch(self,root):self.calls[root]['observed_at']=stamp()
    def ensure(self,e):
        uid=e.get('Uniqueid') or e.get('UniqueID');channel=e.get('Channel','')
        if not uid or not UID.fullmatch(uid):return None
        linked=e.get('Linkedid') or e.get('Variable','').partition('CHANNEL(linkedid)=')[2]
        previous=self.owner.get(uid)
        root=linked if UID.fullmatch(linked or '') else self.owner.get(uid,uid)
        self.owner[uid]=root
        if root not in self.calls:
            self.calls[root]={'channels':{},'aliases':[],'caller_number':e.get('CallerIDNum') or 'Номер скрыт','called_number':(e.get('Exten') or e.get('Extension') or '') if re.fullmatch(r'\+?\d{3,15}',e.get('Exten') or e.get('Extension') or '') else '','started_at':datetime.datetime.fromtimestamp(int(root.split('.')[0]),datetime.timezone.utc).isoformat(),'observed_at':stamp(),'answered_extension':None,'ever_answered':False}
        if previous and previous!=root and previous in self.calls:self.merge(root,previous)
        call=self.calls[root]
        if uid==root and e.get('CallerIDNum'):call['caller_number']=e['CallerIDNum']
        if not call['called_number'] and re.fullmatch(r'\+?\d{3,15}',e.get('Exten') or e.get('Extension') or ''):call['called_number']=e.get('Exten') or e.get('Extension')
        state=e.get('ChannelStateDesc',e.get('State',''))
        leg=call['channels'].setdefault(uid,{'channel':channel,'number':number(channel),'state':'ringing'})
        if state=='Up':
            leg['state']='talking';call['ever_answered']=True
        self.touch(root)
        return root
    def merge(self,parent,child):
        if parent==child:return
        a=self.calls[parent];b=self.calls.pop(child)
        a['aliases']=list(dict.fromkeys(a.get('aliases',[])+[child]+b.get('aliases',[])))[:100]
        a['channels'].update(b['channels']);a['ever_answered']=a['ever_answered'] or b['ever_answered']
        for uid in b['channels']:self.owner[uid]=parent
        self.touch(parent)
    def event(self,e):
        event=e.get('Event')
        if event=='SnapshotStart':self.snapshot=set();return
        if event=='StatusComplete':
            if self.snapshot is not None:
                for root,c in self.calls.items():
                    for uid,leg in c['channels'].items():
                        if uid not in self.snapshot and leg['state']!='ended':leg['state']='ended';c['interrupted']=True;self.touch(root)
            self.snapshot=None;return
        if event=='LocalBridge':
            first=e.get('Channel1','');second=e.get('Channel2','')
            if not first.startswith('Local/') or first.split(';')[0]!=second.split(';')[0]:return
            roots=[]
            for croot,c in self.calls.items():
                if any(v['channel'] in (first,second) for v in c['channels'].values()):roots.append(croot)
            if len(roots)==2:
                parent=min(roots,key=lambda u:tuple(int(n) for n in u.split('.')))
                self.merge(parent,next(x for x in roots if x!=parent))
            return
        if event not in ('Newchannel' ,'Newstate','NewCallerid','Dial','Bridge','Hangup','Status','VarSet','Rename'):return
        if event=='Bridge':
            one=e.get('Uniqueid1') or e.get('UniqueID1');two=e.get('Uniqueid2') or e.get('UniqueID2')
            a=self.owner.get(one);b=self.owner.get(two)
            if a and a==b and e.get('Bridgestate','Link')=='Link':
                c=self.calls[a];c['ever_answered']=True
                target=number(e.get('Channel2',''))
                if target and target!=c['caller_number']:c['answered_extension']=target
                for uid in (one,two):c['channels'][uid]['state']='talking'
                self.touch(a)
            return
        root=self.ensure(e)
        if root is None:return
        uid=e.get('Uniqueid') or e.get('UniqueID');call=self.calls[root]
        if event=='Status' and self.snapshot is not None:self.snapshot.add(uid)
        if event=='Dial' and e.get('SubEvent','Begin')=='Begin':
            dest=e.get('DestUniqueID') or e.get('DestUniqueid')
            if dest and UID.fullmatch(dest):
                destroot=self.ensure({'Uniqueid':dest,'Channel':e.get('Destination','')})
                self.merge(root,destroot)
            dial=e.get('Dialstring','').split('@')[0]
            if dial and re.fullmatch(r'\+?\d{3,15}',dial):call['called_number']=call['called_number'] or dial
        elif event=='Hangup':
            call['channels'][uid]['state']='ended'
        elif event=='Newstate' and call['channels'][uid]['state']=='talking':
            # A channel may be answered by IVR; Dial/Bridge identifies the employee.
            call['ever_answered']=True
        elif event=='NewCallerid' and uid==root and e.get('CallerIDNum'):
            call['caller_number']=e['CallerIDNum']
        elif event=='Rename':
            call['channels'][uid]['channel']=e.get('Newname',call['channels'][uid]['channel'])
    def rows(self):
        rows=[]
        for root,c in self.calls.items():
            # Local channels are routing legs; only emit actual SIP calls.
            if not any(x['channel'].startswith(('SIP/','PJSIP/','DAHDI/','IAX2/')) for x in c['channels'].values()):continue
            active=any(x['state']!='ended' for x in c['channels'].values())
            state=('talking' if c['ever_answered'] else 'ringing') if active else ('interrupted' if c.get('interrupted') else 'ended')
            rows.append({'source':'ami','supersedes':c.get('aliases',[]),'call_unique_id':root,'started_at':c['started_at'],'observed_at':c['observed_at'],'caller_number':c['caller_number'],'called_number':c['called_number'],'answered_extension':c['answered_extension'],'direction':direction(c['caller_number'],c['called_number']),'status':state,'duration':0,'billsec':0,'legs':[{'unique_id':u,'number':v['number'],'state':v['state']} for u,v in c['channels'].items()][:100]})
        return rows
class Outbox:
    def __init__(self,path):
        self.db=sqlite3.connect(path);self.db.execute('PRAGMA journal_mode=WAL')
        self.db.execute('CREATE TABLE IF NOT EXISTS outbox(uid TEXT PRIMARY KEY, body TEXT NOT NULL)')
        self.db.execute('CREATE TABLE IF NOT EXISTS acknowledgements(uid TEXT PRIMARY KEY, body TEXT NOT NULL)')
        self.db.execute('CREATE TABLE IF NOT EXISTS state(id INTEGER PRIMARY KEY, body TEXT NOT NULL)');self.db.commit()
    def restore(self):
        row=self.db.execute('SELECT body FROM state WHERE id=1').fetchone()
        return json.loads(row[0]) if row else {}
    def save(self,reducer):
        with self.db:
            self.db.execute('INSERT OR REPLACE INTO state VALUES(1,?)',(json.dumps(reducer.calls),))
            roots=set(reducer.calls)
            for uid, in self.db.execute('SELECT uid FROM outbox').fetchall():
                if uid not in roots:self.db.execute('DELETE FROM outbox WHERE uid=?',(uid,))
            for call in reducer.rows():
                encoded=json.dumps(call);uid=call['call_unique_id']
                ack=self.db.execute('SELECT body FROM acknowledgements WHERE uid=?',(uid,)).fetchone()
                if not ack or ack[0]!=encoded:self.db.execute('INSERT OR REPLACE INTO outbox VALUES(?,?)',(uid,encoded))
            for uid, in self.db.execute('SELECT uid FROM acknowledgements').fetchall():
                if uid not in roots:self.db.execute('DELETE FROM acknowledgements WHERE uid=?',(uid,))
    def send(self,config,connected):
        batch=self.db.execute('SELECT uid,body FROM outbox LIMIT 100').fetchall()
        bounded=[];size=0
        for item in batch:
            size+=len(item[1].encode())
            if size>200000 and bounded:break
            bounded.append(item)
        batch=bounded
        calls=[json.loads(body) for _,body in batch]
        body=json.dumps({'calls':calls,'health':{'source':'ami','connected':connected,'observed_at':stamp()}}).encode()
        post(config,body)
        with self.db:
            for uid,encoded in batch:
                self.db.execute('INSERT OR REPLACE INTO acknowledgements VALUES(?,?)',(uid,encoded))
                self.db.execute('DELETE FROM outbox WHERE uid=? AND body=?',(uid,encoded))
def post(config,body):
    timestamp=str(int(time.time()));signature=hmac.new(config['ingest_secret'].encode(),timestamp.encode()+b'.'+body,hashlib.sha256).hexdigest()
    req=urllib.request.Request(config['ais_url'],data=body,headers={'Content-Type':'application/json','X-AIS-Timestamp':timestamp,'X-AIS-Signature':signature})
    with urllib.request.urlopen(req,timeout=5) as response:
        result=json.loads(response.read());assert result['accepted']==len(json.loads(body)['calls'])
def main():
    import argparse
    parser=argparse.ArgumentParser();parser.add_argument('--config',required=True);args=parser.parse_args();config=json.loads(Path(args.config).read_text())
    assert len(config['ingest_secret'])>=32 and not config['ingest_secret'].startswith('REPLACE')
    state=Path(config['state_path']);state.parent.mkdir(mode=0o700,parents=True,exist_ok=True)
    os.umask(0o077)
    with state.with_suffix('.lock').open('a') as lock:
        try:fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError:return
        outbox=Outbox(str(state));reducer=Reducer(outbox.restore());process=None;connected=False;last_send=0;last_event=0
        while True:
            try:
                process=subprocess.Popen(config['ami_command'],stdout=subprocess.PIPE,stderr=subprocess.DEVNULL)
                with selectors.DefaultSelector() as selector:
                    selector.register(process.stdout,selectors.EVENT_READ);buffer=b''
                    while process.poll() is None:
                        for key,_ in selector.select(0.2):
                            chunk=os.read(key.fd,65536)
                            if not chunk:raise IOError('AMI stream ended')
                            buffer+=chunk
                            if len(buffer)>1048576:raise IOError('AMI frame exceeded')
                            while b'\n' in buffer:
                                line,buffer=buffer.split(b'\n',1);event=json.loads(line)
                                if event.get('Event')=='AMIConnected':connected=True
                                reducer.event(event);last_event=time.time()
                        now=time.time()
                        if now-last_send>=2 and (now-last_event>=0.3 or now-last_send>=5):
                            outbox.save(reducer)
                            try:outbox.send(config,connected)
                            except Exception:pass # Durable retries; never log PII/secrets.
                            # Completed channel graphs are retained long enough for late events.
                            cutoff=now-3600
                            for root,c in list(reducer.calls.items()):
                                if all(v['state']=='ended' for v in c['channels'].values()) and datetime.datetime.fromisoformat(c['observed_at']).timestamp()<cutoff:
                                    for uid in c['channels']:reducer.owner.pop(uid,None)
                                    del reducer.calls[root]
                            last_send=now
            except (OSError,ValueError):pass
            finally:
                connected=False
                if process:
                    process.terminate()
                    try:process.wait(timeout=5)
                    except subprocess.TimeoutExpired:process.kill();process.wait()
                outbox.save(reducer)
                try:outbox.send(config,False)
                except Exception:pass
            time.sleep(5)
if __name__=='__main__':main()
