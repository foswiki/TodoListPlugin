FOSWIKI_ROOT?=~/foswiki/core
TARGET=build/pkg.css build/pkg.js

-include $(FOSWIKI_ROOT)/pub/System/JQueryPlugin/Makefile.include

PKG_SOURCE=src/TodoItem.js src/TodoList.js

build/pkg.js: $(PKG_SOURCE)
	@echo "generating $@"
	@$(JSMIN) $^ > $@	

build/pkg.css: src/todolist.css
	@echo "generating $@"
	@$(CSSMIN) $^ $(CSSMIN_ARGS)> $@

clean:
	rm -rf build/*
