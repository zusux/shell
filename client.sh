#!/bin/sh
#author 周旭鑫
#email: zhxx136@qq.com

getIp(){
    # 得到ip
    #ip=`ip addr show eth0 | awk ' !/127.0.0.1/ && /inet/ { gsub(/\/.*/, "", $2); print ""$2 }'`
    eth=$1
    #判断网卡存在与否,不存在则退出
    if [ ! -d /sys/class/net/$eth ];then
          echo -e "Network-Interface Not Found"
          echo -e "You system have network-interface:\n`ls /sys/class/net`"
          exit 5
    fi
    ip=`ifconfig $eth|grep "inet" |cut -f 2 -d 'n' |cut -f 2 -d ' '`

}
send_main(){
    #mails=("Fdf" "df" "fd")
    for addr in ${mails[@]};do
        /bin/mail -s "warning ! $HOSTNAME server alarm !" $addr < $tmpfile
    done

}

#磁盘监控
diskUse(){
    diskStatus=`df -h | grep "$1"|awk '{print int($5)}'`; #指定过滤的硬盘分区
    if [[ "$disk" > "$diskPercent" ]]; then #指定分区的磁盘使用空间大于85%就报警
        echo "$1 磁盘使用率:$diskStatus%" >> $tmpfile
        echo -e "\033[31m $1 磁盘使用率:$diskStatus%\033[0m"
        wantsend=1
    else
        echo "$1 磁盘使用率:$diskStatus%"
    fi
}

memoryUse(){
    #统计内存使用率
    memStatus=`free -m | awk -F '[ :]+' 'NR==2{printf "%d", ($2-$7)/$2*100}'`
    if [[ "$memStatus" > "$memPercent" ]]; then #指定分区的磁盘使用空间大于85%就报警
        echo "内存使用率:$memStatus%" >> $tmpfile
        echo -e "\033[31m 内存使用率:$memStatus%\033[0m"
        wantsend=1
    else
        echo "内存使用率:$memStatus%"
    fi
}
#cpu 监控
cpuUse(){
   #计算cpu使用率
   cpuStatus=`top -b -n1 | fgrep "Cpu(s)" | tail -1 | awk -F'id,' '{split($1, vs, ","); v=vs[length(vs)]; sub(/\s+/, "", v);sub(/\s+/, "", v); printf "%d", 100-v;}'`
   if [[ "$cpuStatus" > "$cpuPercent" ]]; then #cpu 使用率大于95 报警
        echo "CPU使用率%: $cpuStatus" >> $tmpfile
        echo -e "\033[31m CPU使用率%: $cpuStatus\033[0m"
        wantsend=1
   else
        #/bin/mail -s "$HOSTNAME disk is ok !" $mail_address < $tmpfile
        echo "CPU使用率%: $cpuStatus"
   fi
}
nginxStatus(){
    nginxProcess=`ps axu |grep 'nginx' |grep -v 'grep' |wc -l`
    if [[ "$nginxProcess" > 0 ]]; then #cpu 使用率大于95 报警
        echo "nginx进程数: $nginxProcess"
        serverFlag=1
   else
        #echo "nginx进程数: $process" >> $tmpfile
        echo "nginx进程数: $nginxProcess"
        #echo -e "\033[31m nginx进程数: $process\033[0m"
   fi
}

apacheStatus(){
    apacheProcess=`ps axu |grep 'httpd' |grep -v 'grep' |wc -l`
    if [[ "$apacheProcess" > 0 ]]; then #cpu 使用率大于95 报警
        echo "apache进程数: $apacheProcess"
        serverFlag=2
   else
        #echo "apache进程数: $process" >> $tmpfile
        #echo -e "\033[31m apache进程数: $process\033[0m"
        echo "apache进程数: $apacheProcess"
   fi
}

fpmStatus(){
    fpmProcess=`ps axu |grep 'php-fpm' |grep -v 'grep' |wc -l`
    if [[ "$fpmProcess" > 0 ]]; then #cpu 使用率大于95 报警
        echo "php-fpm进程数: $fpmProcess"
    else
        echo "php-fpm进程数: $fpmProcess" >> $tmpfile
        echo -e "\033[31m php-fpm进程数: $fpmProcess\033[0m"
        wantsend=1
    fi
}
mysqlStatus(){
    mysqlProcess=`ps axu |grep 'mysql' |grep -v 'grep' |wc -l`
    if [[ "$mysqlProcess" > 0 ]]; then #cpu 使用率大于95 报警
        echo "mysql进程数: $mysqlProcess"
    else
        echo "mysql进程数: $mysqlProcess" >> $tmpfile
        echo -e "\033[31m mysql进程数: $mysqlProcess\033[0m"
        wantsend=1
    fi
}
portStatus(){
    num=`netstat -nlt | grep "$1" | wc -l`

    case $1 in
            80)
                port80=$num
            ;;
            3306)
                port3306=$num
            ;;
            9000)
                port9000=$num
            ;;
    esac

    if [[ "$num" > 0 ]]; then #cpu 使用率大于95 报警
        echo "$1端口数量: $num"
    else
        echo "$1端口数量: $num" >> $tmpfile
        echo -e "\033[31m $1端口数量: $num\033[0m"
        wantsend=1
    fi
}
traffic_monitor_once(){
  # 网口名
  eth=$1
  #判断网卡存在与否,不存在则退出
  if [ ! -d /sys/class/net/$eth ];then
      echo -e "Network-Interface Not Found"
      echo -e "You system have network-interface:\n`ls /sys/class/net`"
      exit 5
  fi

  # 状态
    STATUS="fine"
    # 获取当前时刻网口接收与发送的流量
    RXpre=$(cat /proc/net/dev | grep $eth | tr : " " | awk '{print $2}')
    TXpre=$(cat /proc/net/dev | grep $eth | tr : " " | awk '{print $10}')
    # 获取1秒后网口接收与发送的流量
    sleep 1
    RXnext=$(cat /proc/net/dev | grep $eth | tr : " " | awk '{print $2}')
    TXnext=$(cat /proc/net/dev | grep $eth | tr : " " | awk '{print $10}')
    #clear
    # 获取这1秒钟实际的进出流量
    RX=$((${RXnext}-${RXpre}))
    TX=$((${TXnext}-${TXpre}))
    # 判断接收流量如果大于MB数量级则显示MB单位,否则显示KB数量级
    if [[ $RX -lt 1024 ]];then
      RX="${RX}B/s"
    elif [[ $RX -gt 1048576 ]];then
      RX=$(echo $RX | awk '{print $1/1048576 "MB/s"}')
      $STATUS="busy"
      echo -e "Port:$eth\t Status: $STATUS \tRX:$RX\tTX:$TX " >> $tmpfile
      wantsend=1
    else
      RX=$(echo $RX | awk '{print $1/1024 "KB/s"}')
    fi
    # 判断发送流量如果大于MB数量级则显示MB单位,否则显示KB数量级
    if [[ $TX -lt 1024 ]];then
      TX="${TX}B/s"
      elif [[ $TX -gt 1048576 ]];then
      TX=$(echo $TX | awk '{print $1/1048576 "MB/s"}')
    else
      TX=$(echo $TX | awk '{print $1/1024 "KB/s"}')
    fi

    # 打印实时流量
    echo -e "Status: $STATUS \t Port:$eth\t RX:$RX\tTX:$TX "



}



traffic_monitor(){
  # 网口名
  eth=$1
  #判断网卡存在与否,不存在则退出
  if [ ! -d /sys/class/net/$eth ];then
      echo -e "Network-Interface Not Found"
      echo -e "You system have network-interface:\n`ls /sys/class/net`"
      exit 5
  fi
  while [ "1" ]
  do
    # 状态
    STATUS="fine"
    # 获取当前时刻网口接收与发送的流量
    RXpre=$(cat /proc/net/dev | grep $eth | tr : " " | awk '{print $2}')
    TXpre=$(cat /proc/net/dev | grep $eth | tr : " " | awk '{print $10}')
    # 获取1秒后网口接收与发送的流量
    sleep 1
    RXnext=$(cat /proc/net/dev | grep $eth | tr : " " | awk '{print $2}')
    TXnext=$(cat /proc/net/dev | grep $eth | tr : " " | awk '{print $10}')
    clear
    # 获取这1秒钟实际的进出流量
    RX=$((${RXnext}-${RXpre}))
    TX=$((${TXnext}-${TXpre}))
    # 判断接收流量如果大于MB数量级则显示MB单位,否则显示KB数量级
    if [[ $RX -lt 1024 ]];then
      RX="${RX}B/s"
    elif [[ $RX -gt 1048576 ]];then
      RX=$(echo $RX | awk '{print $1/1048576 "MB/s"}')
      $STATUS="busy"
    else
      RX=$(echo $RX | awk '{print $1/1024 "KB/s"}')
    fi
    # 判断发送流量如果大于MB数量级则显示MB单位,否则显示KB数量级
    if [[ $TX -lt 1024 ]];then
      TX="${TX}B/s"
      elif [[ $TX -gt 1048576 ]];then
      TX=$(echo $TX | awk '{print $1/1048576 "MB/s"}')
    else
      TX=$(echo $TX | awk '{print $1/1024 "KB/s"}')
    fi
    # 打印信息
    echo -e "==================================="
    echo -e "System: $OS_NAME"
    echo -e "Date:   `date +%F`"
    echo -e "Time:   `date +%k:%M:%S`"
    echo -e "Port:   $1"
    echo -e "Status: $STATUS"
    echo -e  " \t     RX \tTX"
    echo "------------------------------"
    # 打印实时流量
    echo -e "$eth \t $RX   $TX "
    echo "------------------------------"
    # 退出信息
    echo -e "Press 'Ctrl+C' to exit"
  done
}

urlencode() {
  local length="${#1}"
  for (( i = 0; i < length; i++ )); do
    local c="${1:i:1}"
    case $c in
      [a-zA-Z0-9.~_-]) printf "$c" ;;
    *) printf "$c" | xxd -p -c1 | while read x;do printf "%%%s" "$x";done
  esac
done
}

ip="";
getIp eth0  #你的真实IP地址
HOSTNAME="服务器IP:$ip"
time=`date +%F-%H:%M`;
# 系统版本
OS_NAME=$(lsb_release -a |grep "Distributor ID"|cut -f 2 -d ":")
echo "-------------------------------------------------------------"
echo "时间:$time          IP:$ip         系统:$OS_NAME"
mails=("zhxx136@qq.com" "1018599394@qq.com")
tmpfile=/tmp/check-disk.txt

wantsend=0
serverFlag=0
diskPercent=85
cpuPercent=95
memPercent=95

STATUS="fine"
diskStatus=""
memStatus=""
cpuStatus=""
nginxProcess=""
apacheProcess=""
fpmProcess=""
mysqlProcess=""
port80=""
port3306=""
port9000=""
RX=""
TX=""
eth=""

touch /tmp/check-disk.txt
echo "服务器IP :$ip" > $tmpfile #这里用“>”的意思是覆盖，保证每次发邮件的内容都是新的。
echo "日期:$time" >> $tmpfile


#磁盘监控
diskUse /dev/vda1
diskUse /dev/vdb1
diskUse /dev/vdc1

cpuUse
memoryUse

nginxStatus
apacheStatus
portStatus 80

mysqlStatus
portStatus 3306




if [[ "$serverFlag" -eq 0 ]]; then
    echo "服务器未开启" >> $tmpfile
    echo -e "\033[31m 服务器未开启\033[0m"
    wantsend=1
elif [[ "$serverFlag" -eq 1 ]];then
    echo "nginx服务"
    fpmStatus
    portStatus 9000
else
    echo "apache服务"
fi


traffic_monitor_once eth0

#邮件发送
if [[ "$wantsend" -eq 1 ]]; then
    send_main
    echo -e "\033[31m 正在发送邮件\033[0m"
else
    echo "未发送邮件"
fi

#记录数据
STATUS=$(urlencode $STATUS)
diskStatus=$(urlencode $diskStatus)
memStatus=$(urlencode $memStatus)
cpuStatus=$(urlencode $cpuStatus)
nginxProcess=$(urlencode $nginxProcess)
apacheProcess=$(urlencode $apacheProcess)
fpmProcess=$(urlencode $fpmProcess)
mysqlProcess=$(urlencode $mysqlProcess)
port80=$(urlencode $port80)
port3306=$(urlencode $port3306)
port9000=$(urlencode $port9000)
RX=$(urlencode $RX)
TX=$(urlencode $TX)
eth=$(urlencode $eth)
ip=$(urlencode $ip)
OS_NAME=$(urlencode $OS_NAME)
time=$(urlencode $time)
#wantsend=$(urlencode $wantsend)
param="ip=${ip}&os=${OS_NAME}&time=${time}&wantsend=${wantsend}&diskStatus=${diskStatus}&status=${STATUS}&memStatus=${memStatus}&cpuStatus=${cpuStatus}&nginxProcess=${nginxProcess}&apacheProcess=${apacheProcess}&fpmProcess=${fpmProcess}&mysqlProcess=${mysqlProcess}&port80=${port80}&port3306=${port3306}&port9000=${port9000}&RX=${RX}&TX=${TX}&eth=${eth}"


#推送地址
url="http://www.xxx.com"
curl   -X POST -H "'Content-type':'application/json'" -H "CSRF:record" -d "$param"  $url



echo -e "\n-------------------------------------------------------------"


