#!/usr/bin/python
# Python 2.6, run on FreePBX after review. No generated files or groups edited.
import datetime,os,re,shutil,subprocess,sys

def main():
    if sys.argv[1:] != ['--activate']:
        print('Prepared PBX browser group and outgoing routing; use --activate after review');return
    root='/etc/asterisk';sip=root+'/sip_custom.conf';dial=root+'/extensions_custom.conf'
    s=open(sip).read();d=open(dial).read()
    peer=re.search(r'(?ms)^\[ais-pilot-bridge\]\n.*?(?=^\[|\Z)',s)
    assert peer and re.search(r'^context=ais-pilot-blocked$',peer.group(0),re.M),'Unexpected peer context; inspect first'
    assert '[from-ais-browser]' not in d,'Already configured; inspect first'
    backup='/root/ais-telephony-backup-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S');os.mkdir(backup,0o700)
    for name in ('sip_custom.conf','extensions_custom.conf'):
        shutil.copy2(root+'/'+name,backup+'/'+name);os.chmod(backup+'/'+name,0o600)
    new_peer=peer.group(0).replace('context=ais-pilot-blocked','context=from-ais-browser')
    s=s[:peer.start()]+new_peer+s[peer.end():]
    d=re.sub(r'(?ms)^\[ais-pilot-browser\]\n.*?(?=^\[|\Z)','',d)
    path=os.path.join(os.path.dirname(os.path.abspath(__file__)),'pbx-dialplan.conf')
    d+='\n'+open(path).read()
    for path,content in ((sip,s),(dial,d)):
        handle=open(path,'w');handle.write(content);handle.close()
    subprocess.check_call(['asterisk','-rx','sip reload'])
    subprocess.check_call(['asterisk','-rx','dialplan reload'])
    print('PBX browser integration activated; backup:',backup)
if __name__=='__main__':main()
