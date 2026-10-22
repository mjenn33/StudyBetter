# Build from the repository root (the server depends on packages/quiz_core):
#   docker build -f server/Dockerfile .

FROM dart:3.13 AS build
WORKDIR /src

# Resolve dependencies first so this layer is cached until a pubspec changes.
# The Flutter app is a workspace member but needs the Flutter SDK and is not
# part of the server, so it is dropped from the workspace inside the image
# (CRs are stripped first: Windows checkouts may have CRLF line endings).
COPY pubspec.yaml pubspec.lock analysis_options.yaml ./
COPY packages/quiz_core/pubspec.yaml packages/quiz_core/
COPY server/pubspec.yaml server/
RUN sed -i -e 's/\r$//' -e '/^  - app$/d' pubspec.yaml && dart pub get

COPY packages/quiz_core packages/quiz_core
COPY server server
RUN cd packages/quiz_core && dart run build_runner build -d
RUN mkdir -p /out && dart compile exe server/bin/server.dart -o /out/server

FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /out/server /app/bin/server

ENV PORT=8080
EXPOSE 8080
CMD ["/app/bin/server"]
