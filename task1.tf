provider "aws" {
  region     = "ap-south-1"
  profile    = "srishtiiiii"
}

resource "aws_key_pair" "task1_key" {
  key_name   = "task1_key"
  public_key = "${file("mykey.pub")}"
}

output "keyname" {
	value = aws_key_pair.task1_key.key_name
}


resource "aws_security_group" "task1_sg" {
  name        = "task1_sg"
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "task1_sg"
  }
}

output "sgname" {
	value = aws_security_group.task1_sg.name
}

resource "aws_instance" "task1_instance" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.task1_key.key_name
  security_groups = [ aws_security_group.task1_sg.name ]

 connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/Srishti Gupta/Documents/mykey.pem")
    host     = aws_instance.task1_instance.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

  tags = {
    Name = "Task1_os"
  }
}

output "instanceAZ" {
	value = aws_instance.task1_instance.availability_zone
}

output "instanceID" {
	value = aws_instance.task1_instance.id
}

resource "aws_ebs_volume" "task1ebs" {
  availability_zone = aws_instance.task1_instance.availability_zone
  size              = 2

  tags = {
    Name = "task1_ebs_volume"
  }
}

output "ebsvolID" {
	value = aws_ebs_volume.task1ebs.id
}

resource "aws_volume_attachment" "ebs_attach" {
  device_name = "/dev/sdd"
  volume_id   = aws_ebs_volume.task1ebs.id
  instance_id = aws_instance.task1_instance.id
  force_detach = true
}

resource "null_resource" "null_remote"  {

depends_on = [
    aws_volume_attachment.ebs_attach,
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/Srishti Gupta/Documents/mykey.pem")
    host     = aws_instance.task1_instance.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdd",
      "sudo mount  /dev/xvdd  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/srishti-gupta20/cloud_task1.git /var/www/html/"
    ]
  }
}


//Creating S3 bucket8
resource "aws_s3_bucket" "firstbucket" {
  bucket = "first-task-bucket"
  acl    = "public-read"
  force_destroy = "true"

  tags = {
    Name = "First Task bucket"
  }
}

//Downloading content from Github
resource "null_resource" "local1"  {
	depends_on = [aws_s3_bucket.firstbucket,]
	provisioner "local-exec" {
		command = "git clone https://github.com/srishti-gupta20/cloud_task1.git"
  	}
	
}


// Uploading file to bucket
resource "aws_s3_bucket_object" "upload_images" {
	depends_on = [aws_s3_bucket.firstbucket , null_resource.local1]
	bucket = aws_s3_bucket.firstbucket.id
        key = "lotus_temple.jpg"    
	source = "cloud_task1/lotus_temple.jpg"
	content_type = "image/jpeg"
        acl = "public-read"
}

//output "Image" {
//  value = aws_s3_bucket_object.upload_images
//}


locals {
  s3_origin_id = "myS3Origin"
}

//creating cloudfront distribution
resource "aws_cloudfront_distribution" "task1_distribution" {
  depends_on = [aws_s3_bucket.firstbucket, null_resource.local1 ]
  origin {
    domain_name = aws_s3_bucket.firstbucket.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
  }

  enabled             = true
//  default_root_object = "index.html"

//  logging_config {
//    bucket          = "mylogs.s3.amazonaws.com"
//  }

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
 }

  price_class = "PriceClass_All"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/Srishti Gupta/Documents/mykey.pem")
    host     = aws_instance.task1_instance.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo su <<EOF",
      "sudo sed -i '5i <img src='http://${aws_cloudfront_distribution.task1_distribution.domain_name}/${aws_s3_bucket_object.upload_images.key}' width='800' height='600' />' /var/www/html/index.html",
      "EOF"
    ]
  }
}

output "cloudfront" {
	value = aws_cloudfront_distribution.task1_distribution.domain_name
}

resource "null_resource" "nulllocalchrome"  {
    depends_on = [
        aws_cloudfront_distribution.task1_distribution,
    ]
	provisioner "local-exec" {
	    command = "chrome  ${aws_instance.task1_instance.public_ip}"
  	}
}
