#!/bin/sh

set -e
cd
export LC_ALL=C

d="drweb.report.$(date +'%Y%m%d%H%M%S').$$"
mkdir -p "$d"
cd "$d"

#ОС
uname -o > OS 2>&1

#архитектуру
uname -m > arch 2>&1

#вывод uname -a
uname -a > uname 2>&1

#список пакетов - (rpm -qa, dpkg -l, pkg (freebsd),)
if type rpm >/dev/null 2>&1; then
  rpm -qa > rpm.txt 2>&1 || :
fi
if type dpkg >/dev/null 2>&1; then
  dpkg -l > dpkg.txt 2>&1 || :
fi
if type pkg >/dev/null 2>&1; then
  pkg info < /dev/null > pkg.txt 2>&1 || :
fi

#список наших пакетов - .../drweb.com/bin/rpm -qa
{ /opt/drweb.com/bin/rpm -qa || /usr/local/libexec/drweb.com/bin/rpm -qa; } \
  > drweb.rpm.txt 2>&1 || :

mkdir -p logs || :
#лог syslog (/var/log/syslog, /var/log/messages)
cp /var/log/syslog logs/ >> logs/copy.txt 2>&1 || :
cp /var/log/messages logs/ >> logs/copy.txt 2>&1 || :

#лог пакетного менеджера (/var/log/apt/, /var/log/yum, etc...)
cp /var/log/apt/history.log /var/log/apt/term.log logs/ >> logs/copy.txt 2>&1 || :
cp /var/log/yum.log logs/ >> logs/copy.txt 2>&1 || :
cp /var/log/apt/dnf*log logs/ >> logs/copy.txt 2>&1 || :
cp /var/log/zypper.log logs/ >> logs/copy.txt 2>&1 || :

#список и md5 файлов в .../drweb.com/ (/opt и /var)
{ find /opt/drweb.com/ /usr/local/libexec/drweb.com/ /var/drweb.com /var/opt/drweb.com -type f -exec md5sum {} \; ; } \
  > md5sums.txt 2>&1 || :

#лог dmesg
dmesg > logs/dmesg 2>&1 || :

#вывод df
df / > df.txt 2>&1
df -a >> df.txt 2>&1

#вывод ip a/ifconfig -a
{ ip a || ifconfig -a; } > ip.ifconfig.txt 2>&1 || :

#вывод ldconfig -p (и аналог для freebsd)
{ ldconfig -p || ldconfig -r; } > ldconfig.txt 2>&1 || :

if type drweb-ctl >/dev/null 2>&1; then
#вывод baseinfo -u
  drweb-ctl baseinfo -l > baseinfo.txt 2>&1 || :
#логи drweb (из ini)
  for c in root linuxspider smbspider nss clamd filecheck netcheck scanengine update esagent httpd snmpd meshd cloudd; do
    f=$(drweb-ctl cfshow --value $c.log);
    if [ -f "$f" ]; then
      cp "$f" logs/ >> logs/copy.txt 2>&1 || :
    fi
  done
#md5 движка
md5sum $(drweb-ctl cfshow --value root.coreenginepath 2>&1) > engine.md5 2>&1 || :
#конфиг drweb.ini, файлы правил или списки из ruleset (@/path/to/file)
  cat /etc/opt/drweb.com/drweb.ini > drweb.ini 2>&1 || :
  drweb-ctl cfshow --uncut | grep -i ruleset > rulesets.txt 2>&1 || :
#hooks
  mkdir -p hooks || :
  drweb-ctl cfshow --uncut | sed -n 's,.*hook\s*=\s*/,/,ip' | xargs -t -r -I {} cp {} hooks/ > hooks/copy.txt 2>&1
fi

#секции [key], [user], и [settings] из drweb32.key если не ec режим
if type drweb-ctl >/dev/null 2>&1 && drweb-ctl license 2>&1 | grep -q 'The license is granted by the protection server'; then
  :
elif [ -r /etc/opt/drweb.com/drweb32.key ]; then
  sed -n '/^\[Key/,/^\s*$/p' /etc/opt/drweb.com/drweb32.key > key.txt 2>&1 || :
  sed -n '/^\[User/,/^\s*$/p' /etc/opt/drweb.com/drweb32.key >> key.txt 2>&1 || :
  sed -n '/^\[Settings/,/^\s*$/p' /etc/opt/drweb.com/drweb32.key >> key.txt 2>&1 || :
fi

#вывод iptables-save
if type iptables-save >/dev/null 2>&1; then
  iptables-save > iptables-save.txt 2>&1 || :
fi

#вывод nft export xml
if type nft >/dev/null 2>&1; then
  nft export xml > nft.txt 2>&1 || :
fi

cd
tar -czf "$d".tgz "$d"
rm -r "$d"
