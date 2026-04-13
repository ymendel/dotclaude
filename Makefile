default: install

install: links

links: link_claudedir

link_claudedir: ~/.claude

~/.claude:
	ln -s ${PWD} ~/.claude

clean: clean_claudedir

clean_claudedir:
	rm -f ~/.claude
