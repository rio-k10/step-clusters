variable "name_prefix" { type = string }

resource "aws_sqs_queue" "dlq" {
  name                    = "${var.name_prefix}-ingress-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled = true
}

resource "aws_sqs_queue" "main" {
  name                       = "${var.name_prefix}-ingress-queue"
  visibility_timeout_seconds = 45
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 10
  sqs_managed_sse_enabled    = true
  redrive_policy             = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 5
  })
}

output "queue_arn" { value = aws_sqs_queue.main.arn }
output "queue_url" { value = aws_sqs_queue.main.id }
