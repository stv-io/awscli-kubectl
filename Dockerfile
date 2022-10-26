ARG ALPINE_VERSION=3.16
FROM python:3.10.8-alpine${ALPINE_VERSION} as awscli-builder

ARG AWS_CLI_VERSION=2.7.20
# ARG AWS_CLI_VERSION=2.7.35
# ARG AWS_CLI_VERSION=2.8.5
RUN apk add --no-cache git==2.36.3-r0 \
    unzip==6.0-r9 \
    groff==1.22.4-r1 \
    build-base==0.5-r3 \
    libffi-dev==3.4.2-r1 \
    cmake==3.23.1-r0 \
&& git clone --single-branch --depth 1 -b ${AWS_CLI_VERSION} https://github.com/aws/aws-cli.git

WORKDIR /aws-cli
# hadolint ignore=SC1091
RUN sed -i'' 's/PyInstaller.*/PyInstaller==5.2/g' requirements-build.txt \
&& python -m venv venv \
&& . venv/bin/activate \
&& scripts/installers/make-exe \
&& unzip -q dist/awscli-exe.zip \
&& aws/install --bin-dir /aws-cli-bin \
&& /aws-cli-bin/aws --version \
&& rm -rf /usr/local/aws-cli/v2/current/dist/aws_completer /usr/local/aws-cli/v2/current/dist/awscli/data/ac.index /usr/local/aws-cli/v2/current/dist/awscli/examples \
&& find /usr/local/aws-cli/v2/current/dist/awscli/botocore/data -name examples-1.json -delete
# last 2 lines to reduce image size: remove autocomplete and examples

FROM golang:1.18.7-bullseye AS genjsonschema-builder

RUN git clone -b v0.2.2 https://github.com/holgerjh/genjsonschema-cli.git /genjsonschema
WORKDIR /genjsonschema
RUN CGO_ENABLED=0 go build

FROM docker.io/alpine/terragrunt:1.3.3-eks as terragrunt

FROM alpine:3.16.2 as final
ARG ARCH="amd64"
ARG HELM_VERSION="v3.10.1"
ARG KUBECTL_VERSION="v1.23.12"
RUN apk add --no-cache \
      curl==7.83.1-r3 \
      jq==1.6-r1 \
      git==2.36.3-r0 \
      git-crypt==0.6.0-r2 \
      openssh-client==9.0_p1-r2 \
      bash==5.1.16-r2 \
    && curl -sLO https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl \
    && mv kubectl /usr/bin/kubectl \
    && chmod +x /usr/bin/kubectl \
    && curl -sLO https://get.helm.sh/helm-${HELM_VERSION}-linux-${ARCH}.tar.gz \
    && tar -xvzf helm-${HELM_VERSION}-linux-${ARCH}.tar.gz \
    && mv linux-${ARCH}/helm /usr/bin/helm \
    && chmod +x /usr/bin/helm \
    && rm -rf linux-${ARCH} \
    && helm plugin install https://github.com/quintush/helm-unittest --version v0.2.9 \
    && helm plugin install https://github.com/holgerjh/helm-schema --version v0.2.0 \
    && curl -sLO https://github.com/mikefarah/yq/releases/download/v4.28.2/yq_linux_${ARCH} \
    && mv yq_linux_${ARCH} /usr/bin/yq && chmod +x /usr/bin/yq

COPY --from=genjsonschema-builder /genjsonschema/genjsonschema-cli /root/.local/share/helm/plugins/helm-schema/genjsonschema-cli
COPY --from=awscli-builder /usr/local/aws-cli/ /usr/local/aws-cli/
COPY --from=awscli-builder /aws-cli-bin/ /usr/local/bin/
COPY --from=terragrunt /bin/terraform /usr/local/bin/terraform
COPY --from=terragrunt /usr/local/bin/terragrunt /usr/local/bin/terragrunt
COPY --from=terragrunt /usr/bin/aws-iam-authenticator /usr/local/bin/aws-iam-authenticator

ENV USER=user
ENV GROUP=user
ENV UID=12345
ENV GID=23456
ENV HELM_REPOSITORY_CACHE="/home/$USER/.helm/cache"

COPY .bashrc /home/$USER/.bashrc

RUN addgroup -S -g "$GID" "$GROUP" \
 && adduser \
    --disabled-password \
    --gecos "" \
    --home "/home/$USER" \
    --ingroup "$USER" \
    --uid "$UID" \
    "$USER" \
  && mkdir -p "/home/$USER/.helm/cache"

USER $USER
WORKDIR $HOME

ENTRYPOINT [ "bash" ]
