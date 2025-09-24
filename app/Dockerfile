FROM node:16-alpine
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm install --omit=dev
RUN npm ci --only=production
COPY . .
CMD ["node", "server.js"]

##### OLD script

#FROM node:18-alpine
#WORKDIR /app
#COPY package*.json ./
#RUN npm ci --only=development
#COPY . .
#ENV PORT=3000
#EXPOSE 3000
#CMD ["node","src/app.js"]
