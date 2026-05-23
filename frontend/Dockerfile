# ── Stage 1: Dependencies ──────────────────────────────────────────────────────
FROM node:21-alpine AS deps

WORKDIR /app

# Copy manifests first
COPY package*.json ./

# CHANGED: Switched from 'npm ci' to 'npm install' to dynamically resolve lockfile mismatch/drift
RUN npm install --prefer-offline --no-audit

# ── Stage 2: Build ─────────────────────────────────────────────────────────────
FROM node:21-alpine AS builder

WORKDIR /app

# Reuse node_modules from deps stage
COPY --from=deps /app/node_modules ./node_modules

# Copy source
COPY . .

# Copy the docker env file so Vite bakes the correct API URL at build time
COPY .env.docker .env.local

RUN npm run build

# ── Stage 3: Production Server (nginx) ─────────────────────────────────────────
FROM nginx:1.27-alpine AS production

# Remove default nginx welcome page
RUN rm -rf /usr/share/nginx/html/*

# Copy Vite build output into nginx's serve directory
COPY --from=builder /app/dist /usr/share/nginx/html

# Custom nginx config — handles SPA client-side routing
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
