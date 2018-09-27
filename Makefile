#
# Copyright (c) 2014 Rick Salevsky <rsalevsky@suse.de>
# Copyright (c) 2016 Stefan Knorr <sknorr@suse.de>
# Copyright (c) 2018 Alessio Adamo <alessio@alessioadamo.com>
#

# How to use this makefile:
# * After updating the XML: $ make po
# * When creating output:   $ make linguas; make all
# * To clean up:            $ make clean

.PHONY: clean_po_temp clean_mo clean_pot clean linguas po pot translate validate pdf text single-html translatedxml

# The list of available languages is retrieved by searching for subdirs with
# pattern lang/po and removing the '/po' suffix
FULL_LANG_LIST := $(subst /po,,$(wildcard */po))

# The list of source files is represented by all '.xml' files in xml/ dir
# except schemas.xml which does not contain translatable strings
FULL_XML_LIST := $(filter-out xml/schemas.xml,$(wildcard xml/*.xml))

# The list of entities is represented by all '.ent' files in xml/ dir
FULL_ENT_LIST := $(wildcard xml/*.ent)

# The PO domain list is generated by taking the basename of the source files
# and removing the dir part
FULL_DOMAIN_LIST := $(basename $(notdir $(FULL_XML_LIST)))

# The list of POT files is generated by attaching the '50-pot/' prefix and the
# '.pot' suffix to each domain
FULL_POT_LIST := $(foreach DOMAIN,$(FULL_DOMAIN_LIST),50-pot/$(DOMAIN).pot)

# The list of PO files is generated as follows. First, for each available language
# it is generated a pattern like 'lang/po/_DOMAIN_NAME_.lang.po', then the placeholder
# _DOMAIN_NAME_ is substituted with each available domain to get a pattern like
# 'lang/po/domain.lang.po'
FULL_PO_LIST := $(foreach DOMAIN,$(FULL_DOMAIN_LIST),$(subst _DOMAIN_NAME_,$(DOMAIN),$(foreach LANG,$(FULL_LANG_LIST),$(LANG)/po/_DOMAIN_NAME_.$(LANG).po)))

# The list of MO files is generated ...
FULL_MO_LIST := $(foreach DOMAIN,$(FULL_DOMAIN_LIST),$(subst _DOMAIN_NAME_,$(DOMAIN),$(foreach LANG,$(FULL_LANG_LIST),$(LANG)/po/_DOMAIN_NAME_.$(LANG).po)))

# If not specified, the default books to be translated are DC-SLED-all, DC-SLES-all,
# DC-opensuse-all
ifndef BOOKS_TO_TRANSLATE
  BOOKS_TO_TRANSLATE := DC-SLED-all DC-SLES-all DC-opensuse-all
endif

# Determine the sources necessary to build selected books
SELECTED_SOURCES := $(shell 50-tools/xml-selector $(BOOKS_TO_TRANSLATE) | tee /dev/tty | sed '1d; s@XML sources of .*: @@; /^$$/d' | tr ' ' '\n' | sort -u)

# These are the xml files required for the selected books stored in the
# variable "BOOKS_TO_TRANSLATE"
SELECTED_XML_FILES := $(filter %.xml,$(SELECTED_SOURCES))

# These are the ent files required for the selected books stored in the
# variable "BOOKS_TO_TRANSLATE"
SELECTED_ENT_FILES := $(filter %.ent,$(SELECTED_SOURCES))

# These are the PO domain list required for the translation of selected books stored in the
# variable "BOOKS_TO_TRANSLATE"
SELECTED_DOMAIN_LIST := $(basename $(notdir $(SELECTED_XML_FILES)))

ifndef LANGS
# If LANGS is not defined within the command line, for output use only those files that have at least 60% translations
# TO DO: rework the po-selector script to limit the check only on the PO files necessary to translate the selected books
  LANGS = $(shell 50-tools/po-selector $(SELECTED_DOMAIN_LIST) | tee /dev/tty | sort -u)
endif

# TO DO: check if LANGSEN is still necessary
LANGSEN := $(LANGS) en

SELECTED_MO_FILES := $(foreach LANG,$(LANGS),$(addprefix $(LANG)/po/,$(addsuffix .$(LANG).mo,$(SELECTED_DOMAIN_LIST))))

XML_DEST_FILES := $(foreach LANG, $(LANGS), $(addprefix $(LANG)/,$(SELECTED_XML_FILES)))
ENT_DEST_FILES := $(foreach LANG,$(LANGS),$(addprefix $(LANG)/,$(SELECTED_ENT_FILES)))
SCHEMAS_XML_DEST_FILES := $(foreach LANG,$(LANGS),$(addprefix $(LANG)/xml/,schemas.xml))
DC_DEST_FILES := $(foreach LANG,$(LANGS),$(addprefix $(LANG)/,$(BOOKS_TO_TRANSLATE)))
# PDF_FILES := $(foreach l, $(LANGSEN), build/release-notes.$(l)/release-notes.$(l)_color_$(l).pdf)
# SINGLE_HTML_FILES := $(foreach l, $(LANGSEN), build/release-notes.$(l)/single-html/release-notes.$(l)/index.html)
# TXT_FILES := $(foreach l, $(LANGSEN), build/release-notes.$(l)/release-notes.$(l).txt)

# TO DO: check if STYLEROOT is still necessary
ifndef STYLEROOT
  STYLEROOT := /usr/share/xml/docbook/stylesheet/opensuse2013-ns
endif

# TO DO: check if VERSION is still necessary
ifndef VERSION
  VERSION := unreleased
endif

# TO DO: check if DATE is still necessary
ifndef DATE
  DATE := $(shell date +%Y-%0m-%0d)
endif

# Allows for DocBook profiling (hiding/showing some text).
# TO DO: check if still necessary
LIFECYCLE_VALID := beta pre maintained unmaintained
ifndef LIFECYCLE
  LIFECYCLE := maintained
endif
ifneq "$(LIFECYCLE)" "$(filter $(LIFECYCLE),$(LIFECYCLE_VALID))"
  override LIFECYCLE := maintained
endif

# Gets the language code: release-notes.en.xml => en
DAPS_COMMAND_BASIC = daps -vv  
DAPS_COMMAND = $(DAPS_COMMAND_BASIC) -d 

ITSTOOL = itstool -i /usr/share/itstool/its/docbook5.its

XSLTPROC_COMMAND = xsltproc \
--stringparam generate.toc "book toc" \
--stringparam generate.section.toc.level 0 \
--stringparam section.autolabel 1 \
--stringparam section.label.includes.component.label 2 \
--stringparam variablelist.as.blocks 1 \
--stringparam toc.max.depth 3 \
--stringparam show.comments 0 \
--xinclude --nonet

# Fetch correct Report Bug link values, so translations get the correct
# version
XPATHPREFIX := //*[local-name()='docmanager']/*[local-name()='bugtracker']/*[local-name()
URL = `xmllint --noent --xpath "$(XPATHPREFIX)='url']/text()" xml/release-notes.xml`
PRODUCT = `xmllint --noent --xpath "$(XPATHPREFIX)='product']/text()" xml/release-notes.xml`
COMPONENT = `xmllint --noent --xpath "$(XPATHPREFIX)='component']/text()" xml/release-notes.xml`
ASSIGNEE = `xmllint --noent --xpath "$(XPATHPREFIX)='assignee']/text()" xml/release-notes.xml`


all:
	@echo -ne "SELECTED_SOURCES: $(SELECTED_SOURCES)\n\nSELECTED_XML_FILES: $(SELECTED_XML_FILES)\n\nSELECTED_ENT_FILES: $(SELECTED_ENT_FILES)\n\nSELECTED_DOMAIN_LIST: $(SELECTED_DOMAIN_LIST)"

<<<<<<< HEAD
linguas:
	echo $(LANGS)

LINGUAS: $(PO_FILES) 50-tools/po-selector
	50-tools/po-selector

# Depending on the selected books, find the necessary sources
XML_SOURCES_PER_DC:
	@echo "Finding XML sources of books selected for translation..."; \
	for DC_FILE in $(BOOKS_TO_TRANSLATE); do \
	for SOURCE_FILE in $$(daps -d $$DC_FILE list-srcfiles); do \
	echo $$SOURCE_FILE | grep -q '/xml/'; \
	if [ $${PIPESTATUS[2]} -eq "0" ]; \
	then echo "xml/$$(basename $$SOURCE_FILE)"; \
	fi; \
	done; \
	done | sort | uniq > XML_SOURCES_PER_DC

pot: $(POT_FILES)
<<<<<<< HEAD
<<<<<<< HEAD
<<<<<<< HEAD
<<<<<<< HEAD
<<<<<<< HEAD
<<<<<<< HEAD
<<<<<<< HEAD
<<<<<<< HEAD
$(POT_FILES): $(SOURCE_FILES) xml/release-notes.ent
=======
$(POT_FILES): $(SOURCE_FILES)
>>>>>>> f6aed2adc... Update Makefile
	$(DAPS_COMMAND_BASIC) -m $(XML_SOURCE) validate
=======
$(POT_FILES): $(SOURCE_FILES)
#	$(DAPS_COMMAND_BASIC) -m $(XML_SOURCE) validate
>>>>>>> cb00f3883... Add .pot and .po files
=======
$(POT_FILES): $(XML_SOURCE_FILES)
>>>>>>> 29f34e64f... Modified Makefile
	$(ITSTOOL) -o $@ $(XML_SOURCE)
=======
$(POT_FILES): $(XML_SOURCE)
	$(ITSTOOL) -o $@ $<
>>>>>>> 8a3e6d198... Fixed prereqs
=======
$(POT_FILES): $(XML_SOURCE_FILES)
	$(ITSTOOL) -o $@ $(XML_SOURCE)
>>>>>>> 19b511832... Update Makefile
=======
pot/%.pot: xml/*.xml
=======
50-pot/%.pot: xml/*.xml
>>>>>>> 6e0e918ef... Update Makefile
=======
=======
pot: $(FULL_POT_LIST)
>>>>>>> 7afed8486... Changed variable names
50-pot/%.pot: xml/%.xml
>>>>>>> c761a300d... Update Makefile
	$(ITSTOOL) -o $@ $<
>>>>>>> b61fec7df... Update Makefile

po: $(FULL_PO_LIST)

define update_po
 $(1)/po/%.$(1).po: 50-pot/%.pot
	if [ -r $$@ ]; then \
	msgmerge  --previous --update $$@ $$<; \
	else \
	msgen -o $$@ $$<; \
	fi
endef   

$(foreach LANG,$(FULL_LANG_LIST),$(eval $(call update_po,$(LANG))))

mo: $(MO_FILES)
%.mo: %.po
	msgfmt $< -o $@

# FIXME: Enable use of its:translate attribute in GeekoDoc/DocBook...
translate: $(XML_DEST_FILES) $(SCHEMAS_XML_DEST_FILES) $(ENT_DEST_FILES) $(DC_DEST_FILES)

define translate_xml
 $(1)/xml/%.xml: $(1)/po/%.$(1).mo xml/%.xml
	if [ ! -d $$(@D) ]; then mkdir -p $$(@D); fi
	$$(ITSTOOL) -m $$< -o $$(@D) $$(filter %.xml,$$^)
#	sed -i -r \
#	  -e 's_\t+_ _' -e 's_\s+$$__' \
#	  $@.0
#	xsltproc \
#	  --stringparam 'version' "$(VERSION)" \
#	  --stringparam 'dmurl' "$(URL)" \
#	  --stringparam 'dmproduct' "$(PRODUCT)" \
#	  --stringparam 'dmcomponent' "$(COMPONENT)" \
#	  --stringparam 'dmassignee' "$(ASSIGNEE)" \
#	  --stringparam 'date' "$(DATE)" \
#	  fix-up.xsl $@.0 \
#	  > $@
#	rm $@.0
	daps-xmlformat -i $$@
#	$(DAPS_COMMAND_BASIC) -m $@ validate

 %/xml/schemas.xml: xml/schemas.xml
	ln -sf ../../$$< $$(@D)
	
 $(1)/xml/%.ent: xml/%.ent
	ln -sf ../../$$< $$(@D)

 $$(DC_DEST_FILES): $(1)/%: %
	cp $$< $$(@D)
endef

$(foreach LANG,$(LANGS),$(eval $(call translate_xml,$(LANG))))

validate: $(DC_DEST_FILES)
	for DC_FILE in $^; do \
	$(DAPS_COMMAND) $$DC_FILE validate; \
	done; 

translatedxml: xml/release-notes.xml xml/release-notes.ent $(XML_FILES)
	xsltproc \
	  --stringparam 'version' "$(VERSION)" \
	  --stringparam 'dmurl' "$(URL)" \
	  --stringparam 'dmproduct' "$(PRODUCT)" \
	  --stringparam 'dmcomponent' "$(COMPONENT)" \
	  --stringparam 'dmassignee' "$(ASSIGNEE)" \
	  --stringparam 'date' "$(DATE)" \
	  fix-up.xsl $< \
	  > xml/release-notes.en.xml

pdf: $(PDF_FILES)
$(PDF_FILES): translatedxml
	lang=$(LANG_COMMAND) ; \
	$(DAPS_COMMAND) pdf PROFCONDITION="general\;$(LIFECYCLE)"

single-html: $(SINGLE_HTML_FILES)
$(SINGLE_HTML_FILES): translatedxml
	lang=$(LANG_COMMAND) ; \
	$(DAPS_COMMAND) html --single \
	--stringparam "homepage='https://www.opensuse.org'" \
	PROFCONDITION="general\;$(LIFECYCLE)"

text: $(TXT_FILES)
$(TXT_FILES): translatedxml
	lang=$(LANG_COMMAND) ; \
	LANG=$${lang} $(DAPS_COMMAND) text \
	PROFCONDITION="general\;$(LIFECYCLE)"

clean_po_temp:
	rm -rf $(foreach LANG,$(LANG_LIST),$(addprefix $(LANG),/po/*.po~))
	
clean_mo:
	rm -rf $(FULL_MO_LIST)

clean_pot:
	rm -rf $(FULL_POT_LIST)
	
clean: clean_po_temp clean_mo clean_pot
	rm -rf $(foreach LANG,$(FULL_LANG_LIST),$(addprefix $(LANG),/xml/)) build/
