# wireguard 配置文件
$WireguardConfigFilePath = "C:\Users\admin\Desktop\company.conf" 
# 检查IP变更时间间隔
$IntervalSeconds = 10
# DNS服务器地址,不设置会从 wireguard 配置文件中读取
$DNS = "dns9.hichina.com"

# 通过文件路径获取文件名（不包含扩展名）
function getFilenameByPath {
    param (
        [string]$path
    )
    $tempArr = $path.Split("\")
    return $tempArr[$tempArr.Length - 1].Split(".")[0] + "temp"
}

# 读取配置文件获取服务端连接域名
function getEndpointByFile {
    param (
        [string]$path
    )
    Get-Content -Path $path | ForEach-Object { 
        if ($_ -like "*Endpoint*") {
            return $_.Split('=')[1].Split(':')[0].Trim() 
        }
    }
}

# 读取配置文件获取DNS服务器地址
function getDNSByFile {
    param (
        [string]$path
    )
    if ($DNS) {
        $domainPattern = '^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9][a-z0-9-]{0,61}[a-z0-9]$'
        $ipv4Pattern = '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'
        if ($DNS -match $domainPattern) {
            $DnsIPAddress = getDnsIp -domain $DNS -DnsServer "114.114.114.114"
            if ($DnsIPAddress -ne "failed") {
                return $DnsIPAddress
            }
        }
        elseif ($DNS -match $ipv4Pattern) {
            return $DNS
        }
        return "114.114.114.114"
    }
    Get-Content -Path $path | ForEach-Object { 
        if ($_ -like "*DNS*") {
            return $_.Split('=')[1].Trim()
        }
    }
}

# 获取dns解析的ip
function getDnsIp() {
    param (
        [string]$domain,
        [string]$DnsServer
    )
    # 调用 Resolve-DnsName 命令并指定参数 -Type A（A记录）
    $result = Resolve-DnsName $domain -Server $DnsServer -Type A -DnsOnly -QuickTimeout
    $ip = "failed"
    if ($result) {
        $ip = $result[0].IPAddress
    }
    else {
        $result = Resolve-DnsName $domain -Server "114.114.114.114" -Type A -DnsOnly -QuickTimeout
        if ($result) {
            $ip = $result[0].IPAddress
        }
    }
    return $ip
}

# 初始化隧道，服务方式运行wireguard
function Start-WireguardTunnel {
    param (
        [string]$TunnelName,
        [string]$EndpointIp
    )
    $serviceName = "WireGuard Tunnel: $TunnelName";
    $ExistsService = Get-Service $serviceName;
    if ($ExistsService) {
        Write-Host "stop wireguard"
        Invoke-Expression "wireguard /uninstalltunnelservice $TunnelName"
    }
    Write-Host "start wireguard"
    Start-Sleep -Seconds 3
    # 生成临时配置文件
    $WireguardConfigFilePathTemp = $WireguardConfigFilePath.Substring(0, $WireguardConfigFilePath.Length - $TunnelName.Length - 1) + "\" + "$TunnelName" + ".conf"
    if (-not(Test-Path $WireguardConfigFilePathTemp -PathType Leaf)) {
        New-Item -ItemType File -Path $WireguardConfigFilePathTemp 
        Set-ItemProperty -Path $WireguardConfigFilePathTemp -Name Attributes -Value ([System.IO.FileAttributes]::Hidden)
    }
    $Endpoint = getEndpointByFile -path $WireguardConfigFilePath
    $Content = Get-Content -Path $WireguardConfigFilePath
    $NewContent = $Content.Replace($Endpoint, $EndpointIp)
    Set-Content -Path $WireguardConfigFilePathTemp -Value $NewContent
    Invoke-Expression "wireguard /installtunnelservice $WireguardConfigFilePathTemp"
}

# 停止WireGuard服务
function Stop-WireGuardServic {
    param (
        [string]$TunnelName
    )
    Write-Host "stop wireguard"
    Invoke-Expression "wireguard /uninstalltunnelservice $TunnelName"
}

# 隧道名称
$TunnelName = getFilenameByPath -path $WireguardConfigFilePath
# 服务端连接域名
$Endpoint = getEndpointByFile -path $WireguardConfigFilePath
# DNS服务器地址
$DnsServer = getDNSByFile -path $WireguardConfigFilePath
# wireguard 解析的ip
$EndpointIPAddress = getDnsIp -domain $Endpoint -DnsServer $DnsServer
# dns 解析的ip
$DnsIPAddress = $EndpointIPAddress
# getDnsIp 失败次数
$DnsFailedCount = 0
# 初始化隧道
Start-WireguardTunnel -TunnelName $TunnelName -EndpointIp $DnsIPAddress
# 主程序
while ($true) {
    $DnsIPAddress = getDnsIp -domain $Endpoint -DnsServer $DnsServer
    Write-Host "DnsIPAddress: $DnsIPAddress, EndpointIPAddress: $EndpointIPAddress, DnsServer: $DnsServer"
    if ($DnsIPAddress -eq "failed") {
        $DnsFailedCount = $DnsFailedCount + 1
        if ($DnsFailedCount -eq 3) {
            Stop-WireGuardServic -TunnelName $TunnelName
            $DnsServer = getDNSByFile -path $WireguardConfigFilePath
            $DnsFailedCount = 1
        }
    }
    else {
        $DnsFailedCount = 1
        if ($EndpointIPAddress -ne $DnsIPAddress) {
            Start-WireguardTunnel -TunnelName $TunnelName -EndpointIp $DnsIPAddress
            $EndpointIPAddress = $DnsIPAddress
        }
        else {
            $serviceName = "WireGuard Tunnel: $TunnelName";
            $ExistsService = Get-Service $serviceName;
            if (!$ExistsService) {
                Start-WireguardTunnel -TunnelName $TunnelName -EndpointIp $DnsIPAddress
            }
        }
    }
    Start-Sleep -Seconds $IntervalSeconds
}