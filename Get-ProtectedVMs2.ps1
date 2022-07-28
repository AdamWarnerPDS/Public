add-pssnapin veeampssnapin

Connect-VBRServer -Server Localhost -Credential (Get-Credential)

$hostname = $ENV:ComputerName

$jobs = (get-vbrjob)

$vms_in_jobs = new-object System.Collections.ArrayList
$allsessions = get-vbrbackupsession

foreach ($job in $jobs){
    Write-Output $job.name
    $vms_protected_by_job = $null
    $vms_protected_by_job = ($allsessions | Where-Object {($_.jobname -like $job.Name) -and ($_.name -notlike "*Retry*") } | sort-object CreationTimeUTC -Descending)[0] | get-vbrtasksession
    foreach ($vm_protected_by_job in $vms_protected_by_job){
        $vm_in_job = New-Object PSObject
        Add-Member -InputObject $vm_in_job -MemberType NoteProperty -Name Name -Value $vm_protected_by_job.name
        Add-Member -InputObject $vm_in_job -MemberType NoteProperty -Name JobName -value $vm_protected_by_job.jobname
        $vms_in_jobs.add($vm_in_job) | out-null
    }
    
}

$vms_in_jobs | Export-CSV -Path "~\Desktop\ProtectedVMs_$hostname.csv" -NoTypeInformation

<#
$vms_in_jobs_compare1 = $vms_in_jobs.name
$vms_in_jobs_compare2 = $vms_in_jobs_compare1 | select -unique
Compare-Object $vms_in_jobs_compare1 $vms_in_compare2
#>