#!/usr/bin/python
# Python 2.6 compatible; deployed root-owned on FreePBX. Read-only DB access.
# Restrict an SSH key to this forced command, no shell, PTY or forwarding.
import datetime,json,os,re,subprocess,sys

def mysql(sql):
    source=open('/etc/amportal.conf').read()
    def value(key):return re.search(r'^'+key+r'=(.*)$',source,re.M).group(1).strip()
    env=os.environ.copy();env['MYSQL_PWD']=value('AMPDBPASS')
    process=subprocess.Popen(['mysql','-N','-B','-h',value('AMPDBHOST'),'-u',value('AMPDBUSER'),'asteriskcdrdb','-e',sql],env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    data,error=process.communicate()
    if process.returncode:raise RuntimeError('CDR read failed')
    return data

def main():
    request=json.loads(sys.stdin.readline(1024))
    day=request['day'];offset=request.get('offset',0)
    if not re.match(r'^20[0-9]{2}-[0-9]{2}-[0-9]{2}$',day) or type(offset) is not int or not 0<=offset<=10000000:raise ValueError()
    begin=datetime.datetime.strptime(day,'%Y-%m-%d');end=begin+datetime.timedelta(days=1)
    # HEX prevents mysql batch escaping from corrupting caller names/fields.
    names=['uniqueid','calldate','src','dst','channel','dstchannel','disposition','recordingfile','lastdata']
    fields=','.join('HEX('+name+')' for name in names)+',duration,billsec'
    sql="SELECT %s FROM cdr WHERE calldate >= '%s' AND calldate < '%s' ORDER BY calldate,uniqueid,channel,dstchannel LIMIT 1000 OFFSET %d"%(fields,begin.strftime('%Y-%m-%d %H:%M:%S'),end.strftime('%Y-%m-%d %H:%M:%S'),offset)
    rows=[]
    for line in mysql(sql).splitlines():
        columns=line.split('\t');row={}
        for i,name in enumerate(names):row[name]=columns[i].decode('hex').decode('utf-8','replace')
        row['duration']=int(columns[-2]);row['billsec']=int(columns[-1]);rows.append(row)
    active=subprocess.Popen(['asterisk','-rx','core show channels concise'],stdout=subprocess.PIPE,stderr=subprocess.PIPE).communicate()[0]
    # Unique IDs encode each active channel's creation epoch. Conservatively
    # keep a day open if any channel might still finish a call from that day.
    epochs=[int(x) for x in re.findall(r'(?:^|!)([0-9]{10})\.[0-9]+(?:!|$)',active,re.M)]
    has_active=any(line.count('!') >= 5 for line in active.splitlines())
    oldest=min(epochs) if epochs else (0 if has_active else None)
    print(json.dumps({'rows':rows,'active_oldest_epoch':oldest}))
if __name__=='__main__':
    try:main()
    except Exception:
        sys.stderr.write('CDR export failed\n');sys.exit(1)
