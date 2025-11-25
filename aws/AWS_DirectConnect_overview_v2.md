# AWS Direct Connect Overview v2 

AWS Direct Connect is a cloud service solution that makes it easy to establish a dedicated network connection from your premises to AWS. Using AWS Direct Connect, you can establish private connectivity between AWS and your data center, office, or colocation environment, which in many cases can reduce your network costs, increase bandwidth throughput, and provide a more consistent network experience than internet-based connections.

### Step 1: Create an AWS Direct Connect Connection
1. Sign in to the AWS Management Console.
2. Navigate to the AWS Direct Connect console at AWS Direct Connect Console.
3. Click on "Create a Connection".
4. Select the location where you want to create the connection. AWS provides various locations (Direct Connect locations) where you can establish your connection.
5. Specify the connection details:
	- Connection Name: Provide a name for your connection.
	- Port Speed: Choose the port speed that matches your requirements (e.g., 1 Gbps, 10 Gbps).
	- Location: Choose the location where you want to create the connection.
6. Request the connection. After you submit the connection request, AWS will review and provision the connection. This can take some time.

### Step 2: Complete the Cross-Connect
1. Receive the Letter of Authorization (LOA) from AWS, which provides details on how to connect to AWS Direct Connect at the selected location.
2. Coordinate with your network provider or data center provider to establish a cross-connect between your network and AWS Direct Connect at the selected location.

### Step 3: Configure the Virtual Interface (VIF)
1. Create a Virtual Interface (VIF) in the AWS Direct Connect console:
	- Go to the "Virtual Interfaces" section and click on "Create Virtual Interface".
	- Choose the type of virtual interface (Private VIF for connecting to VPCs, Public VIF for connecting to AWS public services, or Transit VIF for connecting to a transit gateway).
	- Specify the VIF details:
		- Virtual Interface Name: Name your VIF.
		- Connection: Select the Direct Connect connection you created earlier.
		- VLAN: Specify a VLAN ID (if applicable).
		- BGP ASN: Provide the BGP ASN for your on-premises router.
		- IP Addressing: Provide the IP addresses for the BGP peering.
2. Download the router configuration from the AWS console, which contains the BGP configuration details needed for your on-premises router.
### Step 4: Configure Your On-Premises Router
1. Apply the BGP configuration from the AWS Direct Connect console to your on-premises router to establish BGP peering with AWS.
### Step 5: Configure Routing in Your VPC
1. Update your VPC route tables to route traffic through the Direct Connect virtual interface.
	- Navigate to the VPC console at AWS VPC Console.
	- Select the route table associated with your VPC.
	- Add routes to direct traffic destined for your on-premises network to the Direct Connect gateway or virtual private gateway.

### Step 6: Secure the Connection
1. Configure security groups and network ACLs in your VPC to control traffic between your on-premises network and AWS.
2. Enable AWS Direct Connect Gateway (optional) if you need to connect multiple VPCs across different regions.


### Step 7: Test the Connection

1. Verify BGP Peering:
	- Check the BGP session status on both your on-premises router and the AWS Direct Connect console to ensure that the peering session is established and routes are being advertised correctly.
2. Ping Test:
	- Perform a ping test from your on-premises network to the instances in your AWS VPC to verify network connectivity.
	- Ensure that the latency and packet loss are within acceptable limits.
3. Traceroute Test:
	- Use the traceroute command to trace the path packets take from your on-premises network to your AWS VPC instances.
	- This helps in verifying the routing path and ensuring that traffic is flowing through the Direct Connect link.

### Step 8: Monitor and Maintain the Connection

1. Enable CloudWatch Monitoring:
	- Use Amazon CloudWatch to monitor the performance and health of your Direct Connect connection.
	- Set up alarms and notifications for metrics such as connection state, data transfer, and BGP session state.
2. Regularly Review and Update Configuration:
	- Periodically review your Direct Connect configuration, BGP settings, and routing policies to ensure they meet your ongoing requirements.
	- Update security groups, network ACLs, and route tables as needed to reflect any changes in your network architecture.
3. Plan for Redundancy:
	- Consider setting up a redundant Direct Connect connection to ensure high availability and failover in case of a primary connection failure.
	- Use AWS Direct Connect Resiliency Toolkit to design a resilient network architecture.

### Additional Resources: 

- [AWS Direct Connect Documentation: Comprehensive guide and reference for AWS Direct Connect](https://docs.aws.amazon.com/directconnect/latest/UserGuide/Welcome.html)
- [AWS Direct Connect Resiliency Toolkit: Helps you design a resilient and highly available network architecture](https://docs.aws.amazon.com/directconnect/latest/UserGuide/Welcome.html)
- [AWS Well-Architected Framework: Best practices for designing and operating reliable, secure, efficient, and cost-effective systems in the cloud](https://aws.amazon.com/architecture/well-architected/)
