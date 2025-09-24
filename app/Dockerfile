## Builder stage adjusted script
FROM node:16-alpine
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
CMD ["node", "server.js"]

##### OLD script -1
# Builder stage
#FROM node:20-alpine AS builder
#WORKDIR /usr/src/app
#COPY package*.json ./
#RUN npm install
#COPY . .
#RUN npm run build

# Runtime stage
#FROM node:20-alpine
#WORKDIR /usr/src/app
#COPY package*.json ./
#RUN npm install --omit=dev
#COPY --from=builder /usr/src/app/dist ./dist
#CMD ["node", "dist/server.js"]

##### OLD script-2

#FROM node:18-alpine
#WORKDIR /app
#COPY package*.json ./
#RUN npm ci --only=development
#COPY . .
#ENV PORT=3000
#EXPOSE 3000
#CMD ["node","src/app.js"]
