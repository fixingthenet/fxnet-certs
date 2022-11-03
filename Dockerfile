FROM ruby:2.7.5-bullseye

ENV FORCE_REBUILD=20220818-0902

RUN apt-get update -y && \
    apt-get install -y \
            gnupg2 \
            git-core \
            joe \
            curl  

ENV APP_DIR=/code
WORKDIR $APP_DIR

RUN git clone https://github.com/acmesh-official/acme.sh.git && \
    cd ./acme.sh && \
    ./acme.sh --install --force &&\
    ./acme.sh --set-default-ca  --server  letsencrypt

ADD Gemfile /code/Gemfile
ADD Gemfile.lock /code/Gemfile.lock
RUN bundle install

ADD . /code

CMD "/bin/bash"
# to run it run /code/bin/issue.rb
