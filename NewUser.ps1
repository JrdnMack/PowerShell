#Copyright by Jordan Mackenzie
#Tuesday Febuary 22, 2022
#Copy Over a AD User & Copy over a O365 User

#Imports and Installs Modules Then Connects you to both Services. 
Install-Module AzureAD
Import-Module AzureAD
Install-Module ExchangeOnlineManagement
Import-Module ExchangeOnlineManagement

Connect-ExchangeOnline
Connect-AzureAD

#Set the Varibles for the User you are Creating. 
$Username = read-host("Enter Username: ")
$FirstName = read-host("Enter the User's First name: ")
$LastName = read-host("Enter the User's last name: ")
$DisplayName = ("$FirstName $Lastname")
$Description = read-host("Enter the User's Job Description: ")
$Department = Read-Host("Enter the Department the User will be working in: ")
$Office = Read-Host("Enter the Terminal Address the User will be working at: ")
$Location = Read-Host("Enter the City the User will be working at: ")
$Province = Read-Host("Enter Province: ") 
$Reportingto = Read-Host("Enter who the Username of the Manager they report to: ")
$CopyUsername = read-host("Enter the Username you wish to copy: ")

#This will set password for you
$ClearPassword = (curl https://www.dinopass.com/password/strong).content
$Password = ConvertTo-SecureString -AsPlainText -Force $ClearPassword
$PasswordProfile=New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile
$PasswordProfile.Password="$ClearPassword"

Function Create-ADUser(){
    #New AD User
    $Properties = ("accountExpires", "CannotChangePassword", "MemberOf", "ScriptPath", "AllowReversiblePasswordEncryption", "DistinguishedName") 
    $userInstance = Get-ADUser "$CopyUsername" -Properties $Properties

    New-ADUser -SamAccountName $Username -Name $DisplayName -DisplayName $DisplayName -Surname $LastName -GivenName $FirstName -Description $Description -EmailAddress "$Username@armour.ca"`
    -AccountPassword ($Password) -ChangePasswordAtLogon $True -HomeDirectory ("\\armour-fp01\users\$Username") -HomeDrive "H:" -Enabled $True -Instance $userInstance -UserPrincipalName "$($Username)@armour.ca"`
    -path ("$($userInstance.DistinguishedName)" -replace "CN=$($userInstance.Name),","") -Office $Office -Department $Department -City $Location -State $Province 

    #Adds User to AD Groups
    foreach ($GroupInstance in ($Userinstance.memberof)){
       add-adGroupMember -identity $GroupInstance -Members $Username
    }
}

Function Create-AzureUser(){
    #New Azure User
    $NewAzureUser = New-AzureADUser -DisplayName $DisplayName -GivenName $FirstName -SurName $LastName -UserPrincipalName "$Username@armour.ca" -UsageLocation CA -MailNickName $Username -PasswordProfile $PasswordProfile -AccountEnabled $true `
    -Department $Department -JobTitle $Description -City $Location -Country "Canada" -CompanyName "Armour Transportation Systems" -State $Province

    #Adds the Manager
    $Manager = Get-AzureADUser -objectID "$ReportingTo@armour.ca"
    $UserOBJ = Get-AzureADUser -ObjectId "$Username@armour.ca"
    Set-AzureADUserManager -ObjectId ($UserOBJ).objectID -RefObjectId ($Manager).ObjectId


    #Adds Licenses to the Users account
    $License = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicense
    $License.SkuId = "6fd2c87f-b296-42f0-b197-1e91e994b900"
    $Licenses = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicenses
    $Licenses.AddLicenses = $License

    Set-AzureADUserLicense -ObjectId $NewAzureUser.ObjectId -AssignedLicenses $Licenses

    #Sets Parameters to Check the List of Groups.
    $User = (Get-AzureADUser -SearchString $Username).ObjectID
    $UserToCopy = (Get-AzureADUser -SearchString $CopyUsername).ObjectID

    $GroupCopyList = Get-AzureADUserMembership -ObjectID $UserToCopy
    $GroupList = Get-AzureADUserMembership -ObjectID $User

    #Adds Users to Groups in O365/Azure. 
    Foreach ($Group in $GroupCopyList){
        if ($Group){
            write-host($Group)
            Add-AzureADGroupMember -ObjectID ($Group.objectid) -RefObjectID "$User"
        } 
    }
    #Checks the New User's List and Copied User's List to see if any were missed.
    start-sleep 60 
    Add-DistributionGroupMember -Identity "ArmourTransportationSystems@armour.ca" -Member "$Username@armour.ca"
    Foreach ($GroupL in $GroupCopyList){
        if ($GroupL.ObjectID -notin $GroupList.ObjectID){ 
            ($GroupL.DisplayName)
            Add-DistributionGroupMember -Identity ($GroupL.Displayname) -Member "$Username@armour.ca"
        }
    }
}


#Set All Variables and then run this

Create-ADUser
Create-AzureUser

write-host "`n" $Username "`n" $ClearPassword "`n" "`n" "$($Username)@armour.ca" "`n" $ClearPassword

