EXTRA_INSTALL = scripts/

gvmdir = $(bindir)/
gvm_SCRIPTS = bin/gvm
install_dir = $(prefix)/gvm

install-exec-hook:
	(mkdir -p $(install_dir) ;	 \
	cp -rf . $(install_dir))

#install-data-hook:
#        (mkdir -p $(help_dir) ; \
#        cp -f *_help.txt $(help_dir))
