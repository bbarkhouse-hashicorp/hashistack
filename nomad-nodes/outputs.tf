output "nomad_client_alb" {
  value = aws_lb.nomad_clients.id
}

output "nomad_client_x86_asg" {
  value = aws_autoscaling_group.nomad_client_x86_asg.arn
}

output "nomad_client_arm_asg" {
  value = aws_autoscaling_group.nomad_client_arm_asg.arn
}