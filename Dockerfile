FROM quay.io/powercloud/powervs-container-host:ocp-latest

LABEL authors="Rafael Sene - rpsene@br.ibm.com"

WORKDIR /terraform

RUN ibmcloud plugin update power-iaas --force

COPY ./main.tf .
COPY ./provider.tf .
COPY ./variables.tf .
COPY ./collector.sh .

RUN chmod +x ./collector.sh

ENTRYPOINT ["/bin/bash", "-c", "./collector.sh"]
