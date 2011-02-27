EJABBERD_PATH=../ejabberd/
EJABBERD_SRC_PATH=$(EJABBERD_PATH)src

BEAMS=ebin/mod_private_email.beam

all: $(BEAMS)

ebin/%.beam: src/%.erl
	@mkdir -p ebin
	erlc -pa ./ebin -I ./include -I $(EJABBERD_SRC_PATH) -pa $(EJABBERD_SRC_PATH) -o ./ebin $<

install: all
	cp ebin/*.beam $(EJABBERD_SRC_PATH)

clean:
	rm -f ebin/*.beam test_ebin/*.beam
