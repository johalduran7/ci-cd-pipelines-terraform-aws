# Create a KMS Key
resource "aws_kms_key" "my_kms_key" {
  description              = "My KMS Key for encryption"
  key_usage                = "ENCRYPT_DECRYPT"   # Default is ENCRYPT_DECRYPT (for symmetric keys)
  customer_master_key_spec = "SYMMETRIC_DEFAULT" # This is the default for symmetric keys
  deletion_window_in_days  = 7                   # This is the time before the key is deleted if scheduled for deletion

  tags = {
    Name        = "MyKMSKey"
    Environment = "Dev"
    Terraform   = "yes"
  }
}



# Optional Alias for the KMS Key
resource "aws_kms_alias" "my_kms_alias" {
  name          = "alias/my-key-alias" # Alias must begin with 'alias/'
  target_key_id = aws_kms_key.my_kms_key.id
}

# Output the KMS Key ID
output "kms_key_id" {
  description = "The KMS Key ID"
  value       = aws_kms_key.my_kms_key.id
}


# # 1) encryption
# aws kms encrypt --key-id alias/my-key-alias --plaintext fileb://modules/kms/ExampleSecretFile.txt --output text --query CiphertextBlob  --region us-east-1 > modules/kms/ExampleSecretFileEncrypted.base64

# # base64 decode for Linux or Mac OS -- it decodes a binary file
# cat modules/kms/ExampleSecretFileEncrypted.base64| base64 --decode > modules/kms/ExampleSecretFileEncrypted


# # 2) decryption

# aws kms decrypt --ciphertext-blob fileb://modules/kms/ExampleSecretFileEncrypted  --output text --query Plaintext > modules/kms/ExampleFileDecrypted.base64  --region us-east-1

# # base64 decode for Linux or Mac OS 
# cat modules/kms/ExampleFileDecrypted.base64 | base64 --decode > modules/kms/ExampleFileDecrypted.txt

