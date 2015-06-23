#Prompt for VPC variables
$CidrBlock = Read-Host 'Enter the CIDR Block'
$Subnet = Read-Host 'Enter the subnet'

#Create new VPC
$vpcResult = New-EC2Vpc -CidrBlock '$CidrBlock'
$vpcId = $vpcResult.VpcId
Write-Output “VPC ID : $vpcId”

#Enable DNS Support & Hostnames in VPC
Edit-EC2VpcAttribute -VpcId $vpcId -EnableDnsSupport $true
Edit-EC2VpcAttribute -VpcId $vpcId -EnableDnsHostnames $true

#Create new Internet Gateway
$igwResult = New-EC2InternetGateway
$igwId = $igwResult.InternetGatewayId
Write-Output “Internet Gateway ID: $igwId”

#Attach Internet Gateway to VPC
Add-EC2InternetGateway -InternetGatewayId $igwId -VpcId $vpcId

#Create new Route Table
$rtResult = New-EC2RouteTable -VpcId $vpcId
$rtId = $rtResult.RouteTableId
Write-Output “Route Table ID: $rtId”

#Create new Route
$rResult = New-EC2Route -RouteTableId $rtId -GatewayId $igwId -DestinationCidrBlock ‘0.0.0.0/0′

#Create Subnet & associate route table
$sn1Result = New-EC2Subnet -VpcId $vpcId -CidrBlock  '$Subnet' -AvailabilityZone ‘ap-southeast-2a’
$sn1Id = $sn1Result.SubnetId
Write-Output “Subnet1 ID : $sn1Id”
Register-EC2RouteTable -RouteTableId $rtId -SubnetId $sn1Id

Write-Output “VPC setup complete.”

#Prompt for Security Group variables
$SecurityGroupName = Read-Host 'Enter security group name'

#Create security group, and allow ping and RDP
$GroupID = New-EC2SecurityGroup $SecurityGroupName
Get-EC2SecurityGroup -GroupNames $SecurityGroupName
Grant-EC2SecurityGroupIngress -GroupName $SecurityGroupName -IpPermissions @{IpProtocol = "icmp"; FromPort = -1; ToPort = -1; IpRanges = @("0.0.0.0/0")}
Grant-EC2SecurityGroupIngress -GroupName $SecurityGroupName -IpPermissions @{IpProtocol = "udp"; FromPort = 3389; ToPort = 3389; IpRanges = @("0.0.0.0/0")}
Grant-EC2SecurityGroupIngress -GroupName $SecurityGroupName -IpPermissions @{IpProtocol = "tcp"; FromPort = 3389; ToPort = 3389; IpRanges = @("0.0.0.0/0")}

Write-Output “Security Group setup complete.”

#Prompt for Key Pair variables
$KeyPairName = Read-Host 'Enter keypair name'

#Create a Key Pair, this is used to encrypt the Administrator password.
$KeyPair = New-EC2KeyPair -KeyName $KeyPairName
"$($KeyPairName .KeyMaterial)" | out-file -encoding ascii -filepath $folder\$KeyPairName.pem
"KeyName: $($keypairname.KeyName)" | out-file -encoding ascii -filepath $folder\$KeyPairName.pem -Append
"KeyFingerprint: $($KeyPairName.KeyFingerprint)" | out-file -encoding ascii -filepath $folder\$KeyPairName.pem -Append

Write-Output “Key Pair created”

#Get AMI for Windows 2012 R2 Base
$AMI = Get-EC2ImageByName -Names WINDOWS_2012R2_BASE
$ImageId = $AMI.ImageId

#Creates new m3.medium instance running Windows 2012 R2
$NewInstance = New-EC2Instance -ImageId $imageid -MinCount 1 -MaxCount 1 -InstanceType m3.medium -KeyName $KeyPair -SecurityGroups $SecurityGroupName
$InstanceID = $NewInstance.Instances[0].InstanceId

#Prompt for Name tag of instance
$Name = Read-Host 'Enter instance name'

#Set instance name.
New-EC2Tag -Resource $InstanceID -Tag @{ Key="Name"; Value="$Name" }

#Get Administrator Password
$Password = Get-EC2PasswordData -InstanceId $instance.RunningInstance.instanceid -PemFile C:\Secret\Path\To\Keys\ec2-demo-key.pem -Decrypt

#Output results
Write-Output "Public DNS: $InstanceID.RunningInstance.publicdnsname"
Write-Output "Administrator password: $Password"
