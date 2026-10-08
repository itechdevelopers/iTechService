#!/usr/bin/python
# Existing production parallel pilot only; compare owned values before rollback.
import os,re,subprocess
source=open('/etc/amportal.conf').read()
def value(key):return re.search(r'^'+key+r'=(.*)$',source,re.M).group(1).strip()
env=os.environ.copy();env['MYSQL_PWD']=value('AMPDBPASS')
args=['mysql','-N','-B','-h',value('AMPDBHOST'),'-u',value('AMPDBUSER'),value('AMPDBNAME')]
for number in ('101','102','103'):
    expected='SIP/'+number+'&Local/7771@ais-pilot-browser/n'
    process=subprocess.Popen(args+['-e',"SELECT dial FROM devices WHERE id='%s'"%number],env=env,stdout=subprocess.PIPE)
    output=process.communicate()[0].strip();assert process.returncode==0
    assert output==expected,'Device changed elsewhere; inspect before rollback'
    current=subprocess.Popen(['asterisk','-rx','database get DEVICE '+number+'/dial'],stdout=subprocess.PIPE).communicate()[0].strip()
    assert current=='Value: '+expected,'AstDB changed elsewhere; inspect before rollback'
for number in ('101','102','103'):
    expected='SIP/'+number+'&Local/7771@ais-pilot-browser/n'
    subprocess.check_call(args+['-e',"UPDATE devices SET dial='SIP/%s' WHERE id='%s' AND dial='%s'"%(number,number,expected)],env=env)
    subprocess.check_call(['asterisk','-rx','database put DEVICE '+number+'/dial SIP/'+number])
print('Parallel browser route disabled in both FreePBX DB and AstDB')
