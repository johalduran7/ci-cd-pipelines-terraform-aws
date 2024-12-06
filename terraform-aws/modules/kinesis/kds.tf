# This module creates a Data Stream and the necessary commands as outputs so you can interact as consumer or producer, this is very low level, ideally, you should use Kinesis Client Library KCL 

# Kinesis Data Stream
resource "aws_kinesis_stream" "kds_stream" {
  name             = "kds-stream"
  shard_count      = 1
  retention_period = 24 # Retention period in hours (default: 24)

  tags = {
    Environment = "dev"
    Team        = "data-team"
    Terraform   = "yes"
    Kinesis     = "Kinesis Data Stream"
  }
}

# Local Execution to Fetch Shard Iterator
resource "null_resource" "fetch_shard_iterator" {
  provisioner "local-exec" {
    command = <<EOT
      aws kinesis describe-stream --stream-name ${aws_kinesis_stream.kds_stream.name} --query "StreamDescription.Shards[0].ShardId" --output text > modules/kinesis/shard_id.txt
      shard_id=$(cat modules/kinesis/shard_id.txt)
      aws kinesis get-shard-iterator --stream-name ${aws_kinesis_stream.kds_stream.name} --shard-id $shard_id --shard-iterator-type TRIM_HORIZON --query "ShardIterator" --output text > modules/kinesis/shard_iterator.txt
    EOT
  }

  depends_on = [aws_kinesis_stream.kds_stream]
}

# Outputs
output "kinesis_stream_arn" {
  value = aws_kinesis_stream.kds_stream.arn
}

output "kinesis_stream_name" {
  value = aws_kinesis_stream.kds_stream.name
}

# Output for putting a record
output "put_record_command" {
  value = "aws kinesis put-record --stream-name ${aws_kinesis_stream.kds_stream.name} --partition-key user1-key --data \"example-data-user1\" --cli-binary-format raw-in-base64-out --output json"
}

# Output for describing the stream
output "describe_stream_command" {
  value = "aws kinesis describe-stream --stream-name ${aws_kinesis_stream.kds_stream.name} --output json"
}

# Output for consuming data
output "get_shard_iterator_command" {
  value = "aws kinesis get-shard-iterator --stream-name ${aws_kinesis_stream.kds_stream.name} --shard-id shardId-000000000000 --shard-iterator-type TRIM_HORIZON --output json"
}

# this automation is not that greate since the iterator changes depending on the buffering_intervaal
output "get_records_command" {
  value = "aws kinesis get-records --output json --shard-iterator $(cat modules/kinesis/shard_iterator.txt)"
}

## the file kdf.tf depends on this one, kds.tf. The other one can be commented out if not needed. 