locals {
  name_prefix = "${var.project_name}-${terraform.workspace}"
}

# --- VPC (kept simple; Lambdas are not placed in VPC here) ---
module "vpc" {
  source      = "./modules/vpc"
  name_prefix = local.name_prefix
  cidr_block  = "10.10.0.0/16"
}

# --- Worker Lambda ---
module "lambda_worker" {
  source            = "./modules/lambda"
  name              = "${local.name_prefix}-worker"
  handler_file_path = "${var.lambda_build_dir}/worker.js"
  runtime           = "nodejs20.x"
  memory_mb         = var.lambda_memory_mb
  timeout_s         = var.lambda_timeout_s
  environment       = {}
}

# --- Step Functions (invokes Worker) ---
module "sfn" {
  source            = "./modules/step_functions"
  name_prefix       = local.name_prefix
  worker_lambda_arn = module.lambda_worker.lambda_arn
}

# --- Ingress Lambda (starts SFN) ---
module "lambda_ingress" {
  source            = "./modules/lambda"
  name              = "${local.name_prefix}-ingress"
  handler_file_path = "${var.lambda_build_dir}/index.js"
  runtime           = "nodejs20.x"
  memory_mb         = var.lambda_memory_mb
  timeout_s         = var.lambda_timeout_s
  environment       = { STATE_MACHINE_ARN = module.sfn.state_machine_arn }

  # Allow Ingress to call StartExecution on the state machine
  attach_policies   = [ module.sfn.start_execution_policy_arn ]
}

# --- API Gateway (HTTP API) -> Ingress Lambda ---
module "api" {
  source              = "./modules/api_gateway"
  name_prefix         = local.name_prefix
  lambda_function_name = module.lambda_ingress.lambda_name
  lambda_invoke_arn    = module.lambda_ingress.lambda_invoke_arn
}

output "api_endpoint"         { value = module.api.invoke_url }
output "ingress_lambda_name"  { value = module.lambda_ingress.lambda_name }
output "worker_lambda_name"   { value = module.lambda_worker.lambda_name }
output "state_machine_arn"    { value = module.sfn.state_machine_arn }
