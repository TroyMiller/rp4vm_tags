## Script to setup RP4VM replication based on VM tags

$vcenter = '172.20.204.10'
$rp4vm_cluster = '172.20.204.20'
$tag = 'RP4VM'
$user = 'rp4vm@vsphere.local'
$pass = 'CapData1!'


Connect-VIServer $vcenter -User $user -Password $pass

#Get a List of VMs to be replicated
$vm_list = Get-VM -Tag $tag
write-host $vm_list

#Build Rest Authentication
$pair = "$($user):$($pass)"
$encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
$basicAuthValue = "Basic $encodedCreds"
$Headers = @{
    Authorization = $basicAuthValue
}

#Check if VMs are already protected
#Invoke-WebRequest -Uri https://$rp4vm_cluster/api/v1/vms -Headers $Headers -SkipCertificateCheck
$response = Invoke-WebRequest -Uri https://$rp4vm_cluster/api/v1/vms -Headers $Headers -SkipCertificateCheck
$protected_vms = $response | ConvertFrom-Json
$protected_vms_list = $($protected_vms.name)

foreach ($vm in $vm_list) {
    if ($protected_vms_list -notcontains $vm) {
        Write-host "Need to protect $vm"
        $vm_to_protect_response = Invoke-WebRequest -Uri "https://$rp4vm_cluster/api/v1/vms/protect/candidates?vms=&name=$vm" -Headers $Headers -SkipCertificateCheck
        $vm_rp4vm = $vm_to_protect_response | ConvertFrom-Json
        $vm_id = $($vm_rp4vm).id
        $rp_clusterid = $($vm_rp4vm).rpClusterid
        Write-Host $vm, $vm_id, $rp_clusterid
        
        #Build JSON call for defaults on each VM
            $Body = @{
                vm= "$vm_id"
                rpClusterId= "$rp_clusterid"
            }

            $Parameters = @{
                Method = "POST"
                Uri =  "https://$rp4vm_cluster/api/v1/vms/protect/defaults"
                Body = ($Body | ConvertTo-Json -depth 10) 
                ContentType = "application/json"
                Headers = $Headers
            }
        $default_protection = Invoke-RestMethod @Parameters -SkipCertificateCheck
        #$default_protection | convertto-json -depth 10
        Write-Host "Protecting $vm"
            $Parameters2 = @{
                Method = "POST"
                Uri =  "https://$rp4vm_cluster/api/v1/vms/protect"
                Body = ($default_protection | convertto-json -depth 10)
                ContentType = "application/json"
                Headers = $Headers
            }
        Invoke-RestMethod @Parameters2 -SkipCertificateCheck
    } 
}




#Get-VM <vm_name> | %{(Get-View $_.Id).config.uuid}  

Disconnect-VIServer $vcenter