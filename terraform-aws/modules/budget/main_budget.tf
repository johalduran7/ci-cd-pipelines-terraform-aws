# Create a budget
resource "aws_budgets_budget" "monthly_budget" {
  name         = "MonthlyCostBudget_ec2"
  budget_type  = "COST"
  limit_amount = "10" # Set the budget limit to $21
  limit_unit   = "USD"

  time_unit = "MONTHLY" # Set the budget time unit to monthly
  cost_filter {
    name = "Service"
    values = [
      "Amazon Elastic Compute Cloud - Compute",
    ]
  }

  # Optional notifications (e.g., notify if cost exceeds 80% of the budget)
  notification {
    notification_type          = "ACTUAL"
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80 # Notify when cost exceeds 80% of the budget
    threshold_type             = "PERCENTAGE"
    subscriber_email_addresses = ["johalduran@gmail.com"] # Replace with your email address

  }
  # Add tags to the policy
  tags = {
    "Terraform" = "yes"
    "AWS_SAA"   = "yes"
  }
}

locals {
  budget_name = "Overall Costs"
}

#terraform state rm aws_budgets_budget.overall_costs "948586925757:Overall Costs"
# Create the AWS Budget resource
resource "aws_budgets_budget" "overall_costs" {
  name        = local.budget_name
  account_id  = "948586925757"
  budget_type = "COST"

  limit_amount = "20.0" # Budget limit amount
  limit_unit   = "USD"  # Budget limit unit

  time_unit = "MONTHLY" # Set to the appropriate time unit

  # # Provisioner to run the import command
  # provisioner "local-exec" {
  #   command = <<EOT
  #     terraform import aws_budgets_budget.overall_costs "948586925757:${local.budget_name}"
  #   EOT
  # }

  # Optional notifications (e.g., notify if cost exceeds 80% of the budget)
  notification {
    notification_type          = "ACTUAL"
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80 # Notify when cost exceeds 80% of the budget
    threshold_type             = "PERCENTAGE"
    subscriber_email_addresses = ["johalduran@gmail.com"] # Replace with your email address

  }
  # Optional: Tags can be added if required
  tags = {
    "Terraform" = "yes"
    "AWS_SAA"   = "yes"
    "Imported"  = "yes" #tag created by me to definie when an existing resource was imported
  }
}



data "aws_budgets_budget" "overall_costs" { # importing this one to my config
  name = resource.aws_budgets_budget.overall_costs.name
  #name = local.budget_name
}

output "overall_costs" {
  #value       = data.aws_budgets_budget.overall_costs
  value       = resource.aws_budgets_budget.overall_costs.name
  description = "Fetching data from the existing budget resource created before I implemented this"
  depends_on  = [data.aws_budgets_budget.overall_costs]
}



# Output the budget details
output "budget_name" {
  value = aws_budgets_budget.monthly_budget.name
}


