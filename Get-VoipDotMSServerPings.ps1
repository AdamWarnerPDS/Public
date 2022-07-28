# Usage: Copy and paste the following code into a powershell window
# To run it from a command prompt, save this file with extension ps1. 
# Then run Powershell.exe -file "pathtothisscript.ps1"
Clear-Variable best* -Scope Global #Clear the best* variables in case you run it more than once...
#Get the list of servers into an array
<#
$Servers =      
@(
    "amsterdam.voip.ms",
    "atlanta.voip.ms",
    "atlanta2.voip.ms",
    "chicago.voip.ms",
    "chicago2.voip.ms",
    "chicago3.voip.ms",
    "chicago4.voip.ms",
    "dallas.voip.ms",
    "dallas2.voip.ms",
    "denver.voip.ms",
    "denver2.voip.ms",
    "houston.voip.ms",
    "houston2.voip.ms",
    "london.voip.ms",
    "losangeles.voip.ms",
    "losangeles2.voip.ms",
    "montreal.voip.ms",
    "montreal2.voip.ms",
    "montreal3.voip.ms",
    "montreal4.voip.ms",
    "montreal5.voip.ms",
    "montreal6.voip.ms",
    "montreal7.voip.ms","montreal8.voip.ms","newyork.voip.ms","newyork2.voip.ms","newyork3.voip.ms","newyork4.voip.ms","newyork5.voip.ms",
"newyork6.voip.ms","newyork7.voip.ms","newyork8.voip.ms","paris.voip.ms","sanjose.voip.ms","sanjose2.voip.ms",
"seattle.voip.ms","seattle2.voip.ms","seattle3.voip.ms","tampa.voip.ms","tampa2.voip.ms","toronto.voip.ms",
"toronto2.voip.ms","toronto3.voip.ms","toronto4.voip.ms","toronto5.voip.ms","toronto6.voip.ms","toronto7.voip.ms",
"toronto8.voip.ms","vancouver.voip.ms","vancouver2.voip.ms","washington.voip.ms","washington2.voip.ms")
#>

$Servers = @(
    "chicago.voip.ms",
    "chicago2.voip.ms",
    "chicago3.voip.ms",
    "chicago4.voip.ms",
    "chicago5.voip.ms",
    "chicago6.voip.ms",
    "chicago7.voip.ms",
    "montreal.voip.ms",
    "montreal2.voip.ms",
    "montreal3.voip.ms",
    "montreal4.voip.ms",
    "montreal5.voip.ms",
    "montreal6.voip.ms",
    "montreal7.voip.ms",
    "montreal8.voip.ms",
    "montreal9.voip.ms",
    "montreal10.voip.ms",
    "toronto.voip.ms",
    "toronto2.voip.ms",
    "toronto3.voip.ms",
    "toronto4.voip.ms",
    "toronto5.voip.ms",
    "toronto6.voip.ms",
    "toronto7.voip.ms",
    "toronto8.voip.ms",
    "toronto9.voip.ms",
    "toronto10.voip.ms"
    
)

$k = 0 #Counting variable so we know what server number we are testing
#num of servers to test
$servercount = $servers.length 
#Do the following code for each server in our array
ForEach($server in $servers)
{  
  #Add one to the counting variable....we are on server #1...then server 2, then server 3 etc...
  $k++
  #Update the progress bar                    
  Write-Progress -Activity "Testing Server: ${server}" -status "Testing Server $k out of $servercount" -percentComplete ($k / $servercount*100) 
  #Counting variable for number of times we tried to ping a given server
  $i = 0
  Do{
     #assume a failure
     $pingsuccess = $false 
     $i++ #Add one to the counting variable.....1st try....2nd try....3rd try etc...
     Try{
         #Try to ping
         $currentping = (test-connection $server -count 1 -ErrorAction Stop).responsetime 
         #If success full, set success variable
         $pingsuccess = $true
     }
     #Catch the failure and set the success variable to false
     Catch {
      $pingsuccess = $false 
      }     
  }
  #Try everything between Do and While up to 5 times, or while $pingsuccess is not true
  While($pingsuccess -eq $false -and $i -le 5) 
  #Compare the last ping test with the best known ping test....if there is no known best ping test, assume this one is the best $bestping = $currentping 
  If($pingsuccess -and ($currentping -lt $bestping -or (!($bestping)))){ 
  #If this is the best ping...save it
        $bestserver = $server    #Save the best server
        $bestping = $currentping #Save the best ping results
  }
  write-host "tested: $server at $currentping ms after $i attempts" #write the results of the test for this server
}
Start-Sleep -Seconds 1
write-host " The server with the best ping is: $bestserver at $bestping ms" #write the end result
pause