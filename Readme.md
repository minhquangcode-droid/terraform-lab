                   Internet
                        │
                  Route53 (Optional)
                        │
                     ACM SSL
                        │
                Application Load Balancer
                        │
        ┌───────────────┴───────────────┐
        │                               │
      EC2 (AZ-A)                    EC2 (AZ-B)
         nginx                         nginx
        │                               │
        └───────────────┬───────────────┘
                        │
                 Auto Scaling Group
                        │
                Private Application Subnets
                        │
                 Amazon RDS MySQL
                        │
               Private Database Subnets
			   

VPC: 10.0.0.0/16
Không được phép
Tạo resource bằng AWS Console (trừ S3 backend ban đầu).
Hardcode ID của resource.
Viết toàn bộ code trong một file main.tf.
Lưu state ở local.# terraform-lab


Đây là thay đổi từ PC