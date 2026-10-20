FROM node:20-bookworm-slim

WORKDIR /app

ENV NODE_ENV=production

RUN apt-get update \
  && apt-get install -y --no-install-recommends postgresql-client ca-certificates \
  && rm -rf /var/lib/apt/lists/*

COPY package*.json ./
RUN npm ci --omit=dev

COPY src ./src
COPY scripts ./scripts
COPY db ./db

RUN mkdir -p /var/lib/mtaxi/uploads /var/backups/mtaxi

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --retries=5 CMD node -e "fetch('http://127.0.0.1:' + (process.env.PORT || 8080) + '/readyz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["sh", "-c", "npm run db:apply-schema && npm run preflight && if [ \"$MTAXI_SEED_ADMIN_ON_START\" = \"true\" ]; then npm run seed:admin; fi && npm run start"]
