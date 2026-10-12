#!/usr/bin/python
# Python 2.6: forced SSH command, local AMI only, no caller-supplied actions.
import datetime,json,socket,sys,time
CONFIG='/etc/ais-call-history/ami.json'
EVENTS=set(['Newchannel','Newstate','NewCallerid','Dial','Bridge','Hangup','Status','StatusComplete','VarSet','Rename','LocalBridge'])
def emit(event):
    sys.stdout.write(json.dumps(event)+'\n');sys.stdout.flush()
def main():
    config=json.load(open(CONFIG));sock=socket.create_connection(('127.0.0.1',5038),10);sock.settimeout(1)
    def action(values):
        assert all('\r' not in str(v) and '\n' not in str(v) for v in values.values())
        sock.sendall(('\r\n'.join(k+': '+str(v) for k,v in values.items())+'\r\n\r\n').encode())
    action({'Action':'Login','Username':config['username'],'Secret':config['secret'],'Events':'on','ActionID':'ais-login'})
    buffer='';authenticated=False;next_snapshot=0;deadline=0;login_deadline=time.time()+10
    while True:
        if not authenticated and time.time()>login_deadline:raise IOError('AMI login timed out')
        if deadline and time.time()>deadline:raise IOError('AMI snapshot timed out')
        if authenticated and time.time() >= next_snapshot:
            emit({'Event':'SnapshotStart'})
            action({'Action':'Status','ActionID':'ais-snapshot','Variables':'CHANNEL(linkedid)'})
            next_snapshot=time.time()+30;deadline=time.time()+25
        try:chunk=sock.recv(65536)
        except socket.timeout:continue
        if not chunk:raise IOError('AMI disconnected')
        buffer+=chunk
        if len(buffer)>1048576:raise IOError('AMI frame too large')
        while '\r\n\r\n' in buffer:
            frame,buffer=buffer.split('\r\n\r\n',1);event={}
            for line in frame.split('\r\n'):
                if ': ' in line:
                    k,v=line.split(': ',1);event[k]=v.decode('utf-8','replace')
            if event.get('ActionID')=='ais-login' and 'Response' in event:
                if event['Response']!='Success':raise IOError('AMI login failed')
                authenticated=True;emit({'Event':'AMIConnected'})
            if event.get('ActionID')=='ais-snapshot' and event.get('Response')=='Error':raise IOError('AMI snapshot denied')
            if event.get('Event')=='StatusComplete':deadline=0
            if authenticated and event.get('Event') in EVENTS:emit(event)
if __name__=='__main__':
    try:main()
    except Exception:
        sys.stderr.write('AMI read connection ended\n');sys.exit(1)
