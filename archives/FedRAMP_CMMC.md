# FedRAMP and CMMC: Overview and AWS/Kubernetes Application

## FedRAMP (Federal Risk and Authorization Management Program)

FedRAMP is a US government-wide program that standardizes security assessment, authorization, and continuous monitoring for cloud products and services used by federal agencies.

**Core elements:**

- Based on NIST SP 800-53 security controls
- Three impact levels: Low, Moderate, and High (based on potential impact of a breach)
- Requires a Third-Party Assessment Organization (3PAO) for authorization
- Continuous monitoring requirements post-authorization

**Authorization paths:**

- JAB (Joint Authorization Board) Provisional Authority to Operate (P-ATO)
- Agency ATO (sponsored by a specific federal agency)

## CMMC (Cybersecurity Maturity Model Certification)

CMMC is a DoD framework designed to protect Controlled Unclassified Information (CUI) and Federal Contract Information (FCI) within the defense industrial base.

**Structure (CMMC 2.0):**

- **Level 1 (Foundational):** 17 practices, self-assessment, protects FCI
- **Level 2 (Advanced):** 110 practices aligned with NIST SP 800-171, third-party assessment for critical programs, protects CUI
- **Level 3 (Expert):** 110+ practices from NIST 800-172, government-led assessment

-----

## Applying These Frameworks to AWS + Kubernetes

### 1. Infrastructure Foundation

**Use AWS GovCloud or compliant regions:**

- FedRAMP High and DoD SRG IL4/IL5 workloads require AWS GovCloud (US)
- FedRAMP Moderate can use standard AWS regions with appropriate controls
- AWS provides a shared responsibility model—AWS handles infrastructure controls, you handle application-level controls

**EKS considerations:**

- Amazon EKS in GovCloud is FedRAMP High authorized
- For CMMC, ensure your EKS cluster configuration meets NIST 800-171 controls

### 2. Key Control Domains to Address

**Access Control (AC):**

- Implement RBAC in Kubernetes with least-privilege principles
- Use AWS IAM roles for service accounts (IRSA)
- Enforce MFA for all administrative access
- Integrate with a FedRAMP-authorized identity provider (Okta Gov, Azure AD Gov, etc.)

**Audit and Accountability (AU):**

- Enable EKS control plane logging to CloudWatch
- Ship container logs to a compliant SIEM
- Use Falco or similar for runtime security auditing
- Retain logs per framework requirements (typically 1+ year)

**Configuration Management (CM):**

- Use Infrastructure as Code (Terraform, Bicep, CloudFormation)
- Implement admission controllers (OPA/Gatekeeper, Kyverno) to enforce policies
- Maintain a hardened base image pipeline with vulnerability scanning

**System and Communications Protection (SC):**

- Encrypt data at rest (EBS encryption, KMS-managed keys)
- Encrypt data in transit (TLS everywhere, service mesh like Istio)
- Network segmentation via VPC design and Kubernetes NetworkPolicies
- Use FIPS 140-2 validated cryptographic modules where required

### 3. Kubernetes-Specific Hardening

```yaml
# Example: Pod Security Standards enforcement
apiVersion: pod-security.kubernetes.io/enforce: restricted
apiVersion: pod-security.kubernetes.io/audit: restricted
apiVersion: pod-security.kubernetes.io/warn: restricted
```

**Key practices:**

- Disable privileged containers
- Enforce read-only root filesystems where possible
- Use non-root users in containers
- Implement resource quotas and limit ranges
- Scan images for vulnerabilities before deployment (Trivy, Grype, etc.)

### 4. Continuous Monitoring

Both frameworks require ongoing compliance verification:

- Implement AWS Config rules mapped to control families
- Use AWS Security Hub with the NIST 800-53 or CIS benchmarks
- Automate compliance scanning with tools like Prowler or OSCAL-based pipelines
- Establish a Plan of Action and Milestones (POA&M) process for findings

### 5. Documentation Requirements

Both frameworks are documentation-heavy. You’ll need:

- System Security Plan (SSP)
- Security Assessment Report (SAR)
- Continuous monitoring reports
- Incident response plans
- Configuration management plans

-----

## Key Differences to Note

|Aspect          |FedRAMP              |CMMC                                       |
|----------------|---------------------|-------------------------------------------|
|Scope           |Any federal cloud use|DoD contractors handling FCI/CUI           |
|Assessment      |3PAO required        |Self-assessment (L1) or C3PAO (L2+)        |
|Control baseline|NIST 800-53          |NIST 800-171 (with 800-172 additions at L3)|
|Reciprocity     |Can support CMMC     |FedRAMP Moderate ≈ CMMC Level 2 baseline   |

If targeting both, architecting to FedRAMP Moderate standards will cover most CMMC Level 2 requirements, though you’ll need to address the specific CMMC assessment methodology and any DoD-specific flow-down requirements in your contracts.
