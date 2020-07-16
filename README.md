![Image](https://skdevops.files.wordpress.com/2020/07/prbwap-image1.png)
## Motivation
A couple of weeks or so back, I had an interesting work land into my sprint that had to do with protecting the master branch in a number of repositories in Azure Repos. The request was to review a number of build definitions in a certain folder and then identify the associated Azure repositories tied to the build definition. Once identified, review the branch protection policies associated with each repository and make appropriate changes.
<br />This involved - for each repository:
-	Enable a certain set of policies as stated below:
    -	Require a minimum number of reviewers
    -   Check for linked work items
    -	Check for comment resolution
    -	Check for build validation


 If you are interested in knowing more about it please visit my article on that [here](http://skundunotes.com/2020/07/16/protect-master-in-azure-repos-using-policies).

## Prerequisites
Install Azure CLI on the computer where this script will be run from [here](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)

## Algorithm
Step 1: create a list of all build definitions (these were inside a folder so the list of build definitions was curated)
<br />Step 2: for each build definition in the list, gather information about the repository that is tied to it
<br />Step 3: Here, I had a choice. For each repository

-   (a) either delete all existing policies and apply new ones. This was a lot easier since it would ensure that no checks (if policies exist) were need. 
-   (b) or check if a certain policy existed and apply only if it did not and move to the next policy until all the policies were applied.

<br />Both approaches have benefits and drawbacks: (i) delete all and recreate does not consider special conditions unless explicitly stated and (ii) creating only missing policies would allow for existing deviations to persist (for already created policies)

Which option to take is determined by the value of the mandatory variable $(AzureRepoPolicyApplication) which can be either "ResetRepositoryPolicy" or "AppendRepositoryPolicy".

If AzureRepoPolicyApplication = ResetRepositoryPolicy
<br />existing policies were deleted

If AzureRepoPolicyApplication = AppendRepositoryPolicy
<br />existing policies were reviewed and only those that were missing were applied
## Parameters
AzureRepoPolicyApplication : ResetRepositoryPolicy/AppendRepositoryPolicy
<br />AzureDevopsPAT : AzureDevops team project PAT
<br />$AzureDevopsOrgURL : similar to https://dev.azure.com/MyOrganizationName/
<br />AzureDevopsTeamName : project team name in AzureDevops
<br />BranchName : the name of the branch on which policy to apply. For e.g. master
<br />FolderPath : This is optional and only in case the requirement is to update the repositories tied to a certain list of build definitions that are located inside the root folder -"All build pipelines". If the requirement is to review all build definitions and all repositories tied to them, do not pass this parameter
## Usage
-Open windows powershell as admin before you run the script
<br />-Copy/download powershell file and execute below command
<pre><code>.\ApplyPoliciesToAzureRepos.ps1 -AzureRepoPolicyApplication "ResetRepositoryPolicy" or "AppendRepositoryPolicy"-AzureDevopsPAT "$(AzureDevopsPAT)" -AzureDevopsOrgURL "$(AzureDevopsOrgURL)" -AzureDevopsTeamName "$(YourAzureDevopsTeamName)" -BranchName "$(BranchName)" -FolderPath "$(FolderPath)"</code></pre>

## Contribution/Feedback
Please submit a pull request with as much details as possible
