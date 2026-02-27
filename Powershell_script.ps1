#this script finds users,ip, and more!!
# COMBINED SCRIPT:
# Enumerate all domain computers + IPs AND all users + their group memberships
# (LDAP only, no PowerView)

# --- Domain / LDAP setup ---
$domainObj = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
$PDC  = $domainObj.PdcRoleOwner.Name
$DN   = ([adsi]'').distinguishedName
$LDAP = "LDAP://$PDC/$DN"

$dirEntry = New-Object System.DirectoryServices.DirectoryEntry($LDAP)

# =========================
# PART 1: DOMAIN COMPUTERS
# =========================
$compSearcher = New-Object System.DirectoryServices.DirectorySearcher($dirEntry)
$compSearcher.PageSize = 1000
$compSearcher.Filter = "(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))"

$null = $compSearcher.PropertiesToLoad.Add("name")
$null = $compSearcher.PropertiesToLoad.Add("dnshostname")

$computerResults = $compSearcher.FindAll()

$Computers = foreach ($r in $computerResults) {
    $name = $r.Properties["name"] | Select-Object -First 1
    $dns  = $r.Properties["dnshostname"] | Select-Object -First 1
    $target = if ($dns) { $dns } else { $name }

    $ips = @()
    try {
        $ips = [System.Net.Dns]::GetHostAddresses($target) |
               Where-Object { $_.AddressFamily -eq 'InterNetwork' } |
               ForEach-Object { $_.IPAddressToString }
    } catch {}

    [pscustomobject]@{
        Type        = "Computer"
        Name        = $name
        DNSHostName = $dns
        IPv4        = ($ips -join ", ")
        Groups      = ""
    }
}

# ======================
# PART 2: DOMAIN USERS
# ======================
$userSearcher = New-Object System.DirectoryServices.DirectorySearcher($dirEntry)
$userSearcher.PageSize = 1000
$userSearcher.Filter = "(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))"

$null = $userSearcher.PropertiesToLoad.Add("samaccountname")
$null = $userSearcher.PropertiesToLoad.Add("memberOf")

$userResults = $userSearcher.FindAll()

$Users = foreach ($r in $userResults) {
    $sam = $r.Properties["samaccountname"] | Select-Object -First 1
    if (-not $sam) { continue }

    $groups = @($r.Properties["memberOf"]) | ForEach-Object {
        if ($_ -match "^CN=([^,]+),") { $Matches[1] } else { $_ }
    } | Sort-Object -Unique

    [pscustomobject]@{
        Type        = "User"
        Name        = $sam
        DNSHostName = ""
        IPv4        = ""
        Groups      = ($groups -join "; ")
    }
}

# ======================
# OUTPUT (COMBINED)
# ======================
$Results = $Computers + $Users
$Results | Sort-Object Type, Name | Format-Table -AutoSize
