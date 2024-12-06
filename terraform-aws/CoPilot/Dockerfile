# Use an official Node.js runtime as the base image
FROM node:18.19.1

ENV MONGO_DB_USERNAME=admin \
    MONGO_DB_PASSWORD=1234

# Set the working directory inside the container
WORKDIR /usr/src/app

# Copy the package.json and package-lock.json
#COPY package*.json ./

# Copy the rest of the application code
COPY app/ .

# Restart npm init - Sometimes it fails and it has to be rebuilt
RUN npm init -y

# Install the dependencies
RUN npm install express ejs multer mongodb

# installing vim
RUN apt-get update && apt-get install -y vim

# Expose the port that the app will run on
EXPOSE 3000

# Define the command to run the application
CMD ["node", "app.js"]

