FROM node:12.19-alpine as node

FROM ruby:2.6.6-alpine as builder

# 依存関係のあるパッケージのinstall
# gccやgitなど、ビルドに必要なものもすべて含まれている
RUN apk --update --no-cache add shadow sudo busybox-suid mariadb-connector-c-dev tzdata alpine-sdk sqlite-dev

WORKDIR /rails

COPY Gemfile Gemfile.lock ./

# rails5案件なのでwebpackerの動作環境を整えておく
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/include/node /usr/local/include/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=node /opt/yarn-v1.22.5 /opt/yarn
RUN ln -s /usr/local/bin/node /usr/local/bin/nodejs && \
    ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
    ln -s /opt/yarn/bin/yarn /usr/local/bin/yarn

# bundle installした後、makeで発生した不要なファイルは削除。
RUN gem install bundler && \
    bundle install --without development test --path vendor/bundle && \
    find vendor/bundle/ruby -path '*/gems/*/ext/*/Makefile' -exec dirname {} \; | xargs -n1 -P$(nproc) -I{} make -C {} clean

# yarn install
COPY package.json yarn.lock postcss.config.js ./
RUN yarn install

# assets precompile
COPY Rakefile babel.config.js ./
COPY app/javascript app/javascript
COPY app/assets app/assets
COPY bin bin
COPY config config
RUN RAILS_ENV=production bundle exec rails assets:precompile

FROM ruby:2.6-alpine

# パッケージ全体を軽量化して、railsが起動する最低限のものにする
RUN apk --update --no-cache add shadow sudo busybox-suid execline tzdata mariadb-connector-c-dev sqlite-dev bash && \
    cp /usr/share/zoneinfo/Asia/Tokyo /etc/localtime

EXPOSE 3000

WORKDIR /rails

# gemやassets:precompileの終わったファイルはbuilderからコピーしてくる
COPY --from=builder /rails/vendor/bundle vendor/bundle
COPY --from=builder /usr/local/bundle /usr/local/bundle

COPY --from=builder /rails/public/assets/ /rails/public/assets/
COPY --from=builder /rails/public/packs/ /rails/public/packs/

COPY . /rails

COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]
