#!/bin/bash

function main () {
    COMMAND=${1};
    REPOSITORY_ROOT="$(realpath $(dirname ${BASH_SOURCE})/..)";
    SCRIPT_ROOT=${REPOSITORY_ROOT}/scripts;

    PO_ROOT=${REPOSITORY_ROOT}/po;
    GETTEXT_ROOT=${PO_ROOT}/gettext;

    cd ${REPOSITORY_ROOT};
    while read TEXI_FOLDER
    do
	if [ "${TEXI_FOLDER}"x == x ] ||
	       [ $(echo ${TEXI_FOLDER} | cut -b -1) == '#' ]
	then
	    continue;
	fi

	for TEXI_FILE in ${REPOSITORY_ROOT}/${TEXI_FOLDER}/*.texi
	do
	    if [ "${TEXI_FILE}"x == x ] ||
		   [ $(echo ${TEXI_FILE} | cut -b -1) == '#' ]
	    then
		continue;
	    fi
	    
	    if [ ${COMMAND} == "gettextize" ]
	    then
		GREP_STRING='^@((chapter)|((sub)*(section))|(appendix)(sub)*(sec)?)';
		TEXI_FILE=$(realpath --relative-to ${REPOSITORY_ROOT} ${TEXI_FILE});
		[ -d ${GETTEXT_ROOT}/${TEXI_FOLDER} ] || mkdir -p ${GETTEXT_ROOT}/${TEXI_FOLDER};
		TEXTDOMAIN_DIRECTORY=$(realpath --relative-to ${REPOSITORY_ROOT} ${GETTEXT_ROOT}/${TEXI_FOLDER});
		
		POT_DIRECTORY=${TEXTDOMAIN_DIRECTORY}/C/LC_MESSAGES;
		[ -d ${POT_DIRECTORY} ] || mkdir -p ${POT_DIRECTORY};
		
		[ -d ${SCRIPT_ROOT}/${TEXI_FOLDER} ] || mkdir -p ${SCRIPT_ROOT}/${TEXI_FOLDER};
		SCRIPT_DIRECTORY=$(realpath --relative-to ${REPOSITORY_ROOT} ${SCRIPT_ROOT}/${TEXI_FOLDER});

		generate_gettext_pot ${TEXI_FILE} \
				     ${POT_DIRECTORY} \
				     ${GREP_STRING};
		
		generate_gettext_filter ${TEXI_FILE} \
					${SCRIPT_DIRECTORY} \
					${GREP_STRING} \
					${TEXTDOMAIN_DIRECTORY};

	    else
		while read LINGUA
		do
		    if [ "${LINGUA}"x == x ] ||
			   [ $(echo ${LINGUA} | cut -b -1) == '#' ]
		    then
			continue;
		    fi
		    
		    case ${COMMAND} in
			"msginit")
			    TEXI_NAME=$(basename ${TEXI_FILE});
			    POT_FILE=${GETTEXT_ROOT}/${TEXI_FOLDER}/C/LC_MESSAGES/${TEXI_NAME}.po;
			    PO_FILE=${GETTEXT_ROOT}/${TEXI_FOLDER}/${LINGUA}/LC_MESSAGES/${TEXI_NAME}.po;
			    echo -n "Copying ${POT_FILE} to ${PO_FILE} ... "
			    [ -d ${GETTEXT_ROOT}/${TEXI_FOLDER}/${LINGUA}/LC_MESSAGES ] ||
				mkdir -p ${GETTEXT_ROOT}/${TEXI_FOLDER}/${LINGUA}/LC_MESSAGES;
			    cp -pf ${POT_FILE} ${PO_FILE};
			    echo "done.";
			    ;;

			"translate")
			    TEXI_PATH=$(dirname ${TEXI_FILE});
			    TEXI_NAME=$(basename ${TEXI_FILE});
			    PO_DIRECTORY=${GETTEXT_ROOT}/${TEXI_FOLDER}/${LINGUA}/LC_MESSAGES;
			    PO_FILE=${PO_DIRECTORY}/${TEXI_NAME}.po;
			    TRANSLATED_ROOT=${REPOSITORY_ROOT}/translated;
			    TRANSLATED_FOLDER=${TRANSLATED_ROOT}/${TEXI_FOLDER}/${LINGUA};
			    [ -d  ${TRANSLATED_FOLDER} ] || mkdir -p ${TRANSLATED_FOLDER};
			    TRANSLATED_TEXI=${TRANSLATED_FOLDER}/${TEXI_NAME};
			    SCRIPT_DIRECTORY=$(realpath --relative-to ${REPOSITORY_ROOT} ${SCRIPT_ROOT}/${TEXI_FOLDER});
			    PERL_FILTER=${SCRIPT_DIRECTORY}/${TEXI_NAME}.pl;

			    echo -n "Translate ${TEXI_FILE} to ${TRANSLATED_TEXI} ... ";
			    msgfmt -o ${PO_DIRECTORY}/${TEXI_NAME}.mo ${PO_FILE};
			    TEMP_TEXI=$(mktemp);
			    
			    cat ${TRANSLATED_TEXI} |
				LANGUAGE=${LINGUA} ${PERL_FILTER} >${TEMP_TEXI};
			    cat ${TEMP_TEXI} >${TRANSLATED_TEXI};
			    rm -f ${TEMP_TEXI};
			    echo "done.";
			    ;;

			"msgmerge")
			    # Precisely, update pot that contains new msgid
			    #  with po that contains translated msgstr
			    #  for existing msgid.
			    TEXI_NAME=$(basename ${TEXI_FILE});
			    NEW_POT_FILE=${GETTEXT_ROOT}/${TEXI_FOLDER}/C/LC_MESSAGES/${TEXI_NAME}.po;
			    OLD_PO_FILE=${GETTEXT_ROOT}/${TEXI_FOLDER}/${LINGUA}/LC_MESSAGES/${TEXI_NAME}.po;
			    MERGED_PO=$(mktemp);

			    echo -n "UPDATE ${OLD_PO_FILE} with msgid of ${NEW_POT_FILE} and msgstr of ${OLD_PO_FILE} ... "
			    msgmerge --previous \
				     --compendium ${OLD_PO_FILE} \
				     --output - \
				     /dev/null ${NEW_POT_FILE} |
				msgcat --no-wrap - > ${MERGED_PO};
			    
A			    cp -pf ${MERGED_PO} ${OLD_PO_FILE};
			    rm -f ${MERGED_PO};
			    echo "done.";
			    ;;
			
		    esac
		    
		done <"./LINGUAS"
	    fi
	done
    done <"./TEXI_FOLDERS"
}    

function generate_gettext_filter () {
    TEXI_FILE=${1};
    SCRIPT_DIRECTORY=${2};
    GREP_STRING=${3};
    TEXTDOMAIN_DIRECTORY=${4};

    TEXI_NAME=$(basename ${TEXI_FILE});
    SCRIPT_NAME=${TEXI_NAME}.pl;
    SCRIPT_FILE=${SCRIPT_DIRECTORY}/${SCRIPT_NAME};

    echo -n "Generating ${SCRIPT_FILE} ... ";
    cat <<EOT >${SCRIPT_FILE}
#!/usr/bin/perl
# This script requires libintl-perl(>=1.09).
use Locale::TextDomain ("${TEXI_NAME}" => "./${TEXTDOMAIN_DIRECTORY}");
my (\$en, \$ja);
while (<>) {
EOT
    grep -E ${GREP_STRING} ${TEXI_FILE} | sort | uniq |
 	sed -r "s/'/\\\'/g" |
	sed -r "s|(.+)$|\t\(\$en, \$ja\) = \(quotemeta\('&'\), __ '&'\); s/\$en/\$ja/;|" >>${SCRIPT_FILE};
    printf "\tprint;\n}" >>${SCRIPT_FILE};
    chmod a+x ${SCRIPT_FILE};
    echo "done";
    
    return;
}

function generate_gettext_pot () {
    TEXI_FILE=${1};
    POT_DIRECTORY=${2};
    GREP_STRING=${3};
    
    TEXI_NAME=$(basename ${TEXI_FILE});
    POT_NAME=${TEXI_NAME}.po;
    POT_FILE=${POT_DIRECTORY}/${POT_NAME};
    
    DATE_STRING=$(date '+%Y-%m-%d %H:%M');

    echo -n "Generating ${POT_FILE} ... ";
    cat <<EOT > ${POT_FILE}
msgid ""
msgstr ""
"Project-Id-Version: XXXX-XX.X\n"
"POT-Creation-Date: ${DATE_STRING}\n"
"PO-Revision-Date: ${DATE_STRING}\n"
"Last-Translator: XXXX#translator\n"
"Language-Team: XXXX#translators\n"
"Language: ja\n"
"MIME-Version: 1.0\n"
"Content-Type: text/plain; charset=UTF-8\n"
"Content-Transfer-Encoding: 8bit\n"

EOT
    grep -E ${GREP_STRING} ${TEXI_FILE} |
	perl -pe 's/\"/\\\"/g' | sort | uniq |
	perl -ne 'chomp; print "msgid \"$_\"\nmsgstr \"\"\n\n";' >>${POT_FILE};
    echo "done";
    
    return;
}

main "$@";
