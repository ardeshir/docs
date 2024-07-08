## Adding IPs to AWS SG

To create a bash script that reads IP addresses from a JSON file and whitelists them as inbound IPs for an AWS Security Group, you can use the AWS CLI along with jq to parse the JSON. Below is a step-by-step guide:
- Install Dependencies: Ensure you have jq and AWS CLI installed on your system.
- jq is a lightweight and flexible command-line JSON processor.
- AWS CLI is the unified tool to manage your AWS services.

```
sudo apt-get install jq -y  # For Debian-based systems  
sudo yum install jq -y      # For RHEL-based systems  


# Install AWS CLI if not installed  
sudo apt-get install awscli -y  # For Debian-based systems  
sudo yum install awscli -y      # For RHEL-based systems  
```
 
2. Create the JSON File: Save the JSON content in a file called input.json.

```bash
cat <<EOF > input.json  
{  
    "name": "PowerBI",  
    "id": "PowerBI",  
    "properties": {  
        "changeNumber": 69,  
        "region": "",  
        "regionId": 0,  
        "platform": "Azure",  
        "systemService": "PowerBI",  
        "addressPrefixes": [  
            "4.145.79.96/28",  
            "4.150.35.64/27",  
            "4.150.35.96/28",  
            "4.150.35.112/29",  
            "4.171.26.72/29",  
            "4.190.132.0/28",  
            "2603:1050:6::/122",  
            "2603:1050:6::40/123",  
            "2603:1050:6:1::5e0/123",  
            "2603:1050:6:1::600/122",  
            "2603:1050:301:2::380/122",  
            "2603:1050:301:2::3c0/123",  
            "2603:1050:403::5e0/123",  
            "2603:1050:403::600/122"  
        ],  
        "networkFeatures": [  
            "API",  
            "NSG",  
            "UDR",  
            "FW"  
        ]  
    }  
}  
EOF  
``` 
3. Create the Bash Script: Write the bash script to read the JSON file, extract IP addresses, and whitelist them.

```bash 
#!/bin/bash  

# Variables  
JSON_FILE="input.json"  
SECURITY_GROUP_ID="sg-01456d8ff9db94b6c"  

# Read and whitelist IP addresses  
jq -r '.properties.addressPrefixes[]' "$JSON_FILE" | while read -r ip; do  
    echo "Whitelisting IP: $ip"  
    aws ec2 authorize-security-group-ingress --group-id "$SECURITY_GROUP_ID" --protocol all --cidr "$ip"  
done  

echo "All IP addresses have been whitelisted."  
``` 

4. Make the Script Executable: Give execute permissions to the script.


- chmod +x whitelist_ips.sh  
 
5. Run the Script: Execute the script to add the IP addresses to your AWS Security Group.


- ./whitelist_ips.sh  
 

### Explanation:

Dependencies: jq is used to parse the JSON file. AWS CLI is used to interact with AWS services.
JSON File: The JSON content is saved in input.json.
Bash Script:
 - The script reads IP addresses from `
