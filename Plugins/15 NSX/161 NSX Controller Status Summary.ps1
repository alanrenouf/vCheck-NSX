# Start of Settings
# Number of NSX Controllers Desired
$nsxCtrlClusterSize = 3
# End of Settings

# Reset issue tracking variable
$nsxCtrlIssue = $false

# Controller Components
$nsxCtrls = Get-NsxController

# Build the table to hold the data
$NsxCtrlStatusTable = New-Object system.Data.DataTable "NSX Controller Status"

# Create simple check for number of controllers deployed and set issue tracking variable to true
if (($nsxCtrls | Where-Object {$_.status -eq "RUNNING"}).count -ne $nsxCtrlClusterSize)
{
    $nsxCtrlIssue = $true
}

# Define Columns
$cols = @()
$cols += New-Object system.Data.DataColumn Name,([string])
$cols += New-Object system.Data.DataColumn Status,([string])
$cols += New-Object system.Data.DataColumn "Peers Ping",([string])
$cols += New-Object system.Data.DataColumn "Peers Active",([string])

#Add the Columns
foreach ($col in $cols) {$NsxCtrlStatusTable.columns.add($col)}


# Begin checks
foreach ($nsxCtrl in $nsxCtrls)
{
    # Populate a row in the Table
    $row = $NsxCtrlStatusTable.NewRow()

    # Enter data in the row
    $row.Name = $nsxCtrl.name
    $row.Status = $nsxCtrl.status

    # If more than one controller, check peer health
    if ($nsxCtrls.count -gt 1)
    {
        # Check each controllers peer ping status, get unique values, filter for success, you should only have one response
        if (($nsxCtrl.controllerClusterStatus.controllerPeerConnectivity.pingStatus | Select-Object -Unique | where {$_ -eq "SUCCESS"}).count -eq 1)
        {
            # Need to populate the table with SUCCESSFUL Peer Ping Status for this controller
            $row."Peers Ping" = "SUCCESS"
        }

        else
        {
            # Check for "UNKNOWN" vmstatus - likely to be controllers connected to primary manager, this is a secondary
            if ($nsxCtrl.vmStatus -eq "UNKNOWN")
            {
                write-warning "Controller Ping Status Check Omitted - Connected to Secondary Manager?"
                $row."Peers Ping" = "NA - Secondary Manager, Check on Primary"
            }

            else
            {
                # Need to populate the table with FAILED Peer Ping Status for this controller
                $row."Peers Ping" = "FAILURE(s)"
                $nsxCtrlIssue = $true
            }
        }

        # Check each controllers peer activity status, get unique values, filter for success, you should only have one response
        if (($nsxCtrl.controllerClusterStatus.controllerPeerConnectivity.isDestActive | Select-Object -Unique | where {$_ -eq "true"}).count -eq 1)
        {
            # Need to populate the table with SUCCESSFUL Peer Activity Status for this controller
            $row."Peers Active" = "SUCCESS"
        }

        else
        {
            # Check for "UNKNOWN" vmstatus - likely to be controllers connected to primary manager, this is a secondary
            if ($nsxCtrl.vmStatus -eq "UNKNOWN")
            {
                write-warning "Controller Ping Peer Activity Check Omitted - Connected to Secondary Manager?"
                $row."Peers Active" = "NA - Secondary Manager, Check on Primary"
            }

            else
            {
                # Need to populate the table with FAILED Peer Activity Status for this controller
                $row."Peers Active" = "FAILURE(s)"
                $nsxCtrlIssue = $true
            }
        }
    }

    # Add the row to the table
    $NsxCtrlStatusTable.Rows.Add($row)

}

# If any error conditions were present, display the table
if ($nsxCtrlIssue -eq $true)
{
    # Display the Status Table
    $NsxCtrlStatusTable | Select-Object Name,Status,"Peers Ping","Peers Active"
}

# Plugin Outputs
$PluginCategory = "NSX"
$Title = "NSX Controller Status"
$Header = "NSX Controller Status"
$Comments = "The desired cluster size of $($nsxCtrlClusterSize) running contollers hasn't been met or not all Cluster peers are healthy"
$Display = "Table"
$Author = "David Hocking"
$PluginVersion = 0.2