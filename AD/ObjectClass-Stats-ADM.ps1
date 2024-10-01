# Import the Active Directory module
Import-Module ActiveDirectory

# Get all objects from Active Directory
$allObjects = Get-ADObject -Filter * -Property objectClass

# Group the objects by their class
$groupedByClass = $allObjects | Group-Object -Property objectClass

# Display the classes and the count of objects in each class
$groupedByClass | Select-Object Name, Count
