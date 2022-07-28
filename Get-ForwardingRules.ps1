$usersProcessed = 0
$mailboxes = $null
$mailboxes = ( Get-Mailbox ).PrimarySMTPAddress
$mc = 0
$forwardingRules = $null
Foreach ( $m in $mailboxes ) {
    $mc ++
    $rc = 0
    Write-Progress -Id 0 -Activity "Checking users" -Status "Mailbox $m ; Scanned $mc of $($mailboxes.count)"
    $rules = Get-InboxRule -Mailbox $m
    Foreach ( $r in $rules ) {
    $rc ++
    Write-Progress -Id 1 -ParentId 0 "Checking Rules" -Status "Rule $rc of $($rules.count)"
        if ( $r.ForwardTo -ne $null) {
            $forwardingRules = $forwardingRules + $r
            Write-Host "Found forwarding rule with identity $($r.Identity)"
        }
    }
}
$forwardingRules | Select-Object Identity,ForwardTo | FT
