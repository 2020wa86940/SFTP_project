# File Validation Lambda
resource "aws_lambda_function" "validate_file" {
  filename         = "validate_file.zip"
  function_name    = "${var.environment}-validate-file"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.handler"
  runtime         = "nodejs14.x"
  timeout         = 30

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  tags = var.common_tags
}

# Data Extraction Lambda
resource "aws_lambda_function" "extract_data" {
  filename         = "extract_data.zip"
  function_name    = "${var.environment}-extract-data"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.handler"
  runtime         = "nodejs14.x"
  timeout         = 300

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  tags = var.common_tags
}

# Similar resources for other Lambda functions...

# Handle Error Lambda
resource "aws_lambda_function" "handle_error" {
  filename         = "handle_error.zip"
  function_name    = "${var.environment}-handle-error"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "nodejs14.x"
  timeout          = 30

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  tags = var.common_tags
}


# Compare Data Lambda
resource "aws_lambda_function" "compare_data" {
  filename         = "compare_data.zip"
  function_name    = "${var.environment}-compare-data"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "nodejs14.x"
  timeout          = 60

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  tags = var.common_tags
}

# Generate Report Lambda
resource "aws_lambda_function" "generate_report" {
  filename         = "generate_report.zip"
  function_name    = "${var.environment}-generate-report"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "nodejs14.x"
  timeout          = 60

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  tags = var.common_tags
}


# Store Report Lambda
resource "aws_lambda_function" "store_report" {
  filename         = "store_report.zip"
  function_name    = "${var.environment}-store-report"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "nodejs14.x"
  timeout          = 30

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  tags = var.common_tags
}


# Processing Notification Lambda (SNS Publisher)
resource "aws_lambda_function" "processing_notification" {
  filename         = "processing_notification.zip"
  function_name    = "${var.environment}-processing-notification"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "nodejs14.x"
  timeout          = 30

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  tags = var.common_tags
}


#lambda codes needs to be included in seperate files