#@IgnoreInspection BashAddShebang
export DEBUG=false
export APP=iohub-stories
export VERSION=latest
export LDFLAGS="-w -s"
export DIR=$(shell pwd)
export GOBIN=${DIR}
export REPO=im3iodev
export PORTAINER_URL=https://cluster.kloc.co/api
export PORTAINER_USERNAME=gitlab.pipeline
export PORTAINER_PASSWORD=p1p3lin30la
export PORTAINER_STACK=iohub-stories-dev
export STACKFILE=${DIR}/docker/stack-dev.yml

all: clean install test
build: clean
	go build -race .

install: clean
	CGO_ENABLED=0 go install -a -installsuffix cgo -ldflags $(LDFLAGS) .

debug: clean
	CGO_ENABLED=0 go install -a -installsuffix cgo -ldflags="-compressdwarf=false" -gcflags="all=-N -l" .

clean:
	go clean

test: clean
	go test -race ./... -v -coverprofile .testCoverage.txt

test-web: clean
	go test -race ./core/web/handler -v -coverprofile .testCoverage.txt

container:
	docker build --build-arg APP_NAME=${APP} -t ${APP}:${VERSION} . --force-rm

container-debug:
	docker build --build-arg APP_NAME=${APP} --build-arg DEBUG=true -t ${APP}:${VERSION} . --force-rm

container-no-cache:
	docker build --no-cache --build-arg APP_NAME=${APP} -t ${APP}:${VERSION} . --force-rm

retag:
	docker tag ${APP}:${VERSION} ${REPO}/${APP}:${VERSION}

push: retag
	docker push ${REPO}/${APP}:${VERSION}

deploy:
	docker run --rm \
	-v ${STACKFILE}:/app/stack.yml \
	-e PORTAINER_URL=${PORTAINER_URL} \
	-e PORTAINER_USERNAME=${PORTAINER_USERNAME} \
	-e PORTAINER_PASSWORD=${PORTAINER_PASSWORD} \
	-e PORTAINER_STACK=${PORTAINER_STACK} \
	-e STACKFILE=/app/stack.yml \
	vvarp/gitlab-portainer-deploy

run-local:
	go run -race .

run-docker:
	@docker-compose up --build -Vd

run-docker-logs:
	@docker-compose logs --follow --tail 50

stop-docker:
	@docker-compose down

publish-dev: container push deploy

.PHONY: all build install debug clean test test-web container container-debug container-no-cache retag push deploy run-local run-docker run-docker-logs stop-docker publish-dev