# CircleCI + AWS + OPA + Terraform Lab

A hands-on lab demonstrating cloud security automation using CircleCI, AWS OIDC, Open Policy Agent, and Terraform.

---

## What This Lab Demonstrates

| What | How |
|---|---|
| Policy as Code | Security rules written in OPA Rego, version-controlled and testable |
| CI/CD Automation | CircleCI pipeline that runs security checks on every push |
| Secure AWS Authentication | OIDC-based authentication, no long-term credentials stored anywhere |
| Infrastructure as Code | Terraform provisioning a compliant S3 bucket in AWS |
| Compliance Gates | Pipeline stops automatically if any security check fails |

---

## Repo Structure

| File | Purpose |
|---|---|
| `.circleci/config.yml` | Pipeline definition |
| `policies/security/s3.rego` | OPA security policy |
| `tests/s3_test.rego` | OPA policy tests |
| `terraform/main.tf` | Infrastructure blueprint |
| `compliant-s3.json` | Sample compliant S3 resource |
| `non-compliant-s3.json` | Sample non-compliant S3 resource |
| `circleci-trust-policy.json` | AWS trust policy |
| `circleci-policy.json` | AWS permissions policy |

---

## Pipeline Jobs

The pipeline runs five jobs defined in `.circleci/config.yml`:

| Job | What it does |
|---|---|
| `test-aws-oidc` | Verifies CircleCI can authenticate to AWS using OIDC |
| `test-opa-policies` | Runs the three OPA unit tests in `s3_test.rego` |
| `validate-compliant-resource` | Feeds `compliant-s3.json` into OPA - expects zero violations |
| `validate-non-compliant-resource` | Feeds `non-compliant-s3.json` into OPA - expects violations |
| `validate-terraform` | Runs `terraform init`, `validate`, and `apply` to provision infrastructure |

`test-aws-oidc` runs at the same time as `test-opa-policies`. All other jobs wait for those two to pass first.

---

## Step-by-Step Lab Setup

### Step 1: Create the GitHub Repo

Create a new GitHub repository named:

```
circleci-aws-opa-terraform-lab
```

Add all the project files listed in the repo structure above and commit them to the `main` branch.

> **What you are doing:** Creating the source repo that CircleCI will watch for changes.

---

### Step 2: Connect the Repo to CircleCI

1. Go to CircleCI (https://app.circleci.com/login)
2. Click **Log in with GitHub**
3. Go to **Projects** and find your repo: `circleci-aws-opa-terraform-lab`
4. Click **Set Up Project**
5. If prompted, select `main` as the default branch

CircleCI will now watch this repository and trigger a pipeline on every push.

> **Important:** `config.yml` must be inside a folder named `.circleci` at the repo root. CircleCI will not detect the pipeline otherwise.

---

### Step 2A: Authorize CircleCI to Access GitHub via SSH

Without this step, every job will fail at checkout with a `Permission denied (publickey)` error.

1. Go to your CircleCI project **Settings**
2. Click **SSH Keys** in the left panel
3. Under **User Key**, click **Authorize with GitHub**
4. Click **Add User Key**
5. Click **Confirm User**

---

### Step 3: Get Your CircleCI IDs

You will need your **Organization ID** and **Project ID** for the AWS trust policy.

**Organization ID:**
1. In CircleCI, click **Org** in the left panel
2. Copy the Organization ID from this page

**Project ID:**
1. Go back to the home tab
2. On your project card, click **Overview**, then click **Settings**
3. Copy the Project ID from this page

---

### Step 4: Create the AWS OIDC Identity Provider

This tells AWS to trust tokens issued by CircleCI.

1. Go to **AWS IAM → Identity providers**
2. Click **Add provider**
3. For Provider type, choose **OpenID Connect**
4. For Provider URL, enter: `https://oidc.circleci.com/org/<your-org-id>`
5. For Audience, enter your **Organization ID** (must match exactly)
6. Click **Add provider**

---

### Step 5: Create the IAM Role CircleCI Will Assume

1. Go to **AWS IAM → Roles → Create role**
2. Choose **Web identity** as the trusted entity type
3. Select the OIDC provider you just created
4. Select your **Organization ID** as the audience
5. Click **Next**
6. Search for and attach **AmazonS3FullAccess**
7. Name the role: `CircleCI-OIDC-Lab-Role`
8. Click **Create role**

> **Why AmazonS3FullAccess?** Terraform needs to create, configure, and read S3 buckets and their policies. ReadOnlyAccess is not sufficient.

---

### Step 6: Update the Trust Policy

The trust policy restricts which CircleCI org and project can assume the role.

Open `circleci-trust-policy.json` and confirm your **AWS Account ID**, **Org ID**, and **Project ID** are correctly set in all places they appear:

- **Federated ARN** - contains your AWS account ID and Org ID
- **Condition key names** - contain your Org ID
- **`aud` value** - your Org ID
- **`sub` value** - contains both your Org ID and Project ID

Then go to **AWS IAM → Roles → CircleCI-OIDC-Lab-Role → Trust relationships → Edit trust policy**, paste the contents of `circleci-trust-policy.json`, and save.

---

### Step 7: Add the Role ARN to CircleCI

Copy the ARN from your IAM role. It will look like:

```
arn:aws:iam::123456789012:role/CircleCI-OIDC-Lab-Role
```

Then in CircleCI:

1. Go to your project **Settings → Environment Variables**
2. Click **Add Variable**
3. Name: `AWS_ROLE_ARN` - Value: your role ARN

> The variable name must exactly match what `config.yml` expects.

---

### Step 8: Review the Key Files

**`policies/security/s3.rego`**
The OPA policy file. Contains two rules: S3 buckets must have server-side encryption enabled, and S3 buckets must not use a `public-read` ACL.

**`tests/s3_test.rego`**
Tests the policy logic before it runs in automation. Confirms the policy correctly allows compliant buckets and catches violations.

**`terraform/main.tf`**
The infrastructure blueprint. Defines a compliant S3 bucket with encryption, versioning, and public access blocking enabled.

**`circleci-trust-policy.json`**
Controls who is allowed to assume the IAM role - scoped to your specific CircleCI org and project.

**`circleci-policy.json`**
Controls what CircleCI is allowed to do in AWS once it has assumed the role.

---

### Step 9: Trigger the Pipeline

Push a commit to GitHub - CircleCI will detect it and trigger the pipeline automatically.

Or trigger it manually in CircleCI:
1. Click **Trigger Pipeline** in the top right
2. Select **main** from the Config source dropdown
3. Click **Run Pipeline**

---

### Step 10: Watch the Pipeline Run

In CircleCI you will see all five jobs. Click into any job to view its logs.

**What to look for:**

- **`test-aws-oidc`** - look for the `Test AWS authentication with OIDC` step showing green. This confirms the secret handshake between CircleCI and AWS worked.
- **`test-opa-policies`** - confirms all three OPA unit tests passed.
- **`validate-compliant-resource`** - OPA found zero violations. The good bucket passed.
- **`validate-non-compliant-resource`** - OPA found violations. The bad bucket was correctly blocked.
- **`validate-terraform`** - Terraform initialized, validated, and applied. A real S3 bucket was created in AWS.

> **Note:** Each successful `terraform apply` creates a new bucket with a random suffix. If you re-run the pipeline multiple times, you will accumulate buckets. Clean up old ones manually in the AWS S3 console.

---

## How This Connects to GRC

This lab implements several cloud governance concepts in code:

| GRC Concept | How it's implemented |
|---|---|
| Security controls | OPA policy rules in `s3.rego` |
| Continuous control monitoring | Pipeline runs on every commit |
| Evidence collection | CircleCI job logs with timestamps |
| Drift prevention | Non-compliant resources blocked before deployment |
| Audit trail | Full change history in Git |
| Least privilege access | OIDC temporary credentials, scoped IAM role |

**Frameworks supported:**
- **SOC 2**: CC6, CC7, CC8
- **NIST 800-53**: CM-2, CM-6, SI-7
- **CIS Benchmarks**: S3 encryption and public access controls
- **ISO 27001**: Operations security and system development controls

---

## Video Series

This lab is accompanied by a 4-part YouTube series: **Cloud Security Automation Series**

| Video | Title |
|---|---|
| [Part 1](https://youtu.be/LkgudHL7gHg) | OPA & Policy-as-Code - The Digital Rulebook |
| [Part 2](https://youtu.be/duBk5lrBO2s) | CI/CD Pipeline - The Automated Assembly Line |
| Part 3 | AWS Authentication with OIDC - The Secret Handshake |
| Part 4 | Terraform Provisioning - The Blueprint Check |

---
