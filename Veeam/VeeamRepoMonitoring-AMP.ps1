$repos = get-vbrbackuprepository | where-object {$_.Type -eq "HPStoreOnceIntegration"}

$repo1 = $repos[0].getcontainer()

$repo1n = $repos[0].name
$repo1f = $repo1.CachedFreeSpace.InTerabytes
$repo1t = $repo1.CachedTotalSpace.InTerabytes
$repo1used = $repo1t - $repo1f
$repo1u = ($repo1used/$repo1t) * 100 | % {$_.tostring("#")}

$repo2 = $repos[1].getcontainer()

$repo2n = $repos[1].name
$repo2f = $repo2.CachedFreeSpace.InTerabytes
$repo2t = $repo2.CachedTotalSpace.InTerabytes
$repo2used = $repo2t - $repo2f
$repo2u = ($repo2used/$repo2t) * 100 | % {$_.tostring("#")}

