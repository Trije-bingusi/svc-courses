FROM node:22-alpine

WORKDIR /usr/src/app

COPY package*.json ./

# Use npm ci for clean install; fallback to npm install if ci fails
RUN npm ci --omit=dev || npm install --omit-dev

COPY . .

EXPOSE 3000

CMD ["npm", "start"]