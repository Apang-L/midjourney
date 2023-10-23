### 基础镜像 ###
FROM node:18-alpine AS base
# 设置Alpine的镜像源为阿里云的镜像源
RUN echo "http://mirrors.aliyun.com/alpine/v3.10/main/" > /etc/apk/repositories \
 && echo "http://mirrors.aliyun.com/alpine/v3.10/community/" >> /etc/apk/repositories

### 依赖镜像 ###
FROM base AS deps

RUN apk add --no-cache libc6-compat

WORKDIR /app

COPY package.json pnpm-lock.yaml ./

# 更换为淘宝镜像
RUN npm install -g pnpm --registry=https://registry.npm.taobao.org
RUN pnpm config set registry 'https://registry.npm.taobao.org/'
RUN pnpm install --no-frozen-lockfile

### 构建镜像 ###
FROM base AS builder
# 设置Alpine的镜像源为阿里云的镜像源
RUN echo "http://mirrors.aliyun.com/alpine/v3.10/main/" > /etc/apk/repositories \
 && echo "http://mirrors.aliyun.com/alpine/v3.10/community/" >> /etc/apk/repositories

RUN apk update && apk add --no-cache git

ENV OPENAI_API_KEY=""
ENV CODE=""

WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

### 运行镜像 ###
FROM base AS runner
WORKDIR /app

RUN apk add proxychains-ng

ENV PROXY_URL=""
ENV OPENAI_API_KEY=""
ENV CODE=""
ENV MJ_SERVER_ID=""
ENV MJ_CHANNEL_ID=""
ENV MJ_USER_TOKEN=""
ENV MJ_DISCORD_WSS_PROXY=""
ENV MJ_DISCORD_CDN_PROXY=""

COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/.next/server ./.next/server

EXPOSE 3000

CMD if [ -n "$PROXY_URL" ]; then \
        export HOSTNAME="127.0.0.1"; \
        protocol=$(echo $PROXY_URL | cut -d: -f1); \
        host=$(echo $PROXY_URL | cut -d/ -f3 | cut -d: -f1); \
        port=$(echo $PROXY_URL | cut -d: -f3); \
        conf=/etc/proxychains.conf; \
        echo "strict_chain" > $conf; \
        echo "proxy_dns" >> $conf; \
        echo "remote_dns_subnet 224" >> $conf; \
        echo "tcp_read_time_out 15000" >> $conf; \
        echo "tcp_connect_time_out 8000" >> $conf; \
        echo "localnet 127.0.0.0/255.0.0.0" >> $conf; \
        echo "localnet ::1/128" >> $conf; \
        echo "[ProxyList]" >> $conf; \
        echo "$protocol $host $port" >> $conf; \
        cat /etc/proxychains.conf; \
        proxychains -f $conf node server.js; \
    else \
        node server.js; \
    fi