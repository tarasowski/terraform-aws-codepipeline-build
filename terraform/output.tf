output "pipeline_arn" {
  description = "The ARN of the CodePipeline"
  value       = aws_codepipeline.pipeline.arn
}

# Add any additional outputs as needed