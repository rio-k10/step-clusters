variable "name"              { type = string }
variable "handler_file_path" { type = string }
variable "runtime"           { type = string }
variable "memory_mb"         { type = number }
variable "timeout_s"         { type = number }
variable "environment" {
  type    = map(string)
  default = {}
}
variable "attach_policies" {
  type    = list(string)
  default = []
}

# Execution role
data "aws_iam_policy_document" "assume_lambda" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "role" {
  name               = "${var.name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
}

resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "extras" {
  for_each   = toset(var.attach_policies)
  role       = aws_iam_role.role.name
  policy_arn = each.value
}

# Explicit log group (no retention configured => destroyed with stack)
resource "aws_cloudwatch_log_group" "lg" {
  name         = "/aws/lambda/${var.name}"
  skip_destroy = false
}

# Zip the single built file
data "archive_file" "zip" {
  type        = "zip"
  source_file = var.handler_file_path
  output_path = "${path.module}/../.dist/${var.name}.zip"
}

resource "aws_lambda_function" "fn" {
  function_name    = var.name
  role             = aws_iam_role.role.arn
  filename         = data.archive_file.zip.output_path
  source_code_hash = data.archive_file.zip.output_base64sha256
  runtime          = var.runtime
  handler          = "index.handler"
  memory_size      = var.memory_mb
  timeout          = var.timeout_s

  environment { variables = var.environment }

  depends_on = [aws_cloudwatch_log_group.lg]
}

output "lambda_arn"        { value = aws_lambda_function.fn.arn }
output "lambda_invoke_arn" { value = aws_lambda_function.fn.invoke_arn }
output "lambda_name"       { value = aws_lambda_function.fn.function_name }
output "log_group"         { value = aws_cloudwatch_log_group.lg.name }
