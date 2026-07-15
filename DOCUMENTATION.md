# Tài liệu giải thích Terraform Application

Tài liệu này mô tả **đúng trạng thái code hiện tại** trong thư mục `Application`. Mục tiêu là giúp người đọc hiểu Terraform bắt đầu từ đâu, mỗi module tạo tài nguyên gì, các tài nguyên liên kết với nhau như thế nào và phần nào vẫn chưa được triển khai.

## 1. Tổng quan

Project hướng tới kiến trúc web nhiều tầng trên AWS:

```text
Internet
   |
Route 53 + ACM
   |
Application Load Balancer trong public subnets
   |
EC2 Auto Scaling Group trong private application subnets
   |
RDS MySQL trong private database subnets
```

Hiện tại code mới triển khai phần nền tảng:

```text
Đã có
├── VPC
├── Internet Gateway
├── Public subnets
├── Private application subnets
├── Private database subnets
├── Route tables và associations
├── Public route tới Internet Gateway
├── Module Security Group dùng chung
└── Một Bastion Security Group được gọi từ prod

Chưa có
├── NAT Gateway đang bị comment
├── Bastion EC2 instance
├── Application Load Balancer
├── ACM và Route 53
├── Launch Template
├── Auto Scaling Group
├── Application EC2 instances
├── RDS DB subnet group
└── RDS MySQL
```

Hình kiến trúc mục tiêu nằm tại [`Architecture.png`](./Architecture.png).

## 2. Cấu trúc thư mục

```text
Application/
├── Architecture.png
├── DOCUMENTATION.md
├── Readme.md
├── live/
│   └── prod/
│       ├── backend.tf
│       ├── provider.tf
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── data.tf
│       └── .terraform.lock.hcl
└── modules/
    ├── vpc/
    │   ├── main.tf
    │   ├── routes.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── security/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

`live/prod` là **root module**. Đây là thư mục chạy các lệnh `terraform init`, `terraform plan`, `terraform apply` và `terraform destroy`.

`modules/vpc` và `modules/security` là các **child module**. Chúng không tự chạy; root module gọi chúng bằng block `module`.

## 3. Luồng dependency giữa các module

```text
AWS provider (us-east-1)
          |
          v
     module.vpc
          |
          | output: vpc_id
          v
  module.bastion_sg
```

Terraform tự suy ra thứ tự tạo:

1. Cấu hình AWS provider.
2. Tạo VPC và các tài nguyên network.
3. Lấy `module.vpc.vpc_id`.
4. Tạo Bastion Security Group trong VPC đó.

Không cần viết `depends_on` giữa hai module vì biểu thức `vpc_id = module.vpc.vpc_id` đã tạo dependency tự nhiên.

## 4. Root module `live/prod`

### 4.1 `backend.tf`

```hcl
terraform {
  backend "s3" {
    bucket = "lab-terraform-state-vmq"
    key    = "prod/app.tfstate"
    region = "us-east-1"
  }
}
```

Backend quyết định nơi lưu Terraform state:

```text
s3://lab-terraform-state-vmq/prod/app.tfstate
```

Bucket backend phải tồn tại trước khi chạy `terraform init`. Region trong backend chỉ dùng để truy cập bucket state; nó không cấu hình region cho AWS resources.

### 4.2 `provider.tf`

File này:

- yêu cầu AWS provider phiên bản tương thích với `6.54`;
- cấu hình region mặc định là `us-east-1`.

```hcl
provider "aws" {
  region = "us-east-1"
}
```

Các child module tự kế thừa default AWS provider này. Vì vậy module VPC không cần nhận biến `region`.

### 4.3 `.terraform.lock.hcl`

Lock file đang khóa AWS provider ở phiên bản `6.54.0` cùng các checksum. File này nên được commit để local và CI sử dụng cùng provider build.

Không chỉnh sửa lock file bằng tay. Terraform cập nhật file khi chạy `terraform init` hoặc `terraform init -upgrade`.

### 4.4 `main.tf`

Root module hiện gọi hai module.

#### VPC module

```hcl
module "vpc" {
  source = "../../modules/vpc"

  vpc_cidr = "10.0.0.0/16"
  tag      = "Create by terraform"
  az_count = 3
}
```

Ý nghĩa:

- tạo VPC CIDR `10.0.0.0/16`;
- lấy tối đa ba Availability Zone;
- tạo một public, một private application và một private database subnet trong mỗi AZ.

#### Bastion Security Group module

Root module gọi module `security` để tạo một SG tên `bastion-sg`.

Map `rules` hiện chứa:

- một ingress TCP/22;
- một egress cho phép mọi protocol tới mọi IPv4 destination.

Lưu ý quan trọng: ingress SSH hiện dùng `0.0.0.0/0`, nghĩa là mở port 22 cho toàn Internet. Key `ssh_from_bastion` cũng không khớp với ý nghĩa rule vì đây là traffic đi **vào Bastion**. Cấu hình an toàn hơn là đổi thành `ssh_from_admin` và dùng IP public của quản trị viên theo dạng `/32`.

Ví dụ mong muốn:

```hcl
ssh_from_admin = {
  description = "Allow SSH from administrator IP"
  direction   = "ingress"
  ip_protocol = "tcp"
  from_port   = 22
  to_port     = 22
  cidr_ipv4   = "203.0.113.10/32"
}
```

Security Group không tạo Bastion EC2. Nó chỉ là firewall để gắn vào Bastion EC2 được tạo sau này.

### 4.5 `variables.tf` và `data.tf`

Hai file này hiện đang rỗng.

Khi bỏ hardcode IP admin, nên khai báo `admin_cidr` trong `variables.tf` và truyền giá trị qua `terraform.tfvars` hoặc command line.

### 4.6 `outputs.tf`

Root module expose lại các output của VPC:

| Output | Nội dung |
|---|---|
| `vpc_id` | ID của VPC |
| `public_subnet_ids` | Danh sách public subnet ID |
| `private_subnet_ids` | Danh sách private application subnet ID |
| `private_database_subnet_ids` | Danh sách private database subnet ID |
| `internet_gateway_id` | ID của Internet Gateway |
| `availability_zones` | Danh sách AZ đã chọn |

Output chỉ hiển thị hoặc truyền dữ liệu; nó không tạo thêm AWS resource.

## 5. VPC module

### 5.1 Inputs

`modules/vpc/variables.tf` có ba biến:

| Biến | Kiểu | Default | Ý nghĩa |
|---|---|---:|---|
| `vpc_cidr` | `string` | `10.0.0.0/16` | CIDR chính của VPC |
| `az_count` | `number` | `3` | Số AZ tối đa được sử dụng |
| `tag` | `string` | `Create by terraform` | Nội dung tag mô tả |

Hiện `az_count` chưa có validation. Do code chia CIDR theo các dải `0`, `10` và `20`, nên nên giới hạn `az_count` trong khoảng `1..10` để các nhóm subnet không chồng lấn.

### 5.2 VPC và Internet Gateway

`aws_vpc.this` tạo VPC với DNS support và DNS hostnames được bật.

`aws_internet_gateway.igw` gắn Internet Gateway vào VPC. Chỉ tạo IGW chưa làm subnet trở thành public; subnet còn cần route `0.0.0.0/0 -> IGW`.

### 5.3 Lấy Availability Zones

Data source:

```hcl
data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required", "opted-in"]
  }
}
```

lấy các AZ khả dụng trong region của provider, hiện là `us-east-1`.

Local value xử lý danh sách:

```hcl
availability_zones = slice(
  sort(data.aws_availability_zones.available.names),
  0,
  min(var.az_count, length(data.aws_availability_zones.available.names))
)
```

Luồng xử lý:

1. Lấy tất cả tên AZ khả dụng.
2. `sort()` sắp xếp tên để thứ tự ổn định.
3. `length()` đếm số AZ thật sự có.
4. `min()` tránh lấy quá số AZ hiện có.
5. `slice()` lấy từ phần tử đầu tiên đến tối đa `az_count`.

Ví dụ với `az_count = 3`:

```hcl
[
  "us-east-1a",
  "us-east-1b",
  "us-east-1c"
]
```

Nếu region chỉ trả về hai AZ thì module chỉ tạo tài nguyên trong hai AZ, không báo lỗi vì yêu cầu ba AZ.

### 5.4 Cách `for_each` tạo subnet

Mỗi loại subnet dùng:

```hcl
for_each = {
  for index, az in local.availability_zones : az => index
}
```

Danh sách AZ được chuyển thành map:

```hcl
{
  "us-east-1a" = 0
  "us-east-1b" = 1
  "us-east-1c" = 2
}
```

Trong mỗi resource instance:

- `each.key` là tên AZ;
- `each.value` là index bắt đầu từ `0`.

Địa chỉ Terraform có dạng:

```text
aws_subnet.public["us-east-1a"]
aws_subnet.private["us-east-1a"]
aws_subnet.private_database["us-east-1a"]
```

Dùng AZ làm key ổn định và dễ hiểu hơn dùng `count` với index thuần túy.

### 5.5 Quy hoạch CIDR

Code sử dụng `cidrsubnet(var.vpc_cidr, 8, netnum)`. Với VPC `/16`, thêm tám bit tạo subnet `/24`.

Khi `az_count = 3`, CIDR dự kiến là:

| Tầng | AZ index 0 | AZ index 1 | AZ index 2 |
|---|---|---|---|
| Public | `10.0.0.0/24` | `10.0.1.0/24` | `10.0.2.0/24` |
| Private application | `10.0.10.0/24` | `10.0.11.0/24` | `10.0.12.0/24` |
| Private database | `10.0.20.0/24` | `10.0.21.0/24` | `10.0.22.0/24` |

Public subnet bật:

```hcl
map_public_ip_on_launch = true
```

nên EC2 mới được launch trong đó có thể tự nhận public IPv4. Private application và database subnet đặt giá trị này thành `false`.

`map_public_ip_on_launch` không tự tạo Internet connectivity. Route table vẫn quyết định đường đi của traffic.

### 5.6 Routing hiện tại

#### Public routing

```text
Public subnet
   |
Public route table
   |
0.0.0.0/0 -> Internet Gateway
   |
Internet
```

Một public route table được dùng chung cho tất cả public subnet. `aws_route_table_association.public` lặp qua map `aws_subnet.public` và gắn từng subnet vào route table này.

#### Private application routing

Tất cả private application subnet dùng chung `aws_route_table.private`.

NAT Gateway và route `0.0.0.0/0 -> NAT Gateway` đang bị comment. Vì vậy trạng thái hiện tại là:

```text
Private application subnet
   |
Private route table
   |
Chỉ có route local trong VPC
```

EC2 trong các subnet này hiện không có đường ra Internet. Chúng vẫn có thể giao tiếp với tài nguyên trong VPC nếu Security Group cho phép.

#### Private database routing

Database subnets dùng chung một route table khác và chỉ có route local mặc định. Đây là thiết kế cô lập phù hợp cho RDS:

```text
Private database subnet
   |
Private database route table
   |
Không có IGW hoặc NAT route
```

### 5.7 NAT Gateway đang bị tắt

Các resource `aws_eip.nat`, `aws_nat_gateway.nat_gw` và route private Internet đều đang được comment.

Nếu bật lại một NAT Gateway duy nhất:

- NAT nằm trong public subnet đầu tiên;
- tất cả private application subnet đi qua NAT đó;
- chi phí thấp hơn mô hình một NAT mỗi AZ;
- nhưng NAT trở thành single point of failure cho outbound traffic;
- traffic từ AZ khác có thể đi xuyên AZ.

Database route table không nên được route tới NAT nếu RDS không có nhu cầu đặc biệt.

### 5.8 Outputs của VPC

VPC module output các ID cần cho module phía sau:

```text
vpc_id
public_subnet_ids
private_subnet_ids
private_database_subnet_ids
internet_gateway_id
availability_zones
subnet_ids
```

`subnet_ids` ghép theo thứ tự:

1. toàn bộ public subnet;
2. toàn bộ private application subnet;
3. toàn bộ private database subnet.

Khi module khác cần đúng một loại subnet, nên dùng output riêng thay vì `subnet_ids` tổng hợp.

## 6. Security module

Module `modules/security` là module generic: mỗi lần gọi tạo **một Security Group** và số rule tùy ý.

### 6.1 Inputs

| Biến | Ý nghĩa |
|---|---|
| `name` | Tên Security Group |
| `vpc_id` | VPC chứa Security Group |
| `description` | Mô tả SG, có default |
| `rules` | Map chứa cả ingress và egress rule |
| `tags` | Map tag bổ sung |

Mỗi rule có dạng tổng quát:

```hcl
rule_name = {
  description                  = optional(string)
  direction                    = "ingress" hoặc "egress"
  ip_protocol                  = "tcp", "udp", "icmp" hoặc "-1"
  from_port                    = optional(number)
  to_port                      = optional(number)
  cidr_ipv4                    = optional(string)
  cidr_ipv6                    = optional(string)
  prefix_list_id               = optional(string)
  referenced_security_group_id = optional(string)
}
```

Validation yêu cầu:

1. `direction` chỉ được là `ingress` hoặc `egress`;
2. mỗi rule phải có đúng một source/destination trong bốn loại CIDR IPv4, CIDR IPv6, prefix list hoặc Security Group reference.

### 6.2 Tách ingress và egress

Module nhận một map `rules`, sau đó tạo hai map local:

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

Đây là map comprehension có điều kiện:

- lặp qua từng `name` và `rule`;
- giữ nguyên cặp `name => rule`;
- chỉ giữ rule có direction phù hợp.

### 6.3 Tạo rule bằng `for_each`

Ingress map được dùng bởi:

```hcl
aws_vpc_security_group_ingress_rule.this
```

Egress map được dùng bởi:

```hcl
aws_vpc_security_group_egress_rule.this
```

Ví dụ key `ssh_from_admin` tạo địa chỉ Terraform:

```text
aws_vpc_security_group_ingress_rule.this["ssh_from_admin"]
```

Rule:

```hcl
allow_all_egress = {
  direction   = "egress"
  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}
```

nghĩa là cho phép mọi IP protocol đi tới mọi địa chỉ IPv4. Rule firewall không tự tạo route; resource vẫn cần IGW hoặc NAT nếu muốn đi Internet.

Security Group là stateful: response traffic của một request đã được cho phép sẽ tự động được phép quay lại.

### 6.4 Outputs

Module output:

```text
security_group_id
security_group_arn
```

Các module ALB, EC2 hoặc RDS sau này sẽ nhận `security_group_id` để gắn SG vào tài nguyên tương ứng.

## 7. Trạng thái so với architecture mục tiêu

| Thành phần | Trạng thái | Ghi chú |
|---|---|---|
| S3 backend | Có | Bucket phải tạo trước |
| AWS provider | Có | Region `us-east-1` |
| VPC | Có | `10.0.0.0/16` |
| 3 tầng subnet | Có | Public, application, database |
| Internet Gateway | Có | Public route đã trỏ tới IGW |
| Public route table | Có | Dùng chung cho public subnets |
| Private application route table | Có | Chưa có outbound Internet |
| Database route table | Có | Đang cô lập |
| NAT Gateway | Tắt | Code đang bị comment |
| Generic Security module | Có | Có thể tái sử dụng |
| Bastion SG | Có | SSH đang mở toàn Internet |
| Bastion EC2 | Chưa có | SG không phải EC2 instance |
| ALB SG | Chưa có | Sẽ mở 80/443 từ Internet |
| Application SG | Chưa có | Sẽ nhận traffic từ ALB/Bastion SG |
| RDS SG | Chưa có | Sẽ chỉ nhận 3306 từ Application SG |
| ALB | Chưa có | Cần target group và listeners |
| Launch Template/ASG | Chưa có | Đặt trong private application subnets |
| RDS subnet group | Chưa có | Dùng private database subnet IDs |
| RDS Multi-AZ | Chưa có | Đặt `publicly_accessible = false` |
| ACM/Route 53 | Chưa có | Thực hiện sau ALB |

## 8. Những điểm nên sửa trước khi tiếp tục

### Ưu tiên cao

1. Không mở SSH `0.0.0.0/0`. Dùng IP admin `/32` hoặc cân nhắc AWS Systems Manager Session Manager.
2. Đổi key `ssh_from_bastion` của Bastion SG thành `ssh_from_admin` để đúng ý nghĩa.
3. Quyết định private application instances có cần outbound Internet hay không. Nếu cần, bật NAT hoặc thêm các VPC endpoint phù hợp.

### Nên cải thiện

1. Thêm validation `az_count >= 1 && az_count <= 10` để tránh CIDR overlap.
2. Nếu chỉ muốn standard AZ, thêm filter `zone-type = availability-zone` vào data source.
3. Thêm descriptions cho variables và outputs của VPC module.
4. Thống nhất tag `Name`, `Environment` và `ManagedBy` thay vì chỉ dùng tag `description`.
5. Đưa region, VPC CIDR, AZ count và admin CIDR thành root variables thay vì hardcode.
6. Chạy `terraform fmt -recursive` để chuẩn hóa khoảng trắng và newline trong các file hiện tại.

## 9. Quy trình chạy Terraform

Chạy từ root module:

```bash
cd Application/live/prod
terraform fmt -recursive ../..
terraform init
terraform validate
terraform plan
terraform apply
```

Trước khi apply:

- AWS credentials phải hợp lệ;
- bucket S3 backend phải tồn tại;
- kiểm tra kỹ plan, đặc biệt là CIDR, routes và Security Group rules.

Xem outputs:

```bash
terraform output
terraform output public_subnet_ids
```

Destroy:

```bash
terraform destroy
```

NAT Gateway, Load Balancer và RDS có thể mất vài phút để xóa. Không chạy nhiều lệnh Terraform đồng thời trên cùng state. Nếu lệnh bị dừng bất thường, kiểm tra state lock trước khi dùng `force-unlock`; chỉ force-unlock khi chắc chắn không còn tiến trình apply/destroy khác.

## 10. Thứ tự triển khai tiếp theo

Thứ tự hợp lý để tiếp tục project:

```text
1. Siết Bastion SG và đưa admin CIDR thành variable
2. Tạo ALB SG, Application SG và RDS SG bằng module security
3. Tạo Bastion EC2 hoặc thay bằng Session Manager
4. Tạo ALB target group và ALB
5. Tạo Launch Template và Auto Scaling Group
6. Tạo RDS DB subnet group
7. Tạo RDS MySQL Multi-AZ
8. Tạo ACM certificate
9. Tạo Route 53 record trỏ tới ALB
10. Bổ sung monitoring, logging và alarms
```

Nguyên tắc kết nối Security Group nên là:

```text
Internet --80/443--> ALB SG
Admin /32 --22----> Bastion SG
ALB SG --app port-> Application SG
Bastion SG --22---> Application SG
Application SG --3306--> RDS SG
```

Không dùng CIDR rộng khi có thể tham chiếu trực tiếp Security Group ID.
