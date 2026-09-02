#!/usr/bin/env bash
# Replit startup script
set -e

echo "==> Installing gems..."
bundle config set --local without 'development test'
bundle install --jobs 1

echo "==> Preparing database..."
bundle exec rails db:create 2>/dev/null || true
bundle exec rails db:migrate
bundle exec rails db:seed

echo "==> Precompiling assets..."
bundle exec rails assets:precompile

echo "==> Starting Rails server..."
bundle exec rails server -b 0.0.0.0 -p 3000