function New-AzureUserPassword {
    param (
        [Parameter(Mandatory)]
        [int] $PasswordLength,
        [int] $MinSpecialChar = 3
    )
    $Pass = ('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789{]+-[*=@:)}$^%;(_!&amp;#?>/|.'.ToCharArray() | Get-Random -Count $PasswordLength) -join ''
    $PasswordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile
    $PasswordProfile.Password = $Pass
    $PasswordProfile.ForceChangePasswordNextLogin = $true
    return $PasswordProfile
}

Function Invoke-WithRetry {
    param (
        [ValidateNotNull()]
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [Alias('InputObject')]
        [scriptblock] $ScriptBlock,
        [ValidateRange(1, [int]::MaxValue)]
        [int] $MaxAttempts = 5,
        [Alias('Step')]
        [int] $WaitTimeInMilliseconds = 1000,
        [Parameter(Mandatory)]
        [string] $Message
    )
    
    $currentAttempt = 0;
    $MessageFormat = "{0} [{1}] - {2}"
    do {
        $currentAttempt++;
        try {
            $result = Invoke-Command -ScriptBlock $ScriptBlock;
            $Success = $true
            break;
        }
        catch {
            Write-Host $($MessageFormat -f (Get-Date), "FAILURE", $Message+' | ['+$Error[0].Exception.ErrorCode+'] - '+$Error[0].Exception.Message)
            if ($currentAttempt -lt $MaxAttempts) {
                Start-Sleep -Milliseconds $WaitTimeInMilliseconds;
            }
        }
    } while ($currentAttempt -lt $MaxAttempts);
    if ($Success){
        Write-Host $($MessageFormat -f (Get-Date), "SUCCESS", $Message)
        return $result;
    }
}

$UserList = @()
foreach ($i in 1..20) {
    $Password = New-AzureUserPassword -PasswordLength 15
    $Username = "Test User $i"
    $UserCreation = {
        New-AzureADUser -DisplayName $Username -PasswordProfile $Password -UserPrincipalName "testuser$i@karolgkrupagmail.onmicrosoft.com" -AccountEnabled $true -MailNickName "TestUser$i"
    }    
    $UserList += Invoke-WithRetry -ScriptBlock $UserCreation -Message "Creating new User $Username"
}
$GroupCreation = {
    New-AzureADGroup -Description "Test group" -DisplayName "Varonis Assignment Group" -MailEnabled $false -SecurityEnabled $true -MailNickName "Varonis"
}
$Group = Invoke-WithRetry -ScriptBlock $GroupCreation -Message "Creating new Group $($Group.Displayname)"

foreach ($User in $UserList) {
    $GroupAssignement = {
        Add-AzureADGroupMember -ObjectId $Group.ObjectId -RefObjectId $User.ObjectId
    }
    Invoke-WithRetry -ScriptBlock $GroupAssignement -Message "Assigning User $($User.Displayname) to a group $($Group.Displayname)"
}