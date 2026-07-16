# Tài liệu Terraform Application

Tài liệu này mô tả trạng thái code hiện tại trong thư mục `Application`: kiến trúc, luồng dependency, chức năng từng module, cách triển khai và các điểm cần cải thiện.

## 1. Kiến trúc hiện tại

```text
Internet
   |
   | HTTP :80
   v
Application Load Balancer
   |
   | Target Group :80
   v
EC2 Auto Scaling Group
   |
   | Nginx trong private application subnets
   |
   +--> NAT Gateway --> Internet

Administrator
   |
   | SSH :22
   v
Bastion EC2 trong public subnet
```

VPC được chia thành ba tầng subnet trên tối đa ba Availability Zone:

- public subnet: ALB, Bastion và NAT Gateway;
- private application subnet: EC2 của Auto Scaling Group;
- private database subnet: dành cho RDS và không có route ra Internet.

RDS, ACM và Route 53 chưa được triển khai trong code.

## 2. Cấu trúc project

```text
Application/
├── Architecture.png
├── DOCUMENTATION.md
├── Readme.md
├── live/
│   └── prod/
│       ├── backend.tf
│       ├── provider.tf
│       ├── data.tf
│       ├── main.tf
│       ├── index.html
│       ├── outputs.tf
│       ├── variables.tf
│       └── .terraform.lock.hcl
└── modules/
    ├── vpc/
    ├── security/
    ├── ec2/
    ├── alb/
    └── asg/
```

`live/prod` là root module. Chạy các lệnh Terraform từ thư mục này.

Các thư mục trong `modules` là child module và chỉ tạo tài nguyên khi được root module gọi.

## 3. Luồng dependency

```text
AWS provider
     |
     v
VPC module
     |
     +--> public subnet IDs ----------> Bastion EC2
     |                              |
     |                              +--> Bastion SG
     |
     +--> public subnet IDs ----------> ALB
     |                              |
     |                              +--> ALB SG
     |
     +--> private subnet IDs ---------> ASG
                                    |
ALB Target Group ARN ---------------+
                                    |
Application SG <--- ALB SG/Bastion SG
```

Terraform tự suy ra thứ tự nhờ việc truyền output của module này vào input của module khác. Không cần thêm `depends_on` cho các dependency đã thể hiện qua biểu thức tham chiếu.

## 4. Root module `live/prod`

### 4.1 Backend

State được lưu tại:

```text
s3://lab-terraform-state-vmq/prod/app.tfstate
```

Bucket phải tồn tại trước khi chạy `terraform init`.

Backend hiện chưa khai báo `use_lockfile = true`. Nên bật S3 state locking để tránh hai tiến trình cùng sửa state.

### 4.2 Provider

- AWS provider: `hashicorp/aws ~> 6.54`;
- region: `us-east-1`;
- child module tự kế thừa default provider từ root module.

`.terraform.lock.hcl` phải được commit để các môi trường sử dụng cùng provider version và checksum.

### 4.3 AMI

`data.aws_ami.ubuntu` tìm AMI Ubuntu 26.04 x86_64 mới nhất từ tài khoản Canonical chính thức:

```hcl
owners = ["099720109477"]
```

AMI được dùng cho Bastion và Launch Template. Vì `most_recent = true`, một AMI mới có thể khiến EC2 hoặc Launch Template thay đổi ở lần plan sau.

### 4.4 Các module được gọi

| Module | Chức năng |
|---|---|
| `vpc` | VPC, subnet, IGW, NAT và route tables |
| `bastion_sg` | Firewall cho Bastion |
| `bastion_ec2` | Bastion host trong public subnet đầu tiên |
| `alb_sg` | Nhận HTTP từ Internet |
| `application_sg` | Nhận HTTP từ ALB và SSH từ Bastion |
| `alb` | ALB, Target Group và HTTP listener |
| `application_asg` | Launch Template, ASG và CPU scaling policy |

### 4.5 Security Group flow

```text
Internet 0.0.0.0/0 --TCP/80--> ALB SG
ALB SG               --TCP/80--> Application SG
Bastion SG           --TCP/22--> Application SG
Internet 0.0.0.0/0 --TCP/22--> Bastion SG
```

Rule SSH vào Bastion hiện mở `0.0.0.0/0`. Đây là cấu hình rủi ro và nên đổi thành IP admin dạng `x.x.x.x/32`.

### 4.6 Key pair

- Bastion EC2 dùng key pair `terraform-lab`;
- Launch Template của application hiện không nhận `key_name`, nên giá trị là `null`;
- vì vậy, dù Application SG cho phép SSH từ Bastion, application EC2 chưa thể SSH bằng key pair theo cách thông thường.

Có thể truyền:

```hcl
key_name = "terraform-lab"
```

vào module `application_asg`, hoặc bỏ SSH và quản trị instance bằng AWS Systems Manager.

### 4.7 Root outputs

Root module hiện output:

- VPC ID;
- public, private application và private database subnet IDs;
- Internet Gateway ID;
- Availability Zones;
- Bastion instance ID và public IP.

Nên bổ sung `module.alb.dns_name` để truy cập application thuận tiện sau khi apply.

## 5. VPC module

### 5.1 Availability Zones

Data source lấy các AZ khả dụng trong region hiện tại. Local value sắp xếp và lấy tối đa `az_count` AZ:

```hcl
availability_zones = slice(
  sort(data.aws_availability_zones.available.names),
  0,
  min(var.az_count, length(data.aws_availability_zones.available.names))
)
```

Với `az_count = 3`, kết quả thường là:

```text
us-east-1a
us-east-1b
us-east-1c
```

### 5.2 Subnet và CIDR

Mỗi loại subnet dùng map AZ sang index:

```hcl
for_each = {
  for index, az in local.availability_zones : az => index
}
```

Với VPC `10.0.0.0/16`, module tạo:

| Tầng | AZ-A | AZ-B | AZ-C |
|---|---|---|---|
| Public | `10.0.0.0/24` | `10.0.1.0/24` | `10.0.2.0/24` |
| Application | `10.0.10.0/24` | `10.0.11.0/24` | `10.0.12.0/24` |
| Database | `10.0.20.0/24` | `10.0.21.0/24` | `10.0.22.0/24` |

Nên thêm validation `1 <= az_count <= 10`; nếu lớn hơn 10, các offset CIDR có thể trùng nhau.

### 5.3 Public routing

```text
Public subnet
   |
Public route table
   |
0.0.0.0/0 --> Internet Gateway
```

Tất cả public subnet dùng chung một public route table.

### 5.4 Private application routing và NAT

NAT Gateway hiện đã được bật:

```text
Private application subnet
   |
Shared private route table
   |
0.0.0.0/0
   |
NAT Gateway trong public subnet đầu tiên
   |
Elastic IP + Internet Gateway
   |
Internet
```

Một NAT duy nhất giúp giảm chi phí lab nhưng có các hạn chế:

- là single point of failure cho outbound traffic;
- traffic từ AZ khác có thể phát sinh cross-AZ charge;
- production yêu cầu độ sẵn sàng cao thường dùng một NAT mỗi AZ và route table riêng theo AZ.

NAT cho phép connection đi ra từ private subnet; nó không cho Internet chủ động kết nối vào private EC2.

### 5.5 Database routing

Private database subnets dùng route table riêng và không có default route tới NAT hoặc IGW:

```text
Database subnet --> local VPC route only
```

Đây là cấu hình phù hợp để đặt RDS với `publicly_accessible = false`.

## 6. Security module

Module Security Group nhận một map `rules` chứa cả ingress và egress.

Hai local map lọc rule theo direction:

```hcl
ingress_rules = {
  for name, rule in var.rules : name => rule
  if rule.direction == "ingress"
}

egress_rules = {
  for name, rule in var.rules : name => rule
  if rule.direction == "egress"
}
```

Mỗi rule phải:

- có direction là `ingress` hoặc `egress`;
- khai báo đúng một source/destination: IPv4 CIDR, IPv6 CIDR, prefix list hoặc Security Group ID.

`ip_protocol = "-1"` kết hợp `0.0.0.0/0` ở egress nghĩa là cho phép mọi protocol đi tới mọi IPv4 destination. Route table vẫn quyết định traffic có đường tới destination hay không.

## 7. EC2 module

Module tạo một `aws_instance`, hiện dùng cho Bastion:

- AMI và instance type nhận từ root;
- gắn subnet và danh sách Security Group;
- có thể gắn public IP;
- yêu cầu IMDSv2;
- root EBS mặc định là gp3, 8 GiB, encrypted;
- gắn tag `Name`.

Biến `ebs_volume_size` hiện không được sử dụng vì volume đã được cấu hình qua object `root_volume`; nên xóa biến dư này.

`user_data` đang mặc định là chuỗi rỗng. Provider có thể cảnh báo chuỗi rỗng giống dữ liệu base64; nên đổi default thành `null`.

## 8. ALB module

Module tạo ba resource:

1. Application Load Balancer trong public subnets;
2. Target Group port 80, target type `instance`;
3. HTTP listener port 80 forward tới Target Group.

Health check mặc định:

```text
protocol: HTTP
path: /
port: traffic-port
matcher: 200-399
interval: 30 seconds
```

ALB SG nhận HTTP từ Internet. Application SG chỉ nhận port 80 từ ALB SG, vì vậy Internet không thể truy cập trực tiếp application EC2.

Hiện chưa có HTTPS listener, ACM certificate hoặc HTTP-to-HTTPS redirect.

## 9. Launch Template và Auto Scaling Group

### 9.1 Launch Template

Launch Template cấu hình:

- Ubuntu AMI;
- `t3.micro`;
- Application Security Group;
- IMDSv2 bắt buộc;
- gp3 encrypted root volume;
- instance và volume tags;
- user-data được base64 encode trước khi gửi cho EC2.

`update_default_version = true` tạo default version mới khi nội dung Launch Template thay đổi.

### 9.2 Auto Scaling Group

ASG hiện dùng:

```text
min_size         = 2
desired_capacity = 2
max_size         = 4
```

Instance được phân bổ trong private application subnets và đăng ký vào ALB Target Group. Vì Target Group được truyền vào module, health check type là `ELB`.

### 9.3 CPU scaling

CPU target tracking đang bật mặc định:

```text
Target average CPU = 60%
```

Nếu không muốn tự động scale theo CPU:

```hcl
enable_cpu_scaling = false
```

Khi giữ scaling policy, nên cân nhắc lifecycle `ignore_changes = [desired_capacity]` để Terraform không đưa capacity về giá trị khai báo sau khi AWS đã scale.

### 9.4 Instance refresh

Module sử dụng rolling instance refresh:

```hcl
instance_refresh {
  strategy = "Rolling"

  preferences {
    min_healthy_percentage = 50
    instance_warmup        = 300
    skip_matching          = true
  }
}
```

Khi Launch Template version thay đổi, ASG lần lượt thay EC2 cũ bằng EC2 mới thay vì xóa tất cả cùng lúc.

## 10. Nginx và `index.html`

User-data thực hiện:

1. cập nhật apt package metadata;
2. cài Nginx;
3. giải mã và giải nén `index.html`;
4. ghi file vào `/var/www/html/index.html`;
5. kiểm tra cấu hình và khởi động Nginx.

`index.html` lớn hơn giới hạn user-data 16 KiB nên không được nhúng nguyên văn. Root module sử dụng:

```hcl
base64gzip(file("${path.module}/index.html"))
```

EC2 giải nén bằng:

```bash
base64 --decode | gzip --decompress
```

Trang HTML hiện có favicon SVG nhúng trực tiếp, giao diện responsive, sơ đồ kiến trúc, đồng hồ, request ID, theme switcher và các tương tác JavaScript mà không phụ thuộc CDN.

Khi `index.html` thay đổi:

```text
index.html changes
   |
compressed user_data changes
   |
new Launch Template version
   |
ASG rolling instance refresh
   |
new EC2 runs user-data and serves the new page
```

User-data chỉ chạy trong lần boot đầu tiên, nên việc thay instance là cần thiết với thiết kế hiện tại.

## 11. Trạng thái triển khai trong code

| Thành phần | Trạng thái |
|---|---|
| S3 backend | Có |
| VPC và ba tầng subnet | Có |
| Internet Gateway | Có |
| Public route | Có |
| NAT Gateway và private application route | Có, một NAT |
| Isolated database route table | Có |
| Generic Security Group module | Có |
| Bastion EC2 | Có |
| ALB và Target Group | Có |
| Launch Template và ASG | Có |
| CPU target tracking | Có, mặc định bật |
| Nginx user-data | Có |
| RDS Security Group | Chưa có |
| RDS subnet group và database | Chưa có |
| ACM và HTTPS listener | Chưa có |
| Route 53 record | Chưa có |
| Monitoring/alarms | Chưa có |

## 12. Các điểm cần cải thiện

Ưu tiên:

1. Thay Bastion SSH `0.0.0.0/0` bằng admin CIDR `/32`.
2. Chọn key pair cho application EC2 hoặc chuyển sang Systems Manager.
3. Bổ sung output ALB DNS.
4. Bật state locking cho S3 backend.

Code quality:

1. Thêm validation cho `az_count`, ASG sizes và port values.
2. Xóa biến `ebs_volume_size` không được sử dụng.
3. Đổi EC2 `user_data` mặc định từ `""` sang `null`.
4. Đưa region, CIDR, admin CIDR và environment thành root variables.
5. Thống nhất tags `Name`, `Environment` và `ManagedBy`.

Các bước kiến trúc tiếp theo:

1. RDS Security Group chỉ nhận TCP/3306 từ Application SG.
2. RDS subnet group dùng private database subnet IDs.
3. RDS Multi-AZ với `publicly_accessible = false`.
4. ACM certificate và HTTPS listener.
5. Route 53 alias trỏ tới ALB.
6. CloudWatch logs, metrics và alarms.

## 13. Quy trình chạy Terraform

```bash
cd Application/live/prod

terraform fmt -recursive ../..
terraform init
terraform validate
terraform plan
terraform apply
```

Sau apply:

```bash
terraform output
terraform state list
```

Hủy môi trường:

```bash
terraform destroy
```

Không chạy nhiều lệnh apply/destroy đồng thời trên cùng state. Chỉ dùng `force-unlock` khi chắc chắn không còn tiến trình Terraform nào đang sử dụng state.

NAT Gateway, ALB và public IPv4 phát sinh chi phí ngay cả khi traffic thấp. Khi kết thúc lab, chạy destroy và kiểm tra AWS Console để chắc chắn các tài nguyên tính phí đã được xóa.
