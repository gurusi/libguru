NAME=libguru
VERSION=0.10
PACKAGE=$(NAME)_$(VERSION).deb

.PHONY: package

package:
	# NOTE: if you'd like to debug the package creation process, give give
	# --debug-workspace switch to fpm and inspect the build directories (in
	#  /tmp/package-*)
	fpm \
		--force \
		-s dir -t deb -n$(NAME) -v$(VERSION) --architecture=all \
		--prefix=/usr/lib/libguru -C ./lib \
		libguru-base.sh

# vim: set ts=4 noet cc=80:
