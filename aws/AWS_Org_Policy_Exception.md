# AWS Policy Exception 

Creating an exception in a Service Control Policy (SCP) is a sensitive operation done by the AWS Organization's administrators. Your job is to provide them with a "request for change" that is so clear and well-justified that they can implement it quickly and with confidence.

Here are the steps and the information you need to provide them, broken down into the two most common ways SCPs are written.

---

### Understanding the Two Types of SCP Blocks

Your organization is likely using one of two security models. The solution will depend on which model is in use.

1.  **The "Deny List" Model (Blacklist):** This model allows most actions by default but has a specific SCP that explicitly **DENIES** certain high-risk actions. It's likely there's a policy that denies `sts:AssumeRoleWithWebIdentity`.
2.  **The "Allow List" Model (Whitelist):** This is a more restrictive "zero-trust" model. It has an SCP that denies everything by default, and then another SCP that explicitly **ALLOWS** a specific list of approved services and actions. It's likely that `sts:AssumeRoleWithWebIdentity` is simply missing from this list.

You will provide a solution for both scenarios.

---

### Step 1: Gather Your Evidence (The "Request Package")

You have already gathered all of this information. Consolidate it into a clear package for the admin team.

*   **The Goal:** To allow an EKS pod to assume an IAM Role via IRSA.
*   **The Action Being Denied:** `sts:AssumeRoleWithWebIdentity`
*   **The Account ID:** `559984225005`
*   **The EKS OIDC Provider URL:** `https://oidc.eks.us-east-1.amazonaws.com/id/E3CC793F18AD7E929158A92CBFB433EA`
*   **The Specific IAM Role ARN to be Assumed:** `arn:aws:iam::559984225005:role/DairyEksPodRoleForSecrets-dev`
*   **The Proof:** "My team has confirmed with a standard AWS CLI debug pod that this action is being blocked externally, strongly pointing to an SCP."

---

### Step 2: Propose the Solutions to the Admin Team

This is what the AWS Organization administrator needs to do. You are providing them with the "how-to."

#### Solution A: Creating an Exception in a "Deny List" SCP

If their SCP explicitly denies `sts:AssumeRoleWithWebIdentity`, they need to modify that `Deny` statement to add a `Condition` that creates an exception for your specific use case.

**Here's how they would do it:**

1.  **Find the Denying SCP:** In the AWS Management Account, they will navigate to AWS Organizations -> Policies -> Service Control Policies and find the policy that contains the `Deny` statement for `sts:AssumeRoleWithWebIdentity`.

2.  **Edit the Policy:** They will edit the policy JSON.

    **Before (Example of what might exist now):**
    ```json
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Deny",
                "Action": "sts:AssumeRoleWithWebIdentity",
                "Resource": "*"
            }
        ]
    }
    ```

    **After (The proposed change):**
    They will add a `Condition` block to exclude the specific role you need to assume. This says, "Deny this action for everyone, UNLESS the role being assumed is `DairyEksPodRoleForSecrets-dev`."

    ```json
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Deny",
                "Action": "sts:AssumeRoleWithWebIdentity",
                "Resource": "*",
                "Condition": {
                    "ArnNotLike": {
                        "iam:ResourceTag/eks-irsa-allowed": "true" 
                    }
                }
            }
        ]
    }
    ```
    *Note: A more advanced and secure way is to use tags. The admin would add a `Condition` that skips the deny if the role has a specific tag, like `eks-irsa-allowed: true`. You would then add this tag to your `DairyEksPodRoleForSecrets-dev` role using CDKTF.*

#### Solution B: Adding to an "Allow List" SCP

If their SCP defines a limited list of allowed actions, they simply need to add `sts:AssumeRoleWithWebIdentity` to that list.

**Here's how they would do it:**

1.  **Find the "Allow List" SCP:** They will find the policy that contains the `Allow` statement with a long list of actions.

2.  **Edit the Policy:** They will edit the policy JSON.

    **Before (Example of what might exist now):**
    ```json
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "ec2:*",
                    "s3:GetObject",
                    "rds-data:*"
                    // ... many other services, but sts:AssumeRoleWithWebIdentity is missing
                ],
                "Resource": "*"
            }
        ]
    }
    ```

    **After (The proposed change):**
    They add the required STS action to the list of allowed actions.

    ```json
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "ec2:*",
                    "s3:GetObject",
                    "rds-data:*",
                    "sts:AssumeRoleWithWebIdentity" // <-- THE NEWLY ADDED ACTION
                ],
                "Resource": "*"
            }
        ]
    }
    ```

---

### Step 3: Your Final Request Template

You can now send a clear, professional, and fully-formed request.

> **Subject:** Urgent: EKS IRSA Blocked by SCP - Request for Exception
>
> **Body:**
>
> Hello Cloud Platform Team,
>
> Our EKS application deployment in Account `559984225005` is currently blocked. Pods are failing to assume their IAM Role with the error `Not authorized to perform sts:AssumeRoleWithWebIdentity`.
>
> We have completed a full diagnostic, including deploying a standard AWS CLI debug pod, which conclusively proves the action is being denied by a Service Control Policy. All IAM configurations within our account are correct.
>
> **We request that an exception be made in the relevant SCP to allow this action.**
>
> **Technical Details:**
> *   **Action to Allow:** `sts:AssumeRoleWithWebIdentity`
> *   **Account ID:** `559984225005`
> *   **The IAM Role being assumed:** `arn:aws:iam::559984225005:role/DairyEksPodRoleForSecrets-dev`
> *   **The trusted EKS OIDC Provider:** `https://oidc.eks.us-east-1.amazonaws.com/id/E3CC793F18AD7E929158A92CBFB433EA`
>
> Depending on whether our account is governed by a deny-list or an allow-list SCP, the required change will be either adding a `Condition` to the `Deny` statement or adding `sts:AssumeRoleWithWebIdentity` to the `Allow` statement.
>
> This is a hard blocker for our project. Please let us know when this change can be implemented.
>
> Thank you.

This request gives them everything they need to solve your problem quickly. You have done your part perfectly.