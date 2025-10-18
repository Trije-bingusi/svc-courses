FROM node:22-alpine@sha256:dbcedd8aeab47fbc0f4dd4bffa55b7c3c729a707875968d467aaaea42d6225af

WORKDIR /usr/src/app

COPY package*.json ./

# Use npm ci for clean install; fallback to npm install if ci fails
RUN npm ci --omit=dev || npm install --omit-dev

COPY . .

EXPOSE 3000

CMD ["npm", "start"]