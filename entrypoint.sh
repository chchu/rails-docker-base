#!/bin/bash
set -e

# Remove a potentially pre-existing server.pid for Rails.
rm -f /rails/tmp/pids/server.pid

RAILS_PORT=3000
if [ -n "$PORT" ]; then
  RAILS_PORT=$PORT
fi

# db migrate
bin/rails db:create
bin/rails db:migrate

# Then exec the container's main process (what's set as CMD in the Dockerfile).
exec bundle exec puma -p $RAILS_PORT -C config/puma.rb
