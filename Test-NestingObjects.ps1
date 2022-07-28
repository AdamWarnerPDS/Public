$twiceNestObject1 = [PSCustomObject]@{Name5='Value5';Name6='Value6'}
$NestedObject1 = [pscustomobject]@{Name1='Value1';Name2='Value2';MoreNest=$twiceNestObject1}
$NestedObject2 = [pscustomobject]@{Name3='Value3';Name4='Value4'}
$ParentObject  = [pscustomobject]@{NestedObject1=$NestedObject1;NestedObject2=$NestedObject2}
#let's check it
$ParentObject | Get-Member