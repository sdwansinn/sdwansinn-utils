FROM centos:7

MAINTAINER zoyo.red 

ENV FINAL 2019-12-20
ENV SWAN_VER 3.15

WORKDIR /opt/ipsec/

RUN yum update -y \
   && yum install runc libreswan bind-utils wget sysvinit-tools which policycoreutils -y \
   && yum-complete-transaction --cleanup-only \
   && yum clean all \
   && systemctl enable ipsec
   
COPY ./run.sh /opt/ipsec/run.sh
RUN chmod 755 /opt/ipsec/run.sh
VOLUME ["/sys/fs/cgroup" ]

CMD ["/opt/ipsec/run.sh"]
