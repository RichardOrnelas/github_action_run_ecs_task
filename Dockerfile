# Container image that runs your code
FROM ruby:2.6.5
ENV LANG C.UTF-8

RUN mkdir -p /var/app
RUN mkdir -p /var/runs
WORKDIR /var/app
RUN gem update --system

COPY Gemfile /var/app/Gemfile
COPY Gemfile.lock /var/app/Gemfile.lock
RUN bundle install
# Copies your code file from your action repository to the filesystem path `/` of the container
COPY . /var/app

# Code file to execute when the docker container starts up (`entrypoint.sh`)
ENTRYPOINT ["ruby","/var/app/entrypoint.rb"]