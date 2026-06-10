FROM node:18-alpine

WORKDIR /app

ARG NEXT_PUBLIC_API_URL
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL

COPY package.json package-lock.json ./

RUN npm install

COPY . .

RUN npm run build

RUN mkdir -p .next/standalone/.next
RUN cp -r .next/static .next/standalone/.next/static
RUN cp -r public .next/standalone/public || true

EXPOSE 3000

CMD ["sh", "-c", "cd .next/standalone && node server.js"]