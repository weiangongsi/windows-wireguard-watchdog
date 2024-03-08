# Windows-Wireguard-Watchdog

> 背景：Wireguard服务端是动态IP，Wireguard客户端配置的服务端地址是域名 Endpoint = xx.xxx.com:51820，写的DDNS脚本检测到IP变更会自动更新域名解析。每次宽带重拨IP就会变更，由于客户端重连使用的不是域名而是第一次连接时解析的域名对应的IP地址，导致一直连接不上服务端。

使用此PowerShell脚本，可以让你的Wireguard保持稳定的连接，服务端ip变更客户端仍可自动重新连接。

## 脚本流程

脚本主要执行了一下的步骤:

1. 解析配置文件读取连接服务端的域名。
2. 查询DNS服务器，获取A记录的IP地址。
3. 循环获取查询DNS，如果IP变更，把原配置文件的Endpoint替换成新的IP，生成新的配置文件，然后重新启动Wireguard服务。
4. 如果查询DNS服务器失3次，就停止Wireguard服务（防止因为Wireguard连接不上服务端导致查询DNS失败），然后再次执行第3步。

为什么要用新的IP生成配置文件？

Wireguard不会用我们配置的DNS获取IP，我们通过配置的DNS检测到IP变更，但是Wireguard解析域名可能检测不到变化，试过清除本地DNSClient缓存，不起作用，重启Wireguard服务他还是用原来的IP，导致连接失败。

## 安装步骤

让脚本以Windows服务方式运行 :

1. 修改脚本中的Wireguard 以下几项配置
	```powershell
	# wireguard 配置文件
	$WireguardConfigFilePath = "C:\Users\admin\Desktop\company.conf" 
	# 检查IP变更时间间隔，秒
	$IntervalSeconds = 10
	# DNS服务器地址,不设置会从 wireguard 配置文件中读取DNS参数。我的域名是阿里的，dns9.hichina.com是阿里分配DNS服务器（阿里后台域名解析设置页面能看到这个地址），能立即检测到域名解析的ip变更
	$DNS = "dns9.hichina.com" 
	```
	
2. 用powershell终端管理员执行
	```shell
	.\nssm.exe install MyWireGuardService "powershell.exe" "-ExecutionPolicy Bypass -File C:\Users\admin\Desktop\keep_wireguard_alive.ps1"
	```
	替换 `C:\Users\admin\Desktop\keep_wireguard_alive.ps1` 为你自己的脚本文件路径。
	
3. 启动服务
	```shell
	.\nssm.exe start MyWireGuardService
	```
   现在脚本就作为Windows服务运行了，电脑重启开机Wiregurd会自动连接。你可以打开Wireguard的UI查看日志，任务管理器查看Wireguard的进程。
   
## 关闭脚本服务

停止服务

```shell
.\nssm.exe stop MyWireGuardService
```

移除服务

```shell
.\nssm.exe remove MyWireGuardService
```

## 停止Wireguard服务

```shell
wireguard /uninstalltunnelservice companytemp
```

替换`company`为你的Wireguard 配置文件名（company.conf不包含扩展名），或者任务管理器停止服务

## Wireguard客户端配置例子

```

[Interface]
PrivateKey = WCCQic09ih+u/Xr1v4FXDtXKpzgx9JLr59hRo2hX3E=
Address = 10.0.8.3/24
DNS = 114.114.114.114


[Peer]
PublicKey = H1QI7lFziAopeQfMm61ZMSNvxJeus1KGXZMKw/uoCY=
PresharedKey = l/B0jMWfDqpYD2UrK1H0uNlv4/qpthtPtLvt/QIDU8=
AllowedIPs = 0.0.0.0/0,::/0
PersistentKeepalive = 25
Endpoint = xxx.yyy.com:51820
```

## 创作不易，欢迎打赏

<img src="https://gitee.com/dcssn_weiangongsi/windows-wireguard-watchdog/raw/master/img/wechat-payment-code.jpg" style="width:200px" />
<img src="https://gitee.com/dcssn_weiangongsi/windows-wireguard-watchdog/raw/master/img/ali-payment-code.jpg" style="width:200px" />

1分钱就可以