Import-Module '\\\Powershell\SQL\SQL interface.ps1'


<#
    Receive input from user
    Create new user record in Aeries
    Lookup potential groups to add to user
        Get job title
        Parse keywords
    Prompt group add, if yes:
        Get ID from new user
        Create new association record between user and group
#>


$mailHost = ''
$mailIp = ''
$templatePath = '.\welcome.html'
$dbHost = ''
$db = ''


Echo '=-=-=-=-=-=-=-=-=-=-=-=-=-='
Echo 'Aeries account creation tool'
Echo '=-=-=-=-=-=-=-=-=-=-=-=-=-='
$given = Read-Host -Prompt "`tEnter first name"
$family = Read-Host -Prompt "`tEnter last name"
$adUsr = Read-Host -Prompt "`tEnter username"
$title = Read-Host -Prompt "`tEnter job title"

try {
    $conn = SQL-Connection -Server $dbHost -Database $db
    $email = $adUsr + '@smjuhsd.org'
    $createQuery = "EXEC usp_new_aeries_usr @firstName = '{0}', @lastName = '{1}', @usrEmail = '{2}'" -f ($given, $family, $email)
    Query-SQL -Connection $conn -Query $createQuery
} catch {
    Write-Host 'User not created'
    Echo $Error
}
try {
    $returnQuery = "SELECT [UID] FROM UGN WHERE UN = '{0}'" -f ($email)
    $newId = Query-SQL -Connection $conn -Query $returnQuery
    $newId = $newId.UID
    Echo "User Created: ID=$newId"
} catch {
    Write-Host 'Cannot find user ID'
    Echo $Error
}
try {
    $resp = @()
    $title.split(' ') | ForEach-Object {
        $lookupQuery = "EXEC usp_job_search @Keyword = '{0}'" -f ($_)
        $resp += Query-SQL -Connection $conn -Query $lookupQuery
    }
    If ($resp) {
        Echo 'Groups found:'
        $resp | ForEach-Object {
            Write-Host ("`t{0} - {1}" -f ($_.UID, $_.UN))
        }
    }
} catch {
    Write-Host 'Unable to find groups'
    Echo $Error
}
try {
    $promptAssignment = Read-Host -Prompt 'Enter Group ID for assignment, or "n" to skip'
    If ($promptAssignment -ne 'n') {
        $assignQuery = 'EXEC usp_assign_group @user = {0}, @group = {1}' -f ($newId, $promptAssignment)
        Query-SQL -Connection $conn -Query $assignQuery
        Write-Host 'User added to group'
    }
    Else { Write-Host 'Skipping group assignment' }
} catch {
    Write-Host 'Unable to add to group'
    Echo $Error
}
try {
    $template = Get-Content -Path $templatePath
    $htmlBody = $template -f ($given, $email)
    Send-MailMessage -From 'MC <admin email>' -To "$given $family <$email>" -Cc 'MC <admin email>' -Subject "New Aeries Account for $given $family" -BodyAsHtml $htmlBody -SmtpServer $mailHost
    Write-Host 'Email Sent'
} catch {
    Write-Host 'Error sending email'
    Echo $Error
}
Read-Host 'Press any key to exit...'