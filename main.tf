terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.32.1"
    }
  }
  required_version = "~>1.5"
  backend "local" {
    path = "terraform.local.tfstate"
  }
}
provider "aws" {
  region     = "us-east-1" # Change this to your desired AWS region
  access_key = "mykey"
  secret_key = "mysecretid"
}

# Use data block to get information about the default VPC
data "aws_vpcs" "default" {
  filter {
    name   = "isDefault"
    values = ["true"]
  }
}

# Use data block to get information about the default subnet in the default VPC
data "aws_subnet" "default" {
  vpc_id = data.aws_vpcs.default.ids[0]

  # Add additional constraint to uniquely identify the subnet
  availability_zone = "us-east-1a" # Specify the desired availability zone
}


# Define the launch configuration
resource "aws_launch_configuration" "example" {
  name          = "example-config"        # Specify your desired instance type
  image_id      = "ami-0c7217cdde317cfec" # Amazon Linux in us-east-1, update as per your region
  instance_type = "t2.micro"
  key_name      = "demo01"

  # Additional configuration like user data, security groups, etc., can be added here

  lifecycle {
    create_before_destroy = true
  }
}

# Define the autoscaling group
resource "aws_autoscaling_group" "example" {
  desired_capacity     = 2
  max_size             = 5
  min_size             = 2
  launch_configuration = aws_launch_configuration.example.id

  health_check_type         = "EC2"
  health_check_grace_period = 300

  vpc_zone_identifier = [data.aws_subnet.default.id]

  tag {
    key                 = "Name"
    value               = "example-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}
# Define the CloudWatch metric alarm for scaling up
resource "aws_cloudwatch_metric_alarm" "scale_up" {
  alarm_name          = "scale-up-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization" # Update this metric name based on your requirements
  namespace           = "AWS/EC2"
  period              = 300 # 5 minutes
  statistic           = "Average"
  threshold           = 75 # Set your desired threshold value

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.example.name
  }

  alarm_description = "Scale up when the 5-minute load average exceeds 75%"

  alarm_actions = [aws_autoscaling_policy.scale_up.arn]
}

# Define the CloudWatch metric alarm for scaling down
resource "aws_cloudwatch_metric_alarm" "scale_down" {
  alarm_name          = "scale-down-alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization" # Update this metric name based on your requirements
  namespace           = "AWS/EC2"
  period              = 300 # 5 minutes
  statistic           = "Average"
  threshold           = 50 # Set your desired threshold value

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.example.name
  }

  alarm_description = "Scale down when the 5-minute load average is less than 50%"

  alarm_actions = [aws_autoscaling_policy.scale_down.arn]
}

# Define an SNS topic for sending email alerts
resource "aws_sns_topic" "autoscaling_alerts" {
  name = "autoscaling-alerts"
}

# Subscribe an email address to the SNS topic
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.autoscaling_alerts.arn
  protocol  = "email"
  endpoint  = "gfghfff@mail.com" # Replace with your email address
}


# Define the autoscaling policies
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "scale-up-policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300 # 5 minutes
  autoscaling_group_name = aws_autoscaling_group.example.name
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "scale-down-policy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300 # 5 minutes
  autoscaling_group_name = aws_autoscaling_group.example.name
}
# Define the scheduled action for daily refresh at UTC 12 am
resource "aws_autoscaling_schedule" "daily_refresh" {
  scheduled_action_name  = "daily-refresh"
  min_size               = 0
  max_size               = 0
  desired_capacity       = 0
  recurrence             = "0 0 * * *" # Minutes Hours it's for 24hour format. 
  autoscaling_group_name = aws_autoscaling_group.example.name
}
