FROM library/postgres

RUN apt-get update
RUN apt-get -y install unzip ruby dos2unix

RUN mkdir /data
COPY install.sql /data/
COPY update_csvs.rb /data/
COPY adventure_works_2014_OLTP_script.zip /data/data/
RUN cd /data/data && \
    unzip adventure_works_2014_OLTP_script.zip && \
    rm adventure_works_2014_OLTP_script.zip && \
    cd ../ && \
    ruby update_csvs.rb && \
    rm update_csvs.rb

COPY install.sh /docker-entrypoint-initdb.d/
WORKDIR /data/
RUN dos2unix /docker-entrypoint-initdb.d/*.sh
