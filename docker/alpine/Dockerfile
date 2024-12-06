# Use the Jenkins agent with Alpine and JDK 11 as the base image
FROM jenkins/agent:alpine-jdk11

# Switch to root to install the necessary dependencies
USER root

# Update the package list and install the dependencies
RUN apk update 
RUN apk add --no-cache  
RUN apk add sudo 
RUN apk add net-tools 
RUN apk add git 
RUN apk add jq 
RUN apk add busybox-extras 
RUN apk add ufw 
RUN mkdir /run/sshd 

# Switch back to the Jenkins user after installation
USER jenkins

# Define the default command (optional)
CMD ["jenkins-agent"]
