# Create auto-scaling group launch template
resource "aws_launch_template" "web-application-tier-template" {
  name = "web-application-tier-template"

  block_device_mappings {
    device_name = "/dev/sdf"

    ebs {
      volume_size = 20
    }
  }

  capacity_reservation_specification {
    capacity_reservation_preference = "open"
  }

  cpu_options {
    core_count       = 4
    threads_per_core = 2
  }

  credit_specification {
    cpu_credits = "standard"
  }

  disable_api_stop        = false
  disable_api_termination = false

  ebs_optimized = true

  iam_instance_profile {
    name = "playroom-iam-instance-profile"
  }

  image_id = "ami-0341d95f75f311023" # Replace with your desired AMI ID

  instance_initiated_shutdown_behavior = "terminate"


  instance_type = "t2.micro"

  # kernel_id = "test"

  # SSH Key pair for accessing the instance
  key_name = "playroom-lab-keypair"

  #   license_specification {
  #     license_configuration_arn = "arn:aws:license-manager:eu-west-1:123456789012:license-configuration:lic-0123456789abcdef0123456789abcdef"
  #   }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  monitoring {
    enabled = true
  }


  # Remove hard-coded AZ to avoid region mismatch; let AWS choose AZ or set matching AZ
  # placement { availability_zone = "us-east-1a" }

  ram_disk_id = "test"

  vpc_security_group_ids = [aws_security_group.web-sg.id]

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "playroom-lab-web-template"
    }
  }

  user_data = base64encode(
    templatefile("${path.module}/user_data.tpl", {
      rds_endpoint  = aws_db_instance.students.address,
      rds_port      = aws_db_instance.students.port,
      rds_db_name   = aws_db_instance.students.db_name,
      rds_username  = aws_db_instance.students.username,
      db_secret_arn = aws_secretsmanager_secret.db_credentials.arn,
      efs_id        = aws_efs_file_system.app_efs.id,
      user_data_raw = file("${path.module}/user_data.sh")
    })
  )
}
