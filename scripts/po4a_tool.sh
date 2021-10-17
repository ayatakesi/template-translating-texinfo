#!/bin/bash

function main () {
    COMMAND=${1};
    REPOSITORY_ROOT="$(realpath $(dirname ${BASH_SOURCE})/..)";
    SCRIPT_ROOT=${REPOSITORY_ROOT}/scripts;

    PO_ROOT=${REPOSITORY_ROOT}/po;
    PO4A_ROOT=${PO_ROOT}/po4a;

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
		POT_DIRECTORY=${PO4A_ROOT}/${TEXI_FOLDER}/C;
		[ -d ${POT_DIRECTORY} ] || mkdir -p ${POT_DIRECTORY};
		cd ${POT_DIRECTORY};
		ORIGINAL_TEXI=$(realpath --relative-to . ${TEXI_FILE});
		POT_FILE=$(basename ${TEXI_FILE}).po;
		
		echo -n "Generating ${POT_DIRECTORY}/${POT_FILE} ... ";
		po4a-gettextize -M utf8 \
				-L utf8 \
				-f texinfo \
				-d -v \
				-m ${ORIGINAL_TEXI} |
		    sed 's/CHARSET/UTF-8/' |
		    msgcat --no-wrap - > ./${POT_FILE};
		echo "done.";
		cd ${REPOSITORY_ROOT};
		
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
			    POT_FILE=${PO4A_ROOT}/${TEXI_FOLDER}/C/${TEXI_NAME}.po;
			    PO_FILE=${PO4A_ROOT}/${TEXI_FOLDER}/${LINGUA}/${TEXI_NAME}.po;
			    echo -n "Copying ${POT_FILE} to ${PO_FILE} ... "
			    [ -d ${PO4A_ROOT}/${TEXI_FOLDER}/${LINGUA} ] || mkdir -p ${PO4A_ROOT}/${TEXI_FOLDER}/${LINGUA};
			    cp -pf ${POT_FILE} ${PO_FILE};
			    echo "done.";
			    ;;

			"translate")
			    TRANSLATED_ROOT=${REPOSITORY_ROOT}/translated;
			    TRANSLATED_DIRECTORY=${TRANSLATED_ROOT}/${TEXI_FOLDER}/${LINGUA};

			    TEXI_NAME=$(basename ${TEXI_FILE});
			    PO_FILE=${PO4A_ROOT}/${TEXI_FOLDER}/${LINGUA}/${TEXI_NAME}.po;
			    TRANSLATED_TEXI=${TRANSLATED_DIRECTORY}/${TEXI_NAME};

			    echo -n "Translating ${TEXI_FILE} to ${TRANSLATED_TEXI} with ${PO_FILE} ... ";
			    [ -d ${TRANSLATED_DIRECTORY} ] || mkdir -p ${TRANSLATED_DIRECTORY};
			    po4a-translate -f texinfo \
					   -k 0 \
					   -M utf8 \
					   -m ${TEXI_FILE} \
					   -p ${PO_FILE} \
					   -l ${TRANSLATED_TEXI};
			    echo "done.";
			    ;;

			"msgmerge")
			    # Precisely, update pot that contains new msgid
			    #  with po that contains translated msgstr
			    #  for existing msgid.
			    TEXI_NAME=$(basename ${TEXI_FILE});
			    NEW_POT_FILE=${PO4A_ROOT}/${TEXI_FOLDER}/C/${TEXI_NAME}.po;
			    OLD_PO_FILE=${PO4A_ROOT}/${TEXI_FOLDER}/${LINGUA}/${TEXI_NAME}.po;
			    MERGED_PO=$(mktemp);

			    echo -n "UPDATE ${OLD_PO_FILE} with msgid of ${NEW_POT_FILE} and msgstr of ${OLD_PO_FILE} ... "
			    msgmerge --previous \
				     --compendium ${OLD_PO_FILE} \
				     --output - \
				     /dev/null ${NEW_POT_FILE} |
				msgcat --no-wrap - > ${MERGED_PO};
			    
			    cp -pf ${MERGED_PO} ${OLD_PO_FILE};
			    rm -f ${MERGED_PO};
			    echo "done.";
			    ;;
			
		    esac
		    
		done <"./LINGUAS"
	    fi
	done
    done <"./TEXI_FOLDERS"
}    

main "$@";
