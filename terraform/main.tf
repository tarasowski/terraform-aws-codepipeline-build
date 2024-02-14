provider "aws" {
  region = var.aws_region
}

# need to connect manually to github
# https://docs.aws.amazon.com/dtconsole/latest/userguide/connections-update.html

resource "aws_codestarconnections_connection" "github" {
  name          = "my-github-connection"
  provider_type = "GitHub"
}

resource "aws_codepipeline" "pipeline" {
  name     = "techstarter-starter-pipeline"
  role_arn = aws_iam_role.pipeline.arn

  artifact_store {
    location = aws_s3_bucket.artifact_store.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github.arn
        FullRepositoryId = "${var.github_owner}/${var.github_repo}"
        BranchName       = var.github_branch
      }
    }
  }


  stage {
    name = "Build"

    action {
      name            = "Build"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["source_output"]
      output_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        ProjectName = aws_codebuild_project.build_project.name
      }
    }
  }

    stage {
    name = "Deploy"

    action {
      name             = "Deploy"
      category         = "Deploy"
      owner            = "AWS"
      provider         = "CodeDeploy"
      input_artifacts  = ["build_output"]
      version          = "1"

      configuration = {
        ApplicationName  = aws_codedeploy_app.app.name
        DeploymentGroupName = aws_codedeploy_deployment_group.group.deployment_group_name
      }
    }
  }
}

resource "aws_iam_role" "pipeline" {
  name = "pipeline-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_codebuild_project" "build_project" {
  name          = "techstater-starter-build-project"
  description   = "My techstarter starter project"
  build_timeout = "5"
  service_role  = aws_iam_role.codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = file("${path.module}/../codebuild/buildspec.yml")
  }
}

resource "aws_iam_policy" "codebuild_s3" {
  name        = "CodeBuildS3Policy"
  description = "A policy that allows CodeBuild to download source code from S3"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:Put*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "codebuild_s3" {
  role       = aws_iam_role.codebuild.name
  policy_arn = aws_iam_policy.codebuild_s3.arn
}

resource "aws_iam_role" "codebuild" {
  name = "codebuild-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "codebuild" {
  name        = "CodeBuildPolicy"
  description = "A policy that allows starting builds in CodeBuild"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "codebuild:StartBuild",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "codebuild:BatchGetBuilds",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "codebuild_logs" {
  name        = "CodeBuildLogsPolicy"
  description = "A policy that allows CodeBuild to create log streams in CloudWatch Logs"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "logs:CreateLogStream",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "logs:CreateLogGroup",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "logs:PutLogEvents",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "codebuild_logs" {
  role       = aws_iam_role.codebuild.name
  policy_arn = aws_iam_policy.codebuild_logs.arn
}

resource "aws_iam_role_policy_attachment" "codebuild" {
  role       = aws_iam_role.pipeline.name
  policy_arn = aws_iam_policy.codebuild.arn
}

resource "aws_iam_policy" "codestar_connections" {
  name        = "CodeStarConnectionsPolicy"
  description = "A policy that allows CodePipeline to use CodeStar Connections"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "codestar-connections:UseConnection",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "codestar_connections" {
  role       = aws_iam_role.pipeline.name
  policy_arn = aws_iam_policy.codestar_connections.arn
}

resource "aws_iam_policy" "s3" {
  name        = "S3Policy"
  description = "A policy that allows uploading to S3"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::*/*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "s3" {
  role       = aws_iam_role.pipeline.name
  policy_arn = aws_iam_policy.s3.arn
}

resource "random_pet" "bucket_suffix" {
  length = 2
  prefix = "techstarter"
}

resource "aws_s3_bucket" "artifact_store" {
  bucket = random_pet.bucket_suffix.id
}

output "deployment_group_name" {
  description = "The name of the deployment group"
  value       = aws_codedeploy_deployment_group.group.deployment_group_name
}

resource "aws_codedeploy_app" "app" {
  name = "my-codedeploy-app"
}

resource "aws_codedeploy_deployment_group" "group" {
  app_name               = aws_codedeploy_app.app.name
  deployment_group_name  = "my-deployment-group"
  service_role_arn       = aws_iam_role.role.arn


  deployment_config_name = "CodeDeployDefault.OneAtATime"

  ec2_tag_set {
    ec2_tag_filter {
      key   = "Name"
      type  = "KEY_AND_VALUE"
      value = "my-ec2-instance"
    }
  }
}

resource "aws_instance" "example" {
  ami           = "ami-0c7217cdde317cfec" # This is an example Amazon Linux 2 AMI ID. Replace with the appropriate AMI ID for your region and instance type.
  instance_type = "t2.micro"

  tags = {
    Name = "my-ec2-instance"
  }
}

resource "aws_iam_role" "role" {
  name = "my-codedeploy-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "codedeploy.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "s3_access" {
  name        = "S3AccessPolicy"
  description = "Policy for accessing the S3 bucket"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "s3_access_attachment" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.s3_access.arn
}