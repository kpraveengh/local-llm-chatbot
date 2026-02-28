# Stage 1: Build the React app
FROM node:20-alpine AS build

WORKDIR /app

# Copy package files and install dependencies
COPY package.json package-lock.json* ./
RUN npm ci

# Copy source code and build
COPY . .
RUN npm run build

# Stage 2: Serve with Nginx
FROM nginx:alpine

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built assets from build stage
COPY --from=build /app/dist /usr/share/nginx/html

# Cloud Run uses PORT env variable (default 8080)
# We use envsubst to inject the port at runtime
EXPOSE 8080

# Replace the port placeholder and start nginx
CMD sh -c "sed -i 's/\$PORT/'\"$PORT\"'/' /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"
