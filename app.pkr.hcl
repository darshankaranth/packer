packer {
  required_plugins {
    amazon = {
      version = ">= 0.0.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "app" {
  ami_name                  = "app-${var.app_release_version}-${var.git_sha}"
  ami_description           = "app image"
  iam_instance_profile      = "PackerRole"
  instance_type             = "t2.micro"
  region                    = "us-west-1"
  skip_create_ami           = "${var.skip_image}"
  ssh_clear_authorized_keys = true
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-20210223"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = [""]
  }
  ssh_username = "ubuntu"
}

source "azure-arm" "app" {
  image_publisher = "canonical"
  image_offer     = "0001-com-ubuntu-server-focal"
  image_sku       = "20_04-lts"
  os_type         = "Linux"

  subscription_id           = ""
  client_id                 = "${var.azure_client_id}"
  client_secret             = "${var.azure_client_secret}"
  tenant_id                 = "${var.azure_tenant_id}"
  ssh_clear_authorized_keys = true
  ssh_username = "${var.ssh_user}"
  shared_image_gallery_destination {
    subscription   = ""
    resource_group = "PackerResourceGroup"
    gallery_name   = "PackerImageGallery"
    image_name     = "appImage"
    
    replication_regions = [""]
    image_version  = "1.0.0"
  }
  build_resource_group_name         = "appImage"
  managed_image_resource_group_name = "PackerResourceGroup"
  managed_image_name                = "app-${var.app_release_version}-${var.git_sha}"
  vm_size                           = "Standard_A4_v2"
  azure_tags = {
    "builder" : "packer",
    "git_sha" : "${var.git_sha}",
    "release" : "${var.app_release_version}",
  }
}


build {
  name = "app-builder"
  sources = [
    "source.amazon-ebs.app",
    "sources.azure-arm.app"
  ]

  # Install and update necessary packages
  provisioner "shell" {
    execute_command = "echo '${var.ssh_password}' | {{.Vars}} sudo -S -E bash '{{.Path}}'"
    inline = [
	  "mkdir /opt/app/"
      "sudo apt-get update",
      "sudo apt-get install chrony -y"
    ]
  }

  # Install pre-req packages
  provisioner "shell" {
    execute_command = "echo '${var.ssh_password}' | {{.Vars}} sudo -S -E bash '{{.Path}}'"
    script          = "../app/pre_req.sh"
  }

  # Add default appuser user and adds sudo group. 
  provisioner "shell" {
    execute_command = "echo '${var.ssh_password}' | {{.Vars}} sudo -S -E bash '{{.Path}}'"
    inline = [
      "useradd  -d /home/appuser -m -s /bin/bash appuser -G sudo",
      "passwd -l appuser",
    ]
  }


  provisioner "file" {
    source      = "../cloud-init/aws/user-data"
    destination = "/tmp/defaults.cfg"

  }

  # replace the default ubuntu account with appuser
  provisioner "shell" {
    execute_command = "echo '${var.ssh_password}' | {{.Vars}} sudo -S -E bash '{{.Path}}'"
    inline = [
      "mv /tmp/defaults.cfg /etc/cloud/cloud.cfg.d/defaults.cfg"
    ]
  }

  # Copy default sshd config file
  provisioner "file" {
    source      = "../app/sshd_config"
    destination = "/tmp/sshd_config"
  }


  # Configure ssh settings
  provisioner "shell" {
    execute_command = "echo '${var.ssh_password}' | {{.Vars}} sudo -S -E bash '{{.Path}}'"
    inline = [
      "mv /tmp/sshd_config /etc/ssh/sshd_config",
      "systemctl restart sshd.service",
    ]
  }

  #Download and install appstack executable
  provisioner "shell" {
    execute_command = "echo '${var.ssh_password}' | {{.Vars}} sudo -S -E bash '{{.Path}}'"
    inline = [
      "wget ${var.appstack_pkg_url} --auth-no-challenge --http-user=${var.appstack_user} --http-password='${var.appstack_pass}'  --secure-protocol=TLSv1",
      "dpkg -i appstack-${var.appstack_version}.deb",
      "rm -rf appstack-${var.appstack_version}.deb"
    ]
  }


  #Copy app release package
  provisioner "file" {
    source      = "../download/app-${var.app_release_version}-ubuntu2004-amd64.deb"
    destination = "/tmp/app-${var.app_release_version}-ubuntu2004-amd64.deb"
  }

  #Run CIS hardening script
  provisioner "ansible" {
    playbook_file = "../ansible/run.yml"
    extra_arguments = [
      "-t", "level_1_server",
      "-t", "level_2_server",
      "-e", "ansible_become_password=${var.ssh_password}",
    ]
    user = "${var.ssh_user}"
  }

}