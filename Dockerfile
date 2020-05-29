# Container image that runs your code
FROM ruby:2.6.5
ENV LANG C.UTF-8

RUN mkdir -p /var/app
RUN mkdir -p /var/runs
WORKDIR /var/app
RUN gem update --system
RUN bundle install
# Copies your code file from your action repository to the filesystem path `/` of the container
COPY entrypoint.rb /var/app/entrypoint.rb

# Code file to execute when the docker container starts up (`entrypoint.sh`)
ENTRYPOINT ["ruby","/entrypoint.rb"]