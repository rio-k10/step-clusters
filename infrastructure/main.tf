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
  handler_function_path = "worker.handler"
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
  source                = "./modules/lambda"
  name                  = "${local.name_prefix}-ingress"
  handler_file_path     = "${var.lambda_build_dir}/index.js"
  handler_function_path = "index.handler"
  runtime               = "nodejs20.x"
  memory_mb             = var.lambda_memory_mb
  timeout_s             = var.lambda_timeout_s
  environment = {
    QUEUE_URL = module.sqs.queue_url
  }
  attach_policies = [
    aws_iam_policy.producer_send_sqs.arn
  ]
}

module "lambda_consumer" {
  source                = "./modules/lambda"
  name                  = "${local.name_prefix}-consumer"
  handler_file_path     = "${var.lambda_build_dir}/consumer.js"
  handler_function_path = "consumer.handler"
  runtime               = "nodejs20.x"
  memory_mb             = var.lambda_memory_mb
  timeout_s             = var.lambda_timeout_s
  environment = {
    STATE_MACHINE_ARN = module.sfn.state_machine_arn
  }
  attach_policies = [
    module.sfn.start_execution_policy_arn
  ]
}

resource "aws_lambda_event_source_mapping" "sqs_to_consumer" {
  event_source_arn = module.sqs.queue_arn
  function_name    = module.lambda_consumer.lambda_arn

  batch_size                          = 10
  maximum_batching_window_in_seconds  = 2
  function_response_types             = ["ReportBatchItemFailures"]
}




# --- API Gateway (HTTP API) -> Ingress Lambda ---
module "api" {
  source              = "./modules/api_gateway"
  name_prefix         = local.name_prefix
  lambda_function_name = module.lambda_ingress.lambda_name
  lambda_invoke_arn    = module.lambda_ingress.lambda_invoke_arn
}

module "sqs" {
  source      = "./modules/sqs"
  name_prefix = local.name_prefix
}

data "aws_iam_policy_document" "producer_send_sqs" {
  statement {
    actions   = ["sqs:SendMessage", "sqs:SendMessageBatch"]
    resources = [module.sqs.queue_arn]
  }
}

resource "aws_iam_policy" "producer_send_sqs" {
  name   = "${local.name_prefix}-producer-send-sqs"
  policy = data.aws_iam_policy_document.producer_send_sqs.json
}


output "api_endpoint"         { value = module.api.invoke_url }
output "ingress_lambda_name"  { value = module.lambda_ingress.lambda_name }
output "worker_lambda_name"   { value = module.lambda_worker.lambda_name }
output "state_machine_arn"    { value = module.sfn.state_machine_arn }
output "queue_url" { value = module.sqs.queue_url }
output "queue_arn" { value = module.sqs.queue_arn }