FROM ruby:2.4.2

RUN gem install bundle

COPY Gemfile Gemfile
RUN bundle install

COPY aggregator.rb aggregator.rb

CMD bundle exec aggregator.rb
