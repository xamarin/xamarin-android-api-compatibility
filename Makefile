SHELL                 = /usr/bin/env bash
export OS            := $(shell uname)

MONO_API_HTML         = mono-api-html
MONO_API_INFO         = mono-api-info

HTML_OUTPUT_DIR       =

REFERENCE_DIR         = reference

ifeq ($(OS),Darwin)
XA_FRAMEWORK_DIR      = /Library/Frameworks/Xamarin.Android.framework/Libraries/xbuild-frameworks/MonoAndroid
endif # $(OS)=Darwin

ifndef XA_FRAMEWORK_DIR
$(error XA_FRAMEWORK_DIR must be provided.)
endif  # ndef XA_FRAMEWORK_DIR

STABLE_FRAMEWORKS     = $(shell ls -1 "$(XA_FRAMEWORK_DIR)" | sort -n)
LAST_STABLE_FRAMEWORK = $(lastword $(STABLE_FRAMEWORKS))
FIRST_STABLE_FRAMEWORK = $(firstword $(STABLE_FRAMEWORKS))

all: check


clean:


MONO_API_INFO_LIB_DIRS  = \
	-L $(XA_FRAMEWORK_DIR)/$(LAST_STABLE_FRAMEWORK)     \
	-L $(XA_FRAMEWORK_DIR)/v1.0                         \
	-L $(XA_FRAMEWORK_DIR)/v1.0/Facades

BCL_ASSEMBLIES = \
	Microsoft.CSharp                                    \
	Mono.Data.Sqlite                                    \
	Mono.Data.Tds                                       \
	Mono.Posix                                          \
	Mono.Security                                       \
	mscorlib                                            \
	System                                              \
	System.ComponentModel.Composition                   \
	System.ComponentModel.DataAnnotations               \
	System.Core                                         \
	System.Data                                         \
	System.Data.Services.Client                         \
	System.EnterpriseServices                           \
	System.IdentityModel                                \
	System.IO.Compression                               \
	System.IO.Compression.FileSystem                    \
	System.Json                                         \
	System.Net                                          \
	System.Net.Http                                     \
	System.Net.Http.WinHttpHandler                      \
	System.Numerics                                     \
	System.Numerics.Vectors                             \
	System.Reflection.Context                           \
	System.Runtime.Serialization                        \
	System.Security                                     \
	System.ServiceModel                                 \
	System.ServiceModel.Web                             \
	System.Transactions                                 \
	System.Web.Services                                 \
	System.Windows                                      \
	System.Xml                                          \
	System.Xml.Linq                                     \
	System.Xml.Serialization

CORE_ASSEMBLIES = \
	$(BCL_ASSEMBLIES)                                   \
	Java.Interop                                        \
	Xamarin.Android.NUnitLite

TFV_ASSEMBLY = Mono.Android

ACCESSORY_TFV_ASSEMBLIES = \
	Mono.Android.Export                                 \
	OpenTK-1.0

# $(call BUILD_API_INFO,outdir,frameworkDir)
define BUILD_API_INFO
	mkdir -p $(1)
	for file in $(CORE_ASSEMBLIES); do \
		$(MONO_API_INFO) $(MONO_API_INFO_LIB_DIRS) \
			"$(2)/v1.0/$$file.dll" -o=$(1)/$$file.xml & \
	done ; \
	wait
	$(MONO_API_INFO) $(MONO_API_INFO_LIB_DIRS) \
		"$(2)/$(LAST_STABLE_FRAMEWORK)/$(TFV_ASSEMBLY).dll" -o=$(1)/$(TFV_ASSEMBLY).xml & \
	for file in $(ACCESSORY_TFV_ASSEMBLIES) ; do \
		accessoryTfvDir=$(2)/$(FIRST_STABLE_FRAMEWORK); \
		if [ ! -d $$accessoryTfvDir ]; then \
			accessoryTfvDir=$(2)/$(LAST_STABLE_FRAMEWORK); \
		fi; \
		$(MONO_API_INFO) $(MONO_API_INFO_LIB_DIRS) "$$accessoryTfvDir/$$file.dll" -o=$(1)/$$file.xml & \
	done ; \
	wait
endef

check: check-inter-api-level
	$(call BUILD_API_INFO,temp,$(XA_FRAMEWORK_DIR))
	failed=0 ; \
	for file in $(CORE_ASSEMBLIES) $(TFV_ASSEMBLY) $(ACCESSORY_TFV_ASSEMBLIES); do \
		if [ ! -s temp/$$file.xml ]; then \
			echo "temp/$$file.xml was not generated."; \
			failed=1; \
		fi; \
		if $(MONO_API_HTML) $(REFERENCE_DIR)/$$file.xml temp/$$file.xml --ignore-changes-parameter-names --ignore-nonbreaking | grep '\<data-is-breaking>' > /dev/null 2>&1 ; then \
			echo "ABI BREAK IN: $$file.dll" ; \
			$(MONO_API_HTML) $(REFERENCE_DIR)/$$file.xml temp/$$file.xml  --ignore-changes-parameter-names --ignore-nonbreaking \
				$(if $(HTML_OUTPUT_DIR),$(HTML_OUTPUT_DIR)/$$file.html); \
			if [ -n "$(HTML_OUTPUT_DIR)" ] ; then cat "$(HTML_OUTPUT_DIR)/$$file.html" ; fi ; \
			failed=1; \
		fi ; \
	done ; \
	if [ $$failed -ne 0 ]; then \
		exit $$failed ; \
	fi

-create-inter-api-infos:
	for f in $(STABLE_FRAMEWORKS) ; do \
		if [ ! -f "$(XA_FRAMEWORK_DIR)/$$f/Mono.Android.dll" ]; then \
			continue ; \
		fi; \
		if [ "$(XA_FRAMEWORK_DIR)/$$f/Mono.Android.dll" -ot "inter-apis/$$f/Mono.Android.xml" ] ; then \
			continue; \
		fi; \
		mkdir -p "inter-apis/$$f" || true; \
		$(MONO_API_INFO) $(MONO_API_INFO_LIB_DIRS) "$(XA_FRAMEWORK_DIR)/$$f/Mono.Android.dll" -o="inter-apis/$$f/Mono.Android.xml" ; \
	done

check-inter-api-level: -create-inter-api-infos
	failed=0; \
	_frameworks=($(STABLE_FRAMEWORKS)) ; \
	for (( i = 1; i < $${#_frameworks[@]}; i++ )) ; do \
		if [ ! -d "$(XA_FRAMEWORK_DIR)/$${_frameworks[$$i]}" ] ; then \
			echo "# Framework directory '$(XA_FRAMEWORK_DIR)/$${_frameworks[$$i]}' doesn't exist. Skipping..."; \
			continue ; \
		fi; \
		prev_framework=$$(expr $$i - 1); \
		prev="inter-apis/$${_frameworks[$$prev_framework]}/Mono.Android.xml"; \
		cur="inter-apis/$${_frameworks[$$i]}/Mono.Android.xml"; \
		extras_in="inter-api-extra-$${_frameworks[$$prev_framework]}-$${_frameworks[$$i]}.txt" ; \
		echo "# reading extras from: $$extras_in"; \
		extra=`if [ -f $$extras_in ]; then echo @$$extras_in ; fi`; \
		out=`mktemp interdiff-XXXXXX.html` ; \
		command="$(MONO_API_HTML) \"$$prev\" \"$$cur\" --ignore-changes-parameter-names --ignore-changes-virtual --ignore-changes-property-setters --ignore-nonbreaking $$extra"; \
		echo $$command; \
		eval $$command > "$$out" 2>&1; \
		if grep '\<data-is-breaking>' $$out > /dev/null 2>&1 ; then \
			echo "<h1>### API BREAK BETWEEN $${_frameworks[$$prev_framework]} and $${_frameworks[$$i]}</h1>" ; \
			cat $$out; \
			if [ -n "$(HTML_OUTPUT_DIR)" ]; then \
				cat $$out > "$(HTML_OUTPUT_DIR)/Mono.Android-inter-$${_frameworks[$$prev_framework]}-$${_frameworks[$$i]}.html" ; \
			fi; \
			failed=1; \
		fi ; \
		rm $$out; \
	done; \
	exit $$failed


update:
	$(call BUILD_API_INFO,$(REFERENCE_DIR),$(XA_FRAMEWORK_DIR))
