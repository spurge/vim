instructions:
	# make clean	- Cleans your vim directory
	# make install	- Installs this vim distribution
	# make update	- Updates this vim distribution

clean:
	#

install:
	git submodule update --init
	# Linking vimrc
	ln -sf .vim/vimrc ../.vimrc
	# Pathogen
	mkdir -p autoload
	curl -Sso autoload/pathogen.vim \
		https://raw.githubusercontent.com/tpope/vim-pathogen/master/autoload/pathogen.vim

update:
	git pull
	git submodule sync
	git submodule update --init
