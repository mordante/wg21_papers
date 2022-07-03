%.html: $(DEPS)
	$(PANDOC) --bibliography $(DATADIR)/csl.json
include $(dir $(lastword $(MAKEFILE_LIST)))wg21/Makefile
