# Container image that runs your code
FROM ruby:2.6.5

# Copies your code file from your action repository to the filesystem path `/` of the container
COPY entrypoint.rb /entrypoint.rb

# Code file to execute when the docker container starts up (`entrypoint.sh`)
ENTRYPOINT ["ruby","/entrypoint.rb"]