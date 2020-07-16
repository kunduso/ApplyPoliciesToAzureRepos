 param (  
    [Parameter(Mandatory=$true)][ValidateSet('ResetRepositoryPolicy','AppendRepositoryPolicy')][string]$AzureRepoPolicyApplication,
    [Parameter(Mandatory=$true)][string]$AzureDevopsPAT,
    [Parameter(Mandatory=$true)][string]$AzureDevopsOrgURL,
    [Parameter(Mandatory=$true)][string]$AzureDevopsTeamName,
    [Parameter(Mandatory=$true)][string]$BranchName,
    [Parameter()][string]$FolderPath
    )
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }
# https://www.powershellgallery.com/packages/Atlassian.Bitbucket/0.24.0

#Region Setting and Displaying Variables
$Count = 1
Set-Item -Path Env:AZURE_DEVOPS_EXT_PAT -Value $AzureDevopsPAT
"`nFollowing are the parameters that were passed."
"AzureRepoPolicyApplication: "+$AzureRepoPolicyApplication
"AzureDevopsOrgURL: "+$AzureDevopsOrgURL
"AzureDevopsTeamName: "+$AzureDevopsTeamName
if (!([String]::IsNullOrWhiteSpace($FolderPath))){
    "FolderPath: "+$FolderPath
}
"BranchName: "+$BranchName
"Value of PAT: "+ $env:AZURE_DEVOPS_EXT_PAT
#endregion

function New-AzureReposPolicy-ApproverCount ($RepoID, $AzureDevopsOrgURL, $AzureDevopsTeamName, $BranchName)
{
    "`nCreating New-AzureReposPolicy-ApproverCount"
    #https://docs.microsoft.com/en-us/cli/azure/ext/azure-devops/repos/policy/approver-count?view=azure-cli-latest#ext-azure-devops-az-repos-policy-approver-count-create
    cmd /c "az repos policy approver-count create" `
        --allow-downvotes false `
        --blocking true `
        --branch $BranchName `
        --creator-vote-counts true `
        --enabled true `
        --minimum-approver-count 1 `
        --reset-on-source-push false `
        --repository-id "$RepoID" `
        --org "$AzureDevopsOrgURL" `
        -p "$AzureDevopsTeamName"
}
function New-AzureReposPolicy-WorkItemLinking ($RepoID, $AzureDevopsOrgURL, $AzureDevopsTeamName, $BranchName)
{
    "`nCreating New-AzureReposPolicy-WorkItemLinking"
    #https://docs.microsoft.com/en-us/cli/azure/ext/azure-devops/repos/policy/work-item-linking?view=azure-cli-latest#ext-azure-devops-az-repos-policy-work-item-linking-create
    cmd /c "az repos policy work-item-linking create" `
        --blocking true `
        --branch $BranchName `
        --enabled true `
        --repository-id $RepoID `
        --org $AzureDevopsOrgURL `
        -p $AzureDevopsTeamName
}
function New-AzureReposPolicy-CommentRequired ($RepoID, $AzureDevopsOrgURL, $AzureDevopsTeamName, $BranchName)
{
    "`nCreating New-AzureReposPolicy-CommentRequired"
    #https://docs.microsoft.com/en-us/cli/azure/ext/azure-devops/repos/policy/comment-required?view=azure-cli-latest#ext-azure-devops-az-repos-policy-comment-required-create
    cmd /c "az repos policy comment-required create" `
        --blocking true `
        --branch $BranchName `
        --enabled true `
        --repository-id $RepoID `
        --org $AzureDevopsOrgURL `
        -p $AzureDevopsTeamName
}
function New-AzureReposPolicy-BuildValidation ($RepoID, $AzureDevopsOrgURL, $AzureDevopsTeamName, $BranchName, $BuildDefinitionID, $BuildDefinitionName)
{
    # Blank space in BuildDefinitionName causes the az repos policy build create command to fail and hence spaces are removed
    $DisplayName = $BuildDefinitionName.replace(' ','')
    "`nCreating New-AzureReposPolicy-BuildValidation"
    #https://docs.microsoft.com/en-us/cli/azure/ext/azure-devops/repos/policy/build?view=azure-cli-latest#ext-azure-devops-az-repos-policy-build-create
    cmd /c "az repos policy build create" `
        --blocking true `
        --branch $BranchName `
        --build-definition-id $BuildDefinitionID `
        --display-name "$DisplayName" `
        --enabled true `
        --manual-queue-only false `
        --queue-on-source-update-only true `
        --repository-id $RepoID `
        --valid-duration 720 `
        --org $AzureDevopsOrgURL `
        -p $AzureDevopsTeamName
}
function Remove-AzureReposPolicy ($PolicyName, $PolicyID, $AzureDevopsOrgURL, $AzureDevopsTeamName)
{
    "Deleting Policy: "+$PolicyName
    #https://docs.microsoft.com/en-us/cli/azure/ext/azure-devops/repos/policy?view=azure-cli-latest#ext-azure-devops-az-repos-policy-delete
    cmd /c "az repos policy delete" `
        --id $PolicyID `
        --org $AzureDevopsOrgURL `
        -p $AzureDevopsTeamName --yes
}
###################################################
#
# Operation begins here
#
###################################################

$ListofAzurePipelines = cmd /c "az pipelines build definition list --org $AzureDevopsOrgURL -p $AzureDevopsTeamName --out json" | ConvertFrom-Json
if (!([String]::IsNullOrWhiteSpace($FolderPath))){
    "`n$FolderPath has been specified and only those build definitions will be considered for evaluation"
    $RefinedListOfPipelines = $ListofAzurePipelines | Where-Object {$_.path -like "*$FolderPath*"}
} else 
{
    "`nThere is no specific folder in AzureDevops build definitions to iterate through and hence all the pipelines will be evaluated"
    $RefinedListOfPipelines = $ListofAzurePipelines
}
if ($AzureRepoPolicyApplication -eq "ResetRepositoryPolicy")
{
    "`nAzureRepoPolicyApplication is set to ResetRepositoryPolicy and hence existing policies (if any) will be removed and new policies will be applied."
} elseif ($AzureRepoPolicyApplication -eq "AppendRepositoryPolicy") {
    "`nAzureRepoPolicyApplication is set to AppendRepositoryPolicy and hence only if a policy is missing, will it be applied."
}

#Region Iteration
foreach ($AzurePipeline in $RefinedListOfPipelines)
{
    $BuildDefinitionName = $AzurePipeline.name
    $BuildDefinitionID = $AzurePipeline.id
    "`n$Count"+". Build definition under review :"+$BuildDefinitionName
    $Count = $Count + 1
    $SpecificAzurePipeline = cmd /c "az pipelines build definition show --org $AzureDevopsOrgURL -p $AzureDevopsTeamName --id "$AzurePipeline.id" --out json" | ConvertFrom-Json
    "`nAssociated repository url: "+$SpecificAzurePipeline.repository.url
    $RepoID = $SpecificAzurePipeline.repository.id
    $ListOfPoliciesInRepository = cmd /c "az repos policy list --branch $BranchName --repository-id $RepoID --org $AzureDevopsOrgURL -p $AzureDevopsTeamName --out json" | ConvertFrom-Json
    $PoliciesToInstall = @('Minimum number of reviewers','Work item linking','Comment requirements', 'Build')

    #Region ResetRepositoryPolicy
    if ($AzureRepoPolicyApplication -eq "ResetRepositoryPolicy")
    {
        #check if current repository has any existing policy and remove them if true
        if ( $ListOfPoliciesInRepository.count -ne 0)
        {
            "Current repository under evaluation has existing policies and these policies will be deleted."
            foreach ($Policy in $ListOfPoliciesInRepository) {
            $Policy.type.displayname
            }
            "`n"
            foreach ($Policy in $ListOfPoliciesInRepository) {
                $PolicyID = $Policy.id
                $PolicyName = $Policy.type.displayname
                . Remove-AzureReposPolicy ($PolicyName) ($PolicyID) ($AzureDevopsOrgURL) ($AzureDevopsTeamName)
            }
        } else {
           "No policy found in current repository under evaluation."
        }
        # adding policies to the repository under consideration
        "`nAdding policies to repository: "+$SpecificAzurePipeline.repository.url
        . New-AzureReposPolicy-ApproverCount ($RepoID) ($AzureDevopsOrgURL) ($AzureDevopsTeamName) ($BranchName)
        . New-AzureReposPolicy-WorkItemLinking ($RepoID) ($AzureDevopsOrgURL) ($AzureDevopsTeamName) ($BranchName)
        . New-AzureReposPolicy-CommentRequired ($RepoID) ($AzureDevopsOrgURL) ($AzureDevopsTeamName) ($BranchName)
        . New-AzureReposPolicy-BuildValidation ($RepoID) ($AzureDevopsOrgURL) ($AzureDevopsTeamName) ($BranchName) ($BuildDefinitionID) ($BuildDefinitionName)
    }
    #endregion ResetRepositoryPolicy

    #Region AppendRepositoryPolicy
    if ($AzureRepoPolicyApplication -eq "AppendRepositoryPolicy")
    {
        foreach ($Policy in $PoliciesToInstall)
        {
            $NewPolicyFlagApproverCount = "false"
            $NewPolicyFlagWorkItemLinking = "false"
            $NewPolicyFlagCommentRequired = "false"
            $NewPolicyFlagBuildValidation = "false"
            "`nPolicy under review: "+ $Policy
            if ($Policy -eq "Minimum number of reviewers")
            {   
                foreach ($PolicyInRepository in $ListOfPoliciesInRepository)
                {
                    if ($Policy -eq $PolicyInRepository.type.displayname)
                    {
                        #"value of: "+$PolicyInRepository.type.displayname
                        "Found policy: Minimum number of reviewers"
                        $NewPolicyFlagApproverCount = "true"
                    }
                }
            }elseif ($Policy -eq "Work item linking")
            {                
                foreach ($PolicyInRepository in $ListOfPoliciesInRepository)
                {
                    if ($Policy -eq $PolicyInRepository.type.displayname)
                    {
                        #"value of: "+$PolicyInRepository.type.displayname
                        "Found policy: Work item linking"
                        $NewPolicyFlagWorkItemLinking = "true"
                    }
                }
            }elseif ($Policy -eq "Comment requirements")
            {
                foreach ($PolicyInRepository in $ListOfPoliciesInRepository)
                {
                    if ($Policy -eq $PolicyInRepository.type.displayname)
                    {
                        #"value of: "+$PolicyInRepository.type.displayname
                        "Found policy: Comment requirements"
                        $NewPolicyFlagCommentRequired = "true"
                    }
                }
            }elseif ($Policy -eq "Build")
            {
                foreach ($PolicyInRepository in $ListOfPoliciesInRepository)
                {
                    if ($Policy -eq $PolicyInRepository.type.displayname)
                    {
                        #"value of: "+$PolicyInRepository.type.displayname
                        "Found policy: Build"
                        $NewPolicyFlagBuildValidation = "true"
                    }
                }
            }

            if (($Policy -eq "Minimum number of reviewers") -and ($NewPolicyFlagApproverCount -eq "false"))
            {
                . New-AzureReposPolicy-ApproverCount ($RepoID) ($AzureDevopsOrgURL) ($AzureDevopsTeamName) ($BranchName)
            }
            if (($Policy -eq "Work item linking") -and ($NewPolicyFlagWorkItemLinking -eq "false"))
            {
                . New-AzureReposPolicy-WorkItemLinking ($RepoID) ($AzureDevopsOrgURL) ($AzureDevopsTeamName) ($BranchName)
            }
            if (($Policy -eq "Comment requirements") -and ($NewPolicyFlagCommentRequired -eq "false"))
            {
                . New-AzureReposPolicy-CommentRequired ($RepoID) ($AzureDevopsOrgURL) ($AzureDevopsTeamName) ($BranchName)
            }
            if (($Policy -eq "Build") -and ($NewPolicyFlagBuildValidation -eq "false"))
            {
                . New-AzureReposPolicy-BuildValidation ($RepoID) ($AzureDevopsOrgURL) ($AzureDevopsTeamName) ($BranchName) ($BuildDefinitionID) ($BuildDefinitionName)                   
            }
        }
    }
    #endregion AppendRepositoryPolicy
}
#endregion Iteration

#Region Cleanup
try {
    $env:AZURE_DEVOPS_EXT_PAT = 'settingthistosomethingthatisincorrectsothatitcantbeused'
    "Value of PAT: "+ $env:AZURE_DEVOPS_EXT_PAT
    Remove-Item -Path Env:AZURE_DEVOPS_EXT_PAT
}
catch {
    "An error occurred: " +$_
    $_.ScriptStackTrace
    exit 1
}
#endregion