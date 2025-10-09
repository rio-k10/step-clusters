variable "name_prefix"       { type = string }
variable "worker_lambda_arn" { type = string }

# SFN role
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "role" {
  name               = "${var.name_prefix}-sfn-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

# Allow SFN to invoke the worker lambda
data "aws_iam_policy_document" "invoke" {
  statement {
    actions   = ["lambda:InvokeFunction", "lambda:InvokeAsync"]
    resources = [var.worker_lambda_arn]
  }
}

resource "aws_iam_role_policy" "invoke_worker" {
  name   = "${var.name_prefix}-invoke-worker"
  role   = aws_iam_role.role.id
  policy = data.aws_iam_policy_document.invoke.json
}

# Definition (invoke worker, return payload)
locals {
  definition = jsonencode({
    StartAt = "InvokeWorker",
    States = {
      InvokeWorker = {
        Type       = "Task",
        Resource   = "arn:aws:states:::lambda:invoke",
        OutputPath = "$.Payload",
        Parameters = { FunctionName = var.worker_lambda_arn, Payload = { from = "state-machine" } },
        End = true
      }
    }
  })
}

resource "aws_sfn_state_machine" "sm" {
  name       = "${var.name_prefix}-machine"
  role_arn   = aws_iam_role.role.arn
  definition = local.definition
}

# Policy for StartExecution (attach to ingress lambda)
data "aws_iam_policy_document" "start_exec" {
  statement {
    actions   = ["states:StartExecution"]
    resources = [aws_sfn_state_machine.sm.arn]
  }
}

resource "aws_iam_policy" "start_exec" {
  name   = "${var.name_prefix}-start-execution"
  policy = data.aws_iam_policy_document.start_exec.json
}

output "state_machine_arn"          { value = aws_sfn_state_machine.sm.arn }
output "start_execution_policy_arn" { value = aws_iam_policy.start_exec.arn }
