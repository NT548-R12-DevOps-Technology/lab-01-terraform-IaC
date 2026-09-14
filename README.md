# NT548 Lab 01 — Hạ tầng AWS bằng IaC

## 1. Lab Overview

Lab triển khai một VPC, hai subnet trong cùng một Availability Zone (AZ), Internet Gateway, NAT Gateway với Elastic IP, hai route table, hai nhóm EC2 public/private và hai Security Group. Mặc định mỗi nhóm có một EC2. Mục tiêu là thực hành Infrastructure as Code, module tái sử dụng, định tuyến public/private và truy cập SSH qua bastion.

Thư mục `terraform/` chỉ tổ chức mã nguồn, không phải root module và không chứa cấu hình `.tf` ở cấp thư mục này.

<details>
<summary>Ấn để xem mục lục</summary>

- [1. Lab Overview](#1-lab-overview)
- [2. Architecture](#2-architecture)
  - [2.1. Components](#21-components)
  - [2.2. Architecture Diagram](#22-architecture-diagram)
  - [2.3. Module Explanation](#23-module-explanation)
  - [2.4. NAT Gateway](#24-nat-gateway)
  - [2.5. Route Tables](#25-route-tables)
  - [2.6. Security](#26-security)
- [3. Preparation](#3-preparation)
  - [3.1. Prerequisites](#31-prerequisites)
  - [3.2. AWS Authentication](#32-aws-authentication)
  - [3.3. AMI](#33-ami)
  - [3.4. Public IP](#34-public-ip)
  - [3.5. EC2 Key Pair](#35-ec2-key-pair)
- [4. Deployment](#4-deployment)
  - [4.1. Configuration](#41-configuration)
  - [4.2. Deployment Commands](#42-deployment-commands)
  - [4.3. Outputs](#43-outputs)
  - [4.4. Terraform State](#44-terraform-state)
- [5. Access and Verification](#5-access-and-verification)
  - [5.1. SSH to Public EC2](#51-ssh-to-public-ec2)
  - [5.2. SSH to Private EC2](#52-ssh-to-private-ec2)
  - [5.3. Test Cases / Kiểm thử sau triển khai](#53-test-cases--kiểm-thử-sau-triển-khai)
  - [5.4. Kết quả kiểm thử kết nối](#54-kết-quả-kiểm-thử-kết-nối)
- [6. Cleanup](#6-cleanup)

</details>

## 2. Architecture

### 2.1. Components

| Thành phần | Cấu hình mặc định và vai trò |
| --- | --- |
| VPC | `10.0.0.0/16`, bật DNS support và DNS hostnames |
| Availability Zone | `ap-southeast-1a` cho cả hai subnet |
| Internet Gateway (IGW) | Gắn vào VPC, phục vụ kết nối Internet cho tài nguyên có public IPv4 và route phù hợp |
| Public Subnet | `10.0.1.0/24`, bật tự cấp public IPv4; chứa bastion và NAT Gateway |
| Private Subnet | `10.0.2.0/24`, tắt tự cấp public IPv4; chứa private EC2 |
| Public Route Table | Default route `0.0.0.0/0 -> IGW`, associate với public subnet |
| Private Route Table | Default route `0.0.0.0/0 -> NAT Gateway`, associate với private subnet |
| NAT Gateway | Nằm trong public subnet, dùng một Elastic IP để private EC2 kết nối ra Internet |
| Public EC2 | Bastion có public IPv4; chỉ nhận SSH từ `allowed_ssh_cidr` |
| Private EC2 | Chỉ có private IPv4; nhận SSH từ Public EC2 Security Group |
| Security Groups | Hai group riêng, chỉ mở inbound TCP 22 theo nguồn tương ứng; cho phép mọi outbound IPv4 |

Public EC2 là điểm trung chuyển SSH. Private EC2 không có địa chỉ public và không có đường truy cập trực tiếp từ Internet. NAT chỉ phục vụ kết nối do phía private khởi tạo và lưu lượng trả về. Xem [tài liệu NAT Gateway của AWS](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html).

### 2.2. Architecture Diagram

![Sơ đồ kiến trúc AWS của Lab 01](pictures/diagram.png)

### 2.3. Module Explanation

| Module | Input chính | Tài nguyên và output chính |
| --- | --- | --- |
| `vpc` | `vpc_cidr` | VPC có DNS; xuất `vpc_id` |
| `networking` | `vpc_id`, hai subnet CIDR, AZ | Subnets, IGW, EIP, NAT, route tables và associations; xuất ID subnet/gateway/route table, IP NAT |
| `security` | `vpc_id`, `allowed_ssh_cidr` | Hai Security Group và bốn rule; xuất `public_sg_id`, `private_sg_id` |
| `ec2` | ID subnet/SG, số lượng public/private, AMI, instance type và public key | Đăng ký EC2 Key Pair, tạo EC2 public/private; xuất danh sách instance ID và IP |

Mọi module nhận `name_prefix` và `tags`. Root tạo prefix `${project_name}-${environment}` cùng các tag `Project`, `Environment`, `ManagedBy = "Terraform"`; từng resource được thêm `Name`. Route table association không hỗ trợ tag.

Tham chiếu `module.vpc.vpc_id` tạo phụ thuộc cho networking/security; EC2 phụ thuộc subnet và SG qua output của các module đó. Networking và security có thể được Terraform tạo song song sau VPC. Chỉ NAT có `depends_on` tường minh với IGW, vì NAT cần IGW gắn vào VPC nhưng không có thuộc tính tham chiếu IGW trực tiếp. Cách khai báo này theo [tài liệu AWS provider về NAT Gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway).

AWS tự tạo default Security Group cho VPC. Lab không tạo bản sao; cả hai EC2 đều được gắn Security Group riêng của module `security`.

### 2.4. NAT Gateway

Đường đi của kết nối Internet do private EC2 khởi tạo:

```text
Private EC2 → Private Route Table → NAT Gateway (Public Subnet)
            → Public Route Table → Internet Gateway → Internet
```

NAT dùng Elastic IP làm địa chỉ nguồn public. Private EC2 vẫn chỉ có private IPv4; máy trên Internet không thể dùng EIP NAT để khởi tạo SSH vào private EC2. NAT Gateway không cần và không được gắn Security Group. Kiểm soát inbound EC2 bằng hai SG chuyên biệt.

### 2.5. Route Tables

| Route table | Destination | Target | Association |
| --- | --- | --- | --- |
| Public | `0.0.0.0/0` | Internet Gateway | Public Subnet |
| Private | `0.0.0.0/0` | NAT Gateway | Private Subnet |
| Cả hai | CIDR VPC | `local` do AWS tự tạo | Cho phép định tuyến giữa các IP trong VPC |

SSH từ bastion đến private EC2 đi qua route `local`, không đi qua NAT. Route cho phép định tuyến nhưng traffic vẫn phải qua Security Group. NAT nằm trong public subnet nên dùng public route table để ra IGW.

### 2.6. Security

| Đích | Inbound | Nguồn |
| --- | --- | --- |
| Public EC2 | TCP 22 | `allowed_ssh_cidr`, khuyến nghị IP cá nhân `/32` |
| Private EC2 | TCP 22 | **ID Public EC2 Security Group** |

Không mở inbound HTTP, HTTPS, ICMP hay port khác. Cả hai group cho phép mọi outbound IPv4 theo đề bài. Rule private SSH dùng `referenced_security_group_id`, không dùng CIDR public subnet. Nếu sau này gắn Public SG cho máy khác trong VPC, máy đó cũng được cấp quyền SSH đến private EC2; giữ SG này dành cho bastion.

Rule dùng resource `aws_vpc_security_group_ingress_rule`/`aws_vpc_security_group_egress_rule` riêng theo [hướng dẫn AWS provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule). Private subnet tắt tự cấp public IPv4 và private EC2 đặt `associate_public_ip_address = false`. Không triển khai IPv6.

Cả hai EC2 bắt buộc IMDSv2, giới hạn metadata response hop bằng 1 và mã hóa EBS root volume kiểu `gp3`; dung lượng lấy theo AMI. Root volume được xóa khi terminate instance. Không tạo private key hay credentials bằng Terraform. `.gitignore` loại state, plan, tfvars, cache và key; giữ example và provider lock file. State/plan vẫn cần được bảo vệ trên máy cá nhân.

## 3. Preparation

### 3.1. Prerequisites

<details>
<summary>Ấn để xem điều kiện tiên quyết</summary>

- Terraform **>= 1.5.0**; provider `hashicorp/aws` **6.x** được khóa phiên bản bằng lock file.
- AWS CLI v2 và tài khoản AWS có quyền tạo/quản lý VPC, subnet, gateway, EIP, route table, Security Group, EC2 và tag; có quyền dùng EBS encryption.
- AWS credentials hợp lệ qua profile, environment hoặc IAM role; quyền đọc SSM parameter nếu lấy AMI theo lệnh bên dưới.
- SSH key tự tạo tại `key_pair/`; Terraform đăng ký public key vào Region triển khai, còn private key luôn nằm trên máy cá nhân.
- AMI Linux có SSH, EBS root volume và hỗ trợ IMDSv2. Với `t3.micro`, chọn kiến trúc **x86_64**, ví dụ Amazon Linux 2023 hoặc Ubuntu Server.
- OpenSSH client; `curl` để lấy public IP và kiểm tra egress. Tài khoản còn quota cho EC2, EIP, NAT Gateway và VPC.

Một AZ phù hợp bài lab, không cung cấp tính sẵn sàng cao khi AZ gặp sự cố. AMI, Key Pair và AZ phải thuộc Region đã chọn; khi đổi CIDR, hai subnet phải nằm trong VPC và không chồng lấn. Validation kiểm tra cú pháp/prefix CIDR; không kiểm tra mọi quan hệ mạng hay sự tồn tại của tài nguyên AWS trước khi triển khai.

</details>

### 3.2. AWS Authentication

Terraform dùng AWS credential chain: profile AWS CLI, biến môi trường AWS hoặc IAM role của môi trường chạy. Không đặt access key/secret key trong `.tf` hay `.tfvars`.

Ví dụ với profile SSO đã được cấu hình:

```bash
aws sso login --profile lab
export AWS_PROFILE=lab
aws sts get-caller-identity
```

Nếu phòng lab cung cấp access key, cấu hình bằng `aws configure --profile lab` trên máy cá nhân rồi chọn `AWS_PROFILE=lab`. Với credentials tạm thời, cần session token theo cơ chế cấp credentials của phòng lab. Không đưa thư mục credentials hoặc nội dung credentials vào repo hay ảnh chụp báo cáo. Chi tiết: [AWS provider authentication](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication-and-configuration).

### 3.3. AMI

AMI ID khác nhau theo Region và thay đổi theo bản phát hành. Có thể chọn Amazon Linux 2023/Ubuntu từ EC2 Console tại **Asia Pacific (Singapore)**, xem AMI ID và kiến trúc mà không khởi tạo instance thủ công.

Hoặc lấy AMI Amazon Linux 2023 x86_64 hiện hành bằng lệnh chỉ đọc:

```bash
aws ssm get-parameter \
  --region ap-southeast-1 \
  --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query 'Parameter.Value' \
  --output text
```

Chép kết quả vào `ami_id`. Hai EC2 dùng chung AMI. AMI này dùng SSH username `ec2-user`; Ubuntu dùng `ubuntu`. Cách tra cứu SSM được mô tả trong [tài liệu Amazon Linux 2023](https://docs.aws.amazon.com/linux/al2023/ug/ec2.html).

### 3.4. Public IP

Trên máy sẽ thực hiện SSH, lấy địa chỉ IPv4 đi ra Internet:

```bash
curl -4 --fail --silent --show-error https://checkip.amazonaws.com
```

Đặt `allowed_ssh_cidr = "x.x.x.x/32"` với IP vừa nhận. `203.0.113.10/32` chỉ minh họa cú pháp, không phải IP truy cập được. Nếu đổi mạng/VPN hoặc ISP đổi IP, cập nhật biến và xem lại plan trước khi apply. Không dùng IP LAN như `192.168.x.x`. Biến này bắt buộc nhập và từ chối mọi IPv4 CIDR `/0`.

### 3.5. EC2 Key Pair

Tự tạo SSH key trên máy cá nhân tại `key_pair/`. Terraform đọc file public key và tạo EC2 Key Pair tên `lab_key`; bạn không cần tạo key trước trên AWS hoặc chạy `aws ec2 import-key-pair` thủ công. Private key luôn ở máy cá nhân, không được Terraform đọc, upload hay lưu trong state.

**Tạo key thủ công** — chạy từ thư mục gốc của lab:

```bash
mkdir -p key_pair
chmod 700 key_pair
ssh-keygen -t rsa -b 4096 -C "lab_key" -f key_pair/lab_key
chmod 400 key_pair/lab_key
```

Nhập passphrase khi `ssh-keygen` yêu cầu để bảo vệ private key. Nếu file đã tồn tại, không xác nhận ghi đè key đang sử dụng; chọn tên khác khi cần tạo một cặp mới.

- `key_pair/lab_key`: private key dùng để SSH; không upload lên AWS và không copy lên bastion.
- `key_pair/lab_key.pub`: public key được Terraform đọc và đăng ký vào EC2.

Thư mục `key_pair/` được bỏ qua trong `.gitignore`, nên cả key không có phần mở rộng cũng được loại khỏi Git.

Giữ cấu hình sau trong `terraform/environments/dev/terraform.tfvars`:

```hcl
key_name        = "lab_key"
public_key_path = "key_pair/lab_key.pub"
```

`public_key_path` được tính từ thư mục gốc của lab. Resource `aws_key_pair` trong module EC2 đăng ký nội dung `.pub` với tên `lab_key`, sau đó hai loại EC2 cùng tham chiếu key đó. File public key phải tồn tại trước khi chạy `terraform plan`. Nếu AWS đã có Key Pair trùng tên nhưng không nằm trong state của lab, đổi tên hoặc xóa key cũ sau khi chắc chắn không còn dùng.

## 4. Deployment

### 4.1. Configuration

Từ thư mục repository, chuyển vào root module, tạo bản cấu hình cá nhân:

```bash
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
```

Mở `terraform.tfvars` và thay **hai** placeholder trước `plan`/`apply`:

| Biến | Giá trị cần điền |
| --- | --- |
| `ami_id` | AMI Linux hợp lệ trong Region, đúng kiến trúc instance type |
| `allowed_ssh_cidr` | Public IPv4 hiện tại của bạn kèm `/32` |

Các biến có mặc định và có thể chỉnh:

| Biến | Mặc định |
| --- | --- |
| `aws_region` | `ap-southeast-1` |
| `project_name` | `terraform-aws-lab` |
| `environment` | `dev` |
| `vpc_cidr` | `10.0.0.0/16` |
| `public_subnet_cidr` | `10.0.1.0/24` |
| `private_subnet_cidr` | `10.0.2.0/24` |
| `availability_zone` | `ap-southeast-1a` |
| `instance_type` | `t3.micro` |
| `public_instance_count` | `1` |
| `private_instance_count` | `1` |
| `key_name` | `lab_key` |
| `public_key_path` | `key_pair/lab_key.pub` |

`dev/main.tf` truyền hai biến số lượng vào module EC2 cùng subnet tương ứng. Ví dụ đặt `public_instance_count = 1`, `private_instance_count = 2` trong `terraform.tfvars` để tạo một bastion và hai private EC2. Số lượng phải là số nguyên không âm; `0` tạo danh sách EC2 rỗng cho loại đó, nhưng các tài nguyên mạng vẫn được tạo. Cần ít nhất một public EC2 để SSH vào private EC2 theo kiến trúc lab. Tên EC2/root volume có hậu tố `-1`, `-2`, ...; mỗi loại dùng chung subnet và SG.

Không commit file `terraform.tfvars`; file example cố ý chứa placeholder để buộc người dùng cấu hình trước khi chạy.

### 4.2. Deployment Commands

Tạo backend trước, sau đó mới triển khai environment `dev`. Backend gồm S3 lưu Terraform state và DynamoDB lock state; cả hai được tạo một lần bằng root module `terraform/bootstrap/`.

**Bước 1 — tạo backend.** Chạy từ thư mục gốc của lab:

```bash
cd terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars
```

`state_bucket_name` là tên S3 bucket **bạn tự đặt**; bootstrap sẽ tạo bucket đó, không phải lấy từ output có sẵn. Tên phải viết thường và duy nhất trên toàn AWS. Có thể tạo một tên gợi ý bằng account ID và ngày hiện tại:

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "lab-01-terraform-state-${ACCOUNT_ID}-$(date +%Y%m%d)"
```

Chép kết quả vào `state_bucket_name` trong `terraform.tfvars`, rồi chạy:

```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

**Bước 2 — cấu hình và triển khai `dev`.** Từ thư mục gốc của lab, tạo các file cấu hình cá nhân từ file mẫu:

```bash
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
cp backend.hcl.example backend.hcl
# Tạo key theo mục 3.5.
```

Sau đó điền `ami_id` và `allowed_ssh_cidr` trong `terraform.tfvars`; điền tên S3 bucket/DynamoDB table lấy từ output bước 1 vào `backend.hcl`. Tiếp tục:

```bash
terraform init -reconfigure -backend-config=backend.hcl
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

`init` tải provider/module, cấu hình backend và tạo lock file. `validate` kiểm tra cấu hình/module/provider schema mà không tạo AWS resource. `plan` cần credentials và giá trị AWS phù hợp; xem kỹ tài nguyên sẽ tạo/thay đổi. `apply` sẽ hiển thị plan và yêu cầu xác nhận trước khi tạo tài nguyên; không dùng `-auto-approve` cho bài lab.

`terraform fmt -recursive` tại `dev` chỉ duyệt thư mục `dev`. Khi sửa module, format toàn bộ module bằng lệnh sau, vẫn đứng tại `dev`:

```bash
terraform fmt -recursive ../../modules
terraform fmt -check -recursive
terraform fmt -check -recursive ../../modules
```

### 4.3. Outputs

Sau apply, root xuất:

| Nhóm | Outputs |
| --- | --- |
| Network | `vpc_id`<br>`public_subnet_id`<br>`private_subnet_id`<br>`internet_gateway_id`<br>`nat_gateway_id`<br>`nat_gateway_public_ip`<br>`public_route_table_id`<br>`private_route_table_id` |
| Security | `public_sg_id`<br>`private_sg_id` |
| EC2 | `public_instance_id`<br>`public_instance_public_ip`<br>`public_instance_private_ip`<br>`private_instance_id`<br>`private_instance_private_ip` |

Năm output EC2 giữ nguyên tên nhưng trả về **danh sách** theo thứ tự `count.index`, kể cả khi số lượng là `1`; số lượng `0` trả về `[]`. Xem bằng `terraform output` hoặc `terraform output -json public_instance_public_ip`. Các output network/SG vẫn là chuỗi. Hai block `moved` chuyển địa chỉ EC2 cũ sang phần tử `[0]` khi áp dụng cấu hình mới lên state đã có. Không output credentials hay SSH private key. Public IPv4 của bastion là địa chỉ được AWS tự cấp, có thể đổi sau stop/start hoặc thay instance; khi đó lấy lại output bằng refresh-only plan/apply sau khi kiểm tra thay đổi.

### 4.4. Terraform State

Lab 01 chạy Terraform thủ công trên máy cục bộ nhưng dùng S3 remote backend để lưu state và DynamoDB để lock state. Không có GitHub Actions hay IAM OIDC trong bài lab này.

Sau khi apply `terraform/bootstrap/`, lấy hai output bằng lệnh:

```bash
terraform -chdir=terraform/bootstrap output
```

Chép `state_bucket_name` vào `bucket` và `lock_table_name` vào `dynamodb_table` trong `terraform/environments/dev/backend.hcl`. File này chỉ là cấu hình backend; không ghi AWS credentials vào đó.

State ghi nhận các tài nguyên AWS Terraform đang quản lý. Không sửa hoặc xóa state thủ công khi hạ tầng còn tồn tại. `.gitignore` đã loại state, plan, `backend.hcl`, `terraform.tfvars` và thư mục `.terraform/` khỏi Git.

Khi muốn xóa hạ tầng, chạy `terraform destroy` tại `terraform/environments/dev/` trước. Chỉ xóa S3 bucket và DynamoDB table bằng `terraform destroy` tại `terraform/bootstrap/` sau khi environment `dev` đã bị xóa.

## 5. Access and Verification

### 5.1. SSH tới Public EC2

Chờ EC2 hoàn tất khởi động. Lab dùng Amazon Linux 2023:

```bash
ssh -i key_pair/lab_key ec2-user@<PUBLIC_IP>
```

Thay `<PUBLIC_IP>` bằng một phần tử trong `public_instance_public_ip`. Máy kết nối phải đi ra Internet bằng IP thuộc `allowed_ssh_cidr`. Cần cài `jq` nếu dùng lệnh nhanh dưới đây. Giữ kiểm tra SSH host key; khi gặp host key mới, đối chiếu fingerprint qua kênh AWS tin cậy trước khi chấp nhận.

Hoặc dùng lệnh nhanh kết hợp Terraform output, chạy từ thư mục gốc `lab-01/`:

```bash
ssh -i key_pair/lab_key \
  "ec2-user@$(terraform -chdir=terraform/environments/dev output -json public_instance_public_ip | jq -r '.[0]')"
```

### 5.2. SSH tới Private EC2

Private EC2 chỉ có IP nội bộ. Dùng **ProxyJump** để máy cá nhân mở kết nối SSH đến bastion, rồi bastion mở TCP tới cổng 22 của private EC2. Private key vẫn trên máy cá nhân, dùng để xác thực đến từng host; không cần copy key lên bastion hay bật agent forwarding.

Chạy các lệnh sau từ thư mục gốc `lab-01/`. Nạp key vào SSH agent cục bộ để `-J` xác thực được với Bastion; key không được chuyển lên Bastion.

```bash
eval "$(ssh-agent -s)"
ssh-add key_pair/lab_key
```

Sau đó kết nối bằng ProxyJump:

```bash
ssh -i key_pair/lab_key \
  -J ec2-user@<PUBLIC_IP> \
  ec2-user@<PRIVATE_IP>
```

Hoặc dùng lệnh nhanh kết hợp Terraform output. Hai lệnh `terraform output` lồng trong lệnh SSH tự lấy public IP của Bastion và private IP của Private EC2:

```bash
ssh -i key_pair/lab_key \
  -J "ec2-user@$(terraform -chdir=terraform/environments/dev output -json public_instance_public_ip | jq -r '.[0]')" \
  "ec2-user@$(terraform -chdir=terraform/environments/dev output -json private_instance_private_ip | jq -r '.[0]')"
```

Khi hoàn tất, có thể dừng SSH agent bằng `ssh-agent -k`.

Amazon Linux 2023 dùng `ec2-user` ở cả hai host. Cơ chế ProxyJump: [OpenSSH ssh_config](https://man.openbsd.org/ssh_config#ProxyJump).

### 5.3. Test Cases / Kiểm thử sau triển khai

Test case dùng chung nằm trong [`testcases/`](testcases/). Runner [`validate_aws_cli.sh`](testcases/validate_aws_cli.sh) chỉ gọi AWS CLI, tìm tài nguyên qua tag `Project`, `Environment` và `Name`; không đọc Terraform state hay gọi `terraform output`. Vì vậy CloudFormation có thể tái sử dụng script khi áp dụng cùng quy ước tag và tên tài nguyên.

Terraform và CloudFormation cần giữ các tag và quy ước tên sau để cùng dùng bộ test:

| Tag | Ví dụ |
| --- | --- |
| `Project` | `terraform-aws-lab` |
| `Environment` | `dev` |
| `Name` | `<project>-<environment>-<resource>` |

Sao chép file môi trường mẫu rồi thay `LAB_ALLOWED_SSH_CIDR` bằng public IP hiện tại của bạn ở dạng `/32`:

```bash
cp testcases/.env.example testcases/.env
bash testcases/validate_aws_cli.sh
```

`testcases/.env` được Git ignore và chỉ chứa cấu hình kiểm thử, không chứa AWS credentials:

| Variable | Vai trò |
| --- | --- |
| `LAB_AWS_REGION` | AWS Region chứa tài nguyên lab |
| `LAB_PROJECT_NAME` | Giá trị tag `Project` |
| `LAB_ENVIRONMENT` | Giá trị tag `Environment` |
| `LAB_ALLOWED_SSH_CIDR` | CIDR SSH duy nhất được phép vào Public Security Group |

Runner source các file trong `testcases/tests/` và dùng helper chung tại `testcases/lib/common.sh`. Script cần AWS CLI v2 credentials hợp lệ, quyền chỉ đọc EC2/VPC và `jq`. Kết quả in từng test dưới dạng `PASS` hoặc `FAIL`, và trả về exit code `1` nếu có kiểm tra thất bại. Có thể tạm thời ghi đè biến bằng tham số CLI, ví dụ `--allowed-ssh-cidr 203.0.113.10/32`.

| File | Test case | Kiểm tra bằng AWS CLI |
| --- | --- | --- |
| `test_01_vpc_igw.sh` | Test 01 | VPC ở trạng thái `available`; Internet Gateway gắn vào VPC |
| `test_02_vpc_dns.sh` | Test 02 | VPC bật DNS support và DNS hostnames |
| `test_03_subnets.sh` | Test 03 | Public/private subnet có cấu hình public IPv4 đúng |
| `test_04_nat_gateway.sh` | Test 04 | NAT Gateway `available`, ở Public Subnet và có Elastic IP |
| `test_05_route_tables.sh` | Test 05 | Public route table: `0.0.0.0/0 → Internet Gateway`<br>Private route table: `0.0.0.0/0 → NAT Gateway` |
| `test_06_security_groups.sh` | Test 06 | Public SG chỉ cho phép SSH từ `allowed_ssh_cidr`<br>Private SG cho phép SSH từ Public EC2 SG |
| `test_07_ec2.sh` | Test 07 | Public EC2 có public IPv4/Public SG<br>Private EC2 không có public IPv4/Private SG |

Kiểm thử SSH vào Bastion và Private EC2 thực hiện theo mục 5.1 và 5.2. Lưu kết quả `PASS`/`FAIL` và ảnh AWS Console/CLI cho báo cáo; không ghi PASS cho test chưa chạy trên AWS.

### 5.4. Kết quả kiểm thử kết nối

Sau khi triển khai, kiểm tra kết nối từ Bastion/Public EC2 đến Private EC2 cho kết quả như sau:

| Kiểm thử | Kết quả | Đánh giá |
| --- | --- | --- |
| ICMP từ Bastion đến Private EC2 | Bị chặn | **PASS** — Private Security Group chỉ cho phép inbound TCP 22, nên ICMP bị chặn đúng thiết kế. |
| TCP 22 từ Bastion đến Private EC2 | Kết nối thành công | **PASS** — Bastion kết nối được SSH port của Private EC2. |

Kết quả TCP 22 xác nhận route nội bộ VPC và rule inbound của Private Security Group hoạt động. Ping thất bại không phải lỗi kết nối; đây là kết quả mong đợi khi không mở ICMP trong Security Group.

## 6. Cleanup

**Bước 1 — xóa environment `dev`.** Đứng tại `terraform/environments/dev/`, với đúng credentials và file biến đã dùng:

```bash
terraform destroy
```

Xem kế hoạch hủy và xác nhận khi không còn cần tài nguyên. NAT Gateway, Elastic IP/public IPv4, EC2 và EBS có thể phát sinh chi phí; nên destroy sau bài lab. Chi phí phụ thuộc Region, thời gian sử dụng và lưu lượng; xem [AWS VPC pricing](https://aws.amazon.com/vpc/pricing/).

Đợi destroy hoàn tất, kiểm tra EC2/NAT/EIP trong Console. Không xóa state trước destroy; mất state sẽ làm Terraform mất thông tin tài nguyên cần dọn. EC2 Key Pair `lab_key` do Terraform quản lý sẽ bị xóa khỏi AWS, nhưng hai file trong `key_pair/` trên máy vẫn được giữ lại. Dữ liệu trên EC2 root volume sẽ bị xóa khi hủy instance.

**Bước 2 — xóa backend.** S3 bucket dùng versioning nên phải xóa các version state và delete marker trước khi Terraform có thể xóa bucket. Chạy từ thư mục gốc của lab:

```bash
cd terraform/bootstrap
STATE_BUCKET_NAME=$(terraform output -raw state_bucket_name)

aws s3api list-object-versions \
  --bucket "$STATE_BUCKET_NAME" \
  --output json \
| jq '{
    Objects: (
      ((.Versions // []) + (.DeleteMarkers // []))
      | map({Key: .Key, VersionId: .VersionId})
    ),
    Quiet: true
  }' > /tmp/lab-01-state-objects.json

aws s3api delete-objects \
  --bucket "$STATE_BUCKET_NAME" \
  --delete file:///tmp/lab-01-state-objects.json

terraform destroy
rm -f /tmp/lab-01-state-objects.json
```

Lệnh cuối xóa S3 state bucket và DynamoDB lock table. Chỉ thực hiện bước này khi đã xóa `dev` và không còn cần dùng state của lab.
