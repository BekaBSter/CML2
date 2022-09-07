
variable "token" {
  default = "y0_AgAAAAARkP_kAATuwQAAAADNFW9YmbQqno9-Q0SjNvOV0Lj0mipyfRc" //указывается OAuth токен от yandex cloud
  description = "token"
}

variable "cloud_id" {
  default = "b1gnse9j6a5srleskpo2" //указывается идентификатор облака
  description = "cloud_id"
}

variable "folder_id" {
  default = "b1g9s9qgppg72trf7j4f" //указывается идентификатор рабочего каталога
  description = "folder_id"
}

variable "zone" {
  default = "ru-central1-a"
  description = "zone"
}
