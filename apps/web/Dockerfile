FROM node:20-alpine

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .

EXPOSE 3000

ENV NODE_ENV=development

CMD ["sh", "-c", "if [ \"$NODE_ENV\" = \"production\" ]; then npm run build && npm run start; else npm run dev; fi"]
