output "api_gateway_public_ip" {
  description = "Public IP of the API Gateway (VM1) — use this in curl"
  value       = aws_instance.vm1_api_gateway.public_ip
}

output "api_gateway_private_ip" {
  description = "Private IP of VM1 (workers connect to this)"
  value       = aws_instance.vm1_api_gateway.private_ip
}

output "caller_worker_private_ip" {
  description = "Private IP of VM2 (caller worker)"
  value       = aws_instance.vm2_caller.private_ip
}

output "inference_worker_private_ip" {
  description = "Private IP of VM3 (inference worker)"
  value       = aws_instance.vm3_inference.private_ip
}

output "curl_health" {
  description = "Health check command"
  value       = "curl http://${aws_instance.vm1_api_gateway.public_ip}/health"
}

output "curl_inference" {
  description = "Inference test command"
  value       = "curl -X POST http://${aws_instance.vm1_api_gateway.public_ip}/v1/chat/completions -H 'Content-Type: application/json' -d '{\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}]}'"
}
