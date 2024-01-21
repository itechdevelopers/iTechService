FROM ruby:2.7.5
RUN apt-get update && apt-get install -y nodejs libpq-dev imagemagick libmagickwand-dev tzdata
RUN gem install bundler -v 2.3.17
WORKDIR /app
COPY Gemfile* .
RUN bundle install
COPY . .
EXPOSE 3000
CMD ["rails", "server", "-b", "0.0.0.0", "-P", "/tmp/pids/server.pid"]
