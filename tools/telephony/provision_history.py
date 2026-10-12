#!/usr/bin/python
# Python 2.6. Explicit activation, preserve all existing AMI users/SSH keys.
import datetime,json,os,shutil,subprocess,sys
ROOT='/root/ais-call-history'
def main():
    assert sys.argv[1:]==['--activate']
    config=json.load(open(ROOT+'/private.json'))
    target='/etc/asterisk/manager_custom.conf';text=open(target).read()
    assert '[ais-call-history]' not in text,'Already configured; inspect first'
    assert len(config['ami_secret'])>=40 and config['ami_secret'].isalnum()
    for name in ('cdr_public_key','ami_public_key'):
        assert config[name].startswith('ssh-rsa ') and '\n' not in config[name]
    backup=ROOT+'/backup-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S');os.mkdir(backup,0o700)
    shutil.copy2(target,backup+'/manager_custom.conf')
    text+='\n[ais-call-history]\nsecret='+config['ami_secret']+'\ndeny=0.0.0.0/0.0.0.0\npermit=127.0.0.1/255.255.255.255\nread=call,system\nwrite=reporting\nwritetimeout=5000\n'
    handle=open(target,'w');handle.write(text);handle.close()
    directory='/etc/ais-call-history';os.mkdir(directory,0o700)
    handle=open(directory+'/ami.json','w');json.dump({'username':'ais-call-history','secret':config['ami_secret']},handle);handle.close();os.chmod(directory+'/ami.json',0o600)
    if not os.path.exists('/root/.ssh'):os.mkdir('/root/.ssh',0o700)
    keys='/root/.ssh/authorized_keys';existing=open(keys).read() if os.path.exists(keys) else ''
    if os.path.exists(keys):shutil.copy2(keys,backup+'/authorized_keys')
    for name,script in (('cdr_public_key','pbx_export.py'),('ami_public_key','ami_stream.py')):
        line='from="192.168.1.109",command="/usr/bin/python '+ROOT+'/'+script+'",no-port-forwarding,no-agent-forwarding,no-X11-forwarding,no-pty '+config[name]
        existing+='\n'+line+'\n'
    handle=open(keys,'w');handle.write(existing);handle.close();os.chmod(keys,0o600)
    subprocess.check_call(['asterisk','-rx','manager reload'])
    print('Read-only history access configured; backup '+backup)
if __name__=='__main__':main()
