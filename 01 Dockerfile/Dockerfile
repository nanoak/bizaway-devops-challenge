# ========================= 
# 1) Base image with pnpm 
# ========================= 
FROM node:24-alpine AS base 

# Working directory inside the container 
WORKDIR /srv/app/main 

# Enable corepack to use pnpm (already included in Node 24, Node.js docummentation) 
RUN corepack enable 

# ========================= 
# 2) Dependencies (including dev) 
# ========================= 
FROM base AS deps 

# Copy only dependency files to leverage Docker layer caching 
COPY main/package.json main/pnpm-lock.yaml ./ 

# Install all dependencies (production + development) for the build stage.
# pnpm is used in this project. The --frozen-lockfile flag makes the build fail if package.json and pnpm-lock.yaml are out of sync.
RUN pnpm install --frozen-lockfile 

# ========================= 
# 3) NestJS application build 
# ========================= 
FROM base AS builder 

# Reuse node_modules from dependencies stage 
COPY --from=deps /srv/app/main/node_modules ./node_modules 

# Copy the source code from the main folder 
COPY main ./ 

# Build the NestJS application (output in dist/ assuming NestJS default behaviour) 
RUN pnpm run build 

# ========================= 
# 4) Final image 
# ========================= 
# Starting with a fresh node image trying to create the final image as light as possible 
FROM node:24-alpine AS final 

WORKDIR /srv/app/main 

# Set environment to production 

ENV NODE_ENV=production 

# Enable pnpm via corepack 
RUN corepack enable 

# Create a non-root user for security purposes 
RUN addgroup -g 1001 bizgroup \ 
    && adduser -D -u 1001 -G bizgroup bizuser 

# Copy only required artifacts: 
# - package.json for dependency resolution 
# - compiled dist folder 
# - node_modules from builder stage 

COPY main/package.json ./package.json 
COPY --from=builder /srv/app/main/dist ./dist 
COPY --from=builder /srv/app/main/node_modules ./node_modules 

# Remove development dependencies to reduce image size 
RUN pnpm prune --prod \ && chown -R bizuser:bizgroup /srv/app 

# Switch to non-root user 
USER bizuser 

# Default NestJS port 
EXPOSE 3000 

# Start the application 
CMD ["node", "dist/main.js"]