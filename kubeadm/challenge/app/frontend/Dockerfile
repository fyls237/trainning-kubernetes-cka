# --- Stage 1: Build ---
FROM node:18-alpine as builder
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install
COPY . .
RUN npm run build

# --- Stage 2: Production ---
FROM nginx:alpine
# Copie du build React vers le dossier Nginx
COPY --from=builder /app/dist /usr/share/nginx/html
# Copie de la config Nginx custom
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
