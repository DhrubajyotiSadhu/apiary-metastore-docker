# Copyright (C) 2018 Expedia Inc.
# Licensed under the Apache License, Version 2.0 (the "License");

from amazonlinux:latest

ENV VAULT_VERSION 0.10.3
ENV RANGER_VERSION 1.1.0
ENV APIARY_METASTORE_LISTENER_VERSION 0.1.0
ENV IAM_JDBC_VERSION 1.1.0

COPY files/RPM-GPG-KEY-emr /etc/pki/rpm-gpg/RPM-GPG-KEY-emr
COPY files/emr-apps.repo /etc/yum.repos.d/emr-apps.repo
COPY files/emr-platform.repo /etc/yum.repos.d/emr-platform.repo

RUN yum -y install java-1.8.0-openjdk \
  java-1.8.0-openjdk-devel.x86_64 \
  hive-metastore \
  mariadb-connector-java \
  mysql \
  wget \
  unzip \
  jq \
  emrfs \
  maven \
  && yum clean all \
  && rm -rf /var/cache/yum

RUN wget -qN https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip && unzip -q -o vault_${VAULT_VERSION}_linux_amd64.zip -d /usr/local/bin/ && rm -f vault_${VAULT_VERSION}_linux_amd64.zip

RUN mkdir -p /usr/lib/apiary && cd /usr/lib/apiary && \
wget -q https://search.maven.org/remotecontent?filepath=com/expedia/apiary/apiary-metastore-listener/${APIARY_METASTORE_LISTENER_VERSION}/apiary-metastore-listener-${APIARY_METASTORE_LISTENER_VERSION}-all.jar -O apiary-metastore-listener-${APIARY_METASTORE_LISTENER_VERSION}-all.jar

RUN cd /usr/lib/hive/lib/ && \
wget -qN http://search.maven.org/remotecontent?filepath=org/apache/ranger/ranger-plugins-audit/${RANGER_VERSION}/ranger-plugins-audit-${RANGER_VERSION}.jar && \
wget -qN http://search.maven.org/remotecontent?filepath=org/apache/ranger/ranger-plugins-common/${RANGER_VERSION}/ranger-plugins-common-${RANGER_VERSION}.jar && \
wget -qN http://search.maven.org/remotecontent?filepath=org/apache/ranger/ranger-plugins-cred/${RANGER_VERSION}/ranger-plugins-cred-${RANGER_VERSION}.jar && \
wget -qN https://search.maven.org/remotecontent?filepath=org/apache/solr/solr-solrj/5.5.4/solr-solrj-5.5.4.jar && \
wget -qN https://search.maven.org/remotecontent?filepath=org/apache/httpcomponents/httpmime/4.5.5/httpmime-4.5.5.jar && \
wget -qN https://search.maven.org/remotecontent?filepath=org/noggit/noggit/0.8/noggit-0.8.jar && \
wget -qN https://search.maven.org/remotecontent?filepath=javax/persistence/javax.persistence-api/2.2/javax.persistence-api-2.2.jar && \
wget -qN https://search.maven.org/remotecontent?filepath=org/eclipse/persistence/eclipselink/2.7.3/eclipselink-2.7.3.jar

COPY src /src
RUN cd src && javac -cp "/usr/lib/hadoop/*:/usr/lib/hive/lib/*:/usr/share/aws/aws-java-sdk/*" *.java && jar cf /usr/lib/hive/lib/MetastoreListeners.jar *.class && rm -f *.class

RUN wget -q -O - https://github.com/rikturnbull/iam-jdbc-driver/archive/v${IAM_JDBC_VERSION}.tar.gz|tar -C /tmp -xzf - && \
cd /tmp/iam-jdbc-driver-${IAM_JDBC_VERSION} && \
sed 's/com.mysql.jdbc.Driver/org.mariadb.jdbc.Driver/' -i src/main/java/uk/co/controlz/aws/IAMJDBCDriver.java && \
sed 's/properties.getProperty(PROPERTY_AWS_REGION)/System.getenv("AWS_REGION")/' -i src/main/java/uk/co/controlz/aws/IAMJDBCDriver.java && \
sed 's/<dependencies>/<dependencies>\n<dependency>\n<groupId>org.mariadb.jdbc<\/groupId>\n<artifactId>mariadb-java-client<\/artifactId>\n<version>2.3.0<\/version>\n<\/dependency>\n/g' -i pom.xml && \
mvn package  && cp -a target/iam-jdbc-driver-${IAM_JDBC_VERSION}.jar /usr/lib/hive/lib/ && \
rm -rf /root/.m2 && rm -rf /tmp/iam-jdbc-driver-${IAM_JDBC_VERSION}

#RDS CA certificate, required to use jdbc with ssl
RUN wget -q https://s3.amazonaws.com/rds-downloads/rds-ca-2015-root.pem -O /etc/pki/ca-trust/source/anchors/rds-ca-2015-root.pem && update-ca-trust && update-ca-trust enable

RUN echo 'export HADOOP_CLASSPATH="$HADOOP_CLASSPATH:/usr/share/aws/emr/emrfs/conf:/usr/share/aws/emr/emrfs/lib/*:/usr/share/aws/emr/emrfs/auxlib/*"' >> /etc/hadoop/conf/hadoop-env.sh
COPY files/core-site.xml /etc/hadoop/conf/core-site.xml
COPY files/emrfs-site.xml /usr/share/aws/emr/emrfs/conf/emrfs-site.xml
COPY files/hive-site.xml /etc/hive/conf/hive-site.xml
COPY files/ranger-hive-security.xml /etc/hive/conf/ranger-hive-security.xml
COPY files/ranger-hive-audit.xml /etc/hive/conf/ranger-hive-audit.xml

EXPOSE 9083
COPY files/startup.sh /startup.sh
CMD /startup.sh
