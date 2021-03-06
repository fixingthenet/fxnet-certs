FROM ruby:2.4.1

RUN apt-get update -y && \
    apt-get install -y \
            gnupg2 \
            git-core \
            joe \
            curl  

ENV APP_DIR=/code
WORKDIR $APP_DIR

RUN git clone https://github.com/Neilpang/acme.sh.git && \
    cd ./acme.sh && \
    ./acme.sh --install --force

ADD Gemfile /code/Gemfile
ADD Gemfile.lock /code/Gemfile.lock
RUN bundle install

ADD . /code

CMD "/bin/bash"
# to run it run /code/bin/issue.rb
