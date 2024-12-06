# Use the official Ubuntu 20.04 image as the base image
FROM ubuntu:20.04

# Set environment variable to prevent prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Update the package list and install UFW
RUN apt-get update && \
    apt-get install -y ufw && \
    apt-get clean

# Allow SSH (port 22) and HTTP (port 80) as an example
RUN ufw allow 22/tcp && ufw allow 80/tcp

# Enable UFW without confirmation
RUN ufw --force enable

# Expose SSH and HTTP ports (optional, based on your use case)
EXPOSE 22 80

# Start UFW and show status
CMD ["ufw", "status"]

