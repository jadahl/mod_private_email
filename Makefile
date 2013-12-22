PREFIX=/usr

BEAMS=ebin/mod_private_email.beam

INCLUDES=-I ./include -I $(PREFIX)/lib -pa $(PREFIX)/lib/ejabberd/ebin

all: $(BEAMS)

ebin/%.beam: src/%.erl
	@mkdir -p ebin
	erlc -pa ./ebin $(INCLUDES) -o ./ebin $<

install: all
	cp ebin/*.beam $(PREFIX)/lib/ejabberd/ebin

clean:
	rm -f ebin/*.beam test_ebin/*.beam
