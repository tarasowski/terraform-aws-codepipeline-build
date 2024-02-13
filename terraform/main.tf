provider "aws" {
  region = "us-east-1"
}

resource "aws_codestarconnections_connection" "github" {
    name = "my-github-connection"
    provider_type = "GitHub"
}

resource "aws_codepipeline" "pipeline" {
  name     = "my-pipeline"
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
        ConnectionArn = aws_codestarconnections_connection.github.arn
        FullRepositoryId = "${var.github_owner}/${var.github_repo}"
        BranchName = var.github_branch
      }
    }
  }


  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.build_project.name
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
  name          = "my-build-project"
  description   = "My test project"
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
    type            = "CODEPIPELINE"
    buildspec       = file("${path.module}/../codebuild/buildspec.yml")
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
        "s3:GetObjectVersion"
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
      "Resource": "arn:aws:codestar-connections:us-east-1:586283906760:connection/0404ab44-9493-47d2-ab3f-5d847ac96a97"
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

resource "aws_s3_bucket" "artifact_store" {
  bucket = "my-artifact-store-random-name"
# Remove the aws_s3_bucket_acl attribute
# aws_s3_bucket_acl   = "private"
}