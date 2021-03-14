.PHONY: go docs

GOPATH := $(or ${GOPATH}, ${HOME}/go)
GO_DEST := ./go
SPACE := $(EMPTY) $(EMPTY)
PB_ROOT := $(shell find proto/ -type f -name '*.proto' | cut -c7- )
PROTOC_GEN_GO:=  $(GOPATH)/bin/protoc-gen-go
PROTOC_GEN_GO_GRPC:=  $(GOPATH)/bin/protoc-gen-go-grpc
PROTOC_GEN_GRPC_GATEWAY:=  $(GOPATH)/bin/protoc-gen-grpc-gateway
PROTOC_GEN_OPENAPIV2 :=  $(GOPATH)/bin/protoc-gen-openapiv2
PROTOC_GEN_GO_JSON :=  $(GOPATH)/bin/protoc-gen-go-json
PROTOC_GEN_GO_VALIDATE :=  $(GOPATH)/bin/protoc-gen-go-validate

# enable marshal go
GO_JSON_WILL_MARSHAL := \
	entities/product.proto\
	services/product.proto

GO_JSON_MARSHAL	:= $(addprefix go/, $(GO_JSON_WILL_MARSHAL:.proto=.pb.json.go))
PROTO_GOS 		:= $(addprefix go/, $(PB_ROOT:.proto=.pb.go))

INCLUDES := ./proto ./vendor/github.com/envoyproxy/protoc-gen-validate vendor/github.com/grpc-ecosystem/grpc-gateway/v2
PROTO_INCLUDES := $(addprefix -I , $(INCLUDES))

PROTOC_GO_PLUGINS :=  \
	$(PROTOC_GEN_GO) \
	$(PROTOC_GEN_GO_GRPC) \
	$(PROTOC_GEN_GRPC_GATEWAY) \
	$(PROTOC_GEN_OPENAPIV2) \
	$(PROTOC_GEN_GO_VALIDATE)
PROTOC_GO_PLUGINS_ARG :=  $(addprefix --plugin$(SPACE), $(PROTOC_GO_PLUGINS))

# go stuff
go: vendor $(PROTO_GOS) $(GO_JSON_MARSHAL)

$(GO_DEST)/%.pb.go: proto%.proto $(PROTOC_GO_PLUGINS)
	@mkdir -p $(@D)
	protoc\
		$(PROTO_INCLUDES)\
		$(PROTOC_GO_PLUGINS_ARG)\
		$< \
		--grpc-gateway_out=logtostderr=true,paths=source_relative:$(GO_DEST) \
		--go_out=:$(GO_DEST) --go_opt=paths=source_relative \
		--validate_out="paths=source_relative,lang=go:$(GO_DEST)" \
		--go-grpc_out=:$(GO_DEST) --go-grpc_opt=paths=source_relative

	protoc\
		$(PROTO_INCLUDES)\
		$(PROTOC_GO_PLUGINS_ARG)\
		--grpc-gateway_out $(GO_DEST) \
		--grpc-gateway_opt logtostderr=true \
		--grpc-gateway_opt paths=source_relative \
		$<

# json Marshal & Unmarshal fields for proto
$(GO_DEST)/%.pb.json.go: proto/%.proto $(PROTOC_GEN_GO_JSON)
	@mkdir -p $(@D)
	protoc\
		$(PROTO_INCLUDES)\
		--plugin $(PROTOC_GEN_GO_JSON)\
		$< \
		--go-json_out=allow_unknown,enums_as_ints,orig_name:$(GO_DEST)

vendor:
	go mod vendor

docs: $(PROTOC_GEN_OPENAPIV2)
	@mkdir -p docs
	protoc\
		$(PROTO_INCLUDES)\
		$(PROTOC_GO_PLUGINS_ARG)\
		--openapiv2_out json_names_for_fields=false:./docs \
		--openapiv2_opt logtostderr=true\
		--openapiv2_opt enums_as_ints=true\
		$(PB_ROOT)
	
# Install plugin for Google Protocol Buffers
$(PROTOC_GEN_GO):
	GOPATH=$(GOPATH) go install -mod=mod \
		google.golang.org/protobuf/cmd/protoc-gen-go

$(PROTOC_GEN_GO_VALIDATE):
	@cd /tmp && go get -d github.com/envoyproxy/protoc-gen-validate
	@make -C $(GOPATH)/src/github.com/envoyproxy/protoc-gen-validate build

$(PROTOC_GEN_GO_JSON):
	@GOPATH=$(GOPATH) go install -mod=mod github.com/mitchellh/protoc-gen-go-json

$(PROTOC_GEN_GO_GRPC):
	@GOPATH=$(GOPATH) go install -mod=mod google.golang.org/grpc/cmd/protoc-gen-go-grpc

$(PROTOC_GEN_GRPC_GATEWAY):
	@GOPATH=$(GOPATH) go install -mod=mod github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-grpc-gateway

$(PROTOC_GEN_OPENAPIV2):
	@GOPATH=$(GOPATH) go install -mod=mod github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-openapiv2

$(BUF)
	@GOPATH=$(GOPATH) go install -mod=mod github.com/bufbuild/buf/cmd/buf