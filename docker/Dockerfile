FROM node:22-alpine AS build
WORKDIR /workspace
COPY app/package*.json ./
RUN npm install
COPY app/ ./
RUN npm test && npm run build

FROM nginx:1.27-alpine
RUN apk upgrade --no-cache && rm -rf /usr/share/nginx/html/*
COPY --from=build /workspace/dist/ /usr/share/nginx/html/
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
USER nginx
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 CMD wget -q -O /dev/null http://127.0.0.1:8080/health || exit 1
