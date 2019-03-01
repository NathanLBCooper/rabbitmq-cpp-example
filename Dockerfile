# https://blogs.msdn.microsoft.com/vcblog/2018/12/13/using-multi-stage-containers-for-c-development/

FROM alpine:latest as build

LABEL description="Build container - rabbitmqcppexample"

RUN apk update && apk add --no-cache \ 
    autoconf build-base binutils cmake curl file gcc g++ git libgcc libtool linux-headers make musl-dev ninja tar unzip wget openssl openssl-dev

RUN cd /tmp \
    && wget https://github.com/Microsoft/CMake/releases/download/untagged-fb9b4dd1072bc49c0ba9/cmake-3.11.18033000-MSVC_2-Linux-x86_64.sh \
    && chmod +x cmake-3.11.18033000-MSVC_2-Linux-x86_64.sh \
    && ./cmake-3.11.18033000-MSVC_2-Linux-x86_64.sh --prefix=/usr/local --skip-license \
    && rm cmake-3.11.18033000-MSVC_2-Linux-x86_64.sh

RUN cd /tmp \
    && git clone https://github.com/Microsoft/vcpkg.git -n \ 
    && cd vcpkg \
    && git checkout 5b0b4b6472fecfe90ce30e108ec56ec0c8bb995f \
    && ./bootstrap-vcpkg.sh -useSystemBinaries

COPY x64-linux-musl.cmake /tmp/vcpkg/triplets/

RUN VCPKG_FORCE_SYSTEM_BINARIES=1 ./tmp/vcpkg/vcpkg install openssl catch2 boost-asio fmt http-parser restinio amqpcpp

COPY ./src /src
WORKDIR /src
# Delete stuff generated by debugging in VSCode
RUN rm -rf /output
RUN mkdir out \
    && cd out \
    && cmake .. -DCMAKE_TOOLCHAIN_FILE=/tmp/vcpkg/scripts/buildsystems/vcpkg.cmake -DVCPKG_TARGET_TRIPLET=x64-linux-musl \
    && make \
    && ctest --verbose

FROM alpine:latest as runtime

LABEL description="Run container - rabbitmqcppexample"

RUN apk update && apk add --no-cache \ 
    libstdc++

COPY --from=build /src/out/rabbitmqcppexample /usr/local/rabbitmqcppexample/rabbitmqcppexample

WORKDIR /usr/local/rabbitmqcppexample

CMD ./rabbitmqcppexample

EXPOSE 8080
