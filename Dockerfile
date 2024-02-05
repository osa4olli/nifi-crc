FROM apache/nifi:1.25.0

RUN wget https://jdbc.postgresql.org/download/postgresql-42.7.1.jar -O /opt/nifi/nifi-current/lib/postgresql-42.7.1.jar

RUN chmod -R a+r /opt/nifi/nifi-current/
RUN chmod -R a+x /opt/nifi/nifi-current/lib/
RUN chmod -R a+x /opt/nifi/nifi-current/bin/
RUN chmod -R a+rwx /opt/nifi/nifi-current/conf/
