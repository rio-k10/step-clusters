# Step Functions + Lambda (Terraform)

Minimal Terraform example that deploys:

- A Python Lambda function that echoes input.
- A Step Functions state machine that invokes the Lambda.

## Prereqs

- Terraform >= 1.9 (1.13 is fine).
- AWS credentials available via environment or `AWS_PROFILE`.
- `make` (optional but recommended).

## Quick start

```bash
# Set your AWS profile (optional)
# echo AWS_PROFILE=yourprofile >> .env

# Ensure workspace is sbox (default in .env)
echo TF_WORKSPACE=sbox > .env
echo AWS_REGION=eu-west-2 >> .env

# Initialize + create/select workspace
make init

# Plan
make plan

# Apply
make apply
```

Outputs will show the state machine ARN. You can start executions from the console or AWS CLI:

```bash
aws stepfunctions start-execution \  --state-machine-arn <arn-from-outputs> \  --name "demo-$(date +%s)" \  --input '{"message":"from cli"}' \  $( [ -n "$AWS_PROFILE" ] && echo --profile $AWS_PROFILE )
```

## Notes

- The Lambda package is built by the `archive_file` data source directly from `lambda/`.
- To add dependencies, put them into `lambda/` (vendored) or add to `requirements.txt` and run `make package`. The `pip install --target .` step vendors libs into the folder before zipping.
- State is local by default. Add a backend block if you want remote state.
