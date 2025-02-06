# Stage 1: Build the application
FROM node:16-alpine AS build

# Set the working directory
WORKDIR /app

# Copy package.json and package-lock.json
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy the rest of the application code
COPY . .

# Stage 2: Create the final lightweight image
FROM node:16-alpine

# Set the working directory
WORKDIR /app

# Copy only the necessary files from the build stage
COPY --from=build /app /app

# Expose the port the app runs on
EXPOSE 3000

# Command to run the application
CMD ["node", "app.js"]

# to test locallly: 
# $ docker build -t test_app_portfolio:1.0 .
# $ docker run -t -d -p 3000:3000 --name app_portfolio test_app_portfolio:1.0