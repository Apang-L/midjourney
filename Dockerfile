FROM registry.bbcloud.babybus.com/pagoda/node:18-alpine AS base

# 设置环境变量http_proxy和https_proxy
ENV http_proxy=http://10.9.249.135:18888
ENV https_proxy=http://10.9.249.135:18888

FROM base AS deps

RUN apk add --no-cache libc6-compat

WORKDIR /app

COPY package.json pnpm-lock.yaml ./
RUN npm install pnpm -g
RUN pnpm config set registry 'https://registry.npmjs.org/'
RUN pnpm install --no-frozen-lockfile

FROM base AS builder


RUN apk update && apk add --no-cache git

ENV OPENAI_API_KEY=""
ENV CODE=""

WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

FROM base AS runner
WORKDIR /app

RUN apk add proxychains-ng

# 取消代理环境变量
ENV http_proxy=
ENV https_proxy=

ENV PROXY_URL="http://10.9.249.135:18888"
ENV OPENAI_API_KEY="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"
ENV CODE=""
ENV MJ_SERVER_ID="1130174786010624020"
ENV MJ_CHANNEL_ID="1130175529413267486"
ENV MJ_USER_TOKEN="MTA3NTY2MTU5MDM3ODA3MDA0OA.GaszkB.MNKkUj63d2X7JAraezL2Sc6XYm0O1stCdRwS1Y"
ENV MJ_DISCORD_WSS_PROXY=""
ENV MJ_DISCORD_CDN_PROXY=""

COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/.next/server ./.next/server

EXPOSE 3000

CMD if [ -n "$PROXY_URL" ]; then \
        export HOSTNAME="0.0.0.0"; \
        protocol=$(echo $PROXY_URL | cut -d: -f1); \
        host=$(echo $PROXY_URL | cut -d/ -f3 | cut -d: -f1); \
        port=$(echo $PROXY_URL | cut -d: -f3); \
        conf=/etc/proxychains.conf; \
        echo "strict_chain" > $conf; \
        echo "proxy_dns" >> $conf; \
        echo "remote_dns_subnet 224" >> $conf; \
        echo "tcp_read_time_out 15000" >> $conf; \
        echo "tcp_connect_time_out 8000" >> $conf; \
        echo "localnet 0.0.0.0/255.0.0.0" >> $conf; \
        echo "localnet ::1/128" >> $conf; \
        echo "[ProxyList]" >> $conf; \
        echo "$protocol $host $port" >> $conf; \
        cat /etc/proxychains.conf; \
        proxychains -f $conf node server.js; \
    else \
        node server.js; \
    fi