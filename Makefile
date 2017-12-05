BLOG_BUILD_DIR := docs
BLOG_TITLE := "P. Czarnota"
BLOG_DESCRIPTION := "Programmer's blog"
BLOG_LONG_DESCRIPTION := "Programmer's blog by P. Czarnota"
BLOG_HTTP_URL := "https://czarnota.github.io"

all: build

.PHONY: serve
serve: build
	php -S localhost:8000 -t "$(BLOG_BUILD_DIR)"

.PHONY: s
s: serve

.PHONY: cs
rs: | clean serve

.SILENT: build
.PHONY: build
build:
	BLOG_BUILD_DIR=$(BLOG_BUILD_DIR) \
	BLOG_TITLE=$(BLOG_TITLE) \
	BLOG_DESCRIPTION=$(BLOG_DESCRIPTION) \
	BLOG_LONG_DESCRIPTION=$(BLOG_LONG_DESCRIPTION) \
	BLOG_HTTP_URL=$(BLOG_HTTP_URL) \
	bin/blog.sh

.PHONY: clean
clean:
	rm -fr "$(BLOG_BUILD_DIR)"
