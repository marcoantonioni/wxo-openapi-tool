#!/bin/bash

#------------------------------------------------------

_INPUT_FILE=""
_OUTPUT_FILE=""
_SECURITY="all"
_OUTPUT_SUMMARY_DESC=""
_INPUT_SUMMARY_DESC=""
_GEN_SD_ONLY=false
_PREFIX=""

_DESCRIPTION=""
_SUMMARY=""
_INTENTS=""
_TEXT_SUMM_DES=""

#--------------------------------------------------------
_me=$(basename "$0")

CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"


#--------------------------------------------------------
_CLR_RED="\033[0;31m"   #'0;31' is Red's ANSI color code
_CLR_GREEN="\033[0;32m"   #'0;32' is Green's ANSI color code
_CLR_YELLOW="\033[1;32m"   #'1;32' is Yellow's ANSI color code
_CLR_BLUE="\033[0;34m"   #'0;34' is Blue's ANSI color code
_CLR_NC="\033[0m"

usage () {
  echo ""
  echo -e "${_CLR_GREEN}usage: $_me
    -i input-openapi-file
        (eg: './services/test-openapi.json')
    -o output-openapi-file
        (eg: './output/adapted-openapi.json')
    -s (optional, all is default) select-security-type [basic|zen|all]
    -g (optional) generate properties structure for api operations [summary+description]
    -d (optional) properties-file for api summaries and descriptions 
    -k (optional) your-unique-id is used ad prefix for skills identification
    ${_CLR_NC}"
}

#--------------------------------------------------------
# read command line params
while getopts i:o:s:g:k:d: flag
do
    case "${flag}" in
        i) _INPUT_FILE=${OPTARG};;
        o) _OUTPUT_FILE=${OPTARG};;
        s) _SECURITY=${OPTARG};;
        g) _OUTPUT_SUMMARY_DESC=${OPTARG};;
        d) _INPUT_SUMMARY_DESC=${OPTARG};;
        k) _PREFIX=${OPTARG};;
        \?) # Invalid option
            usage
            exit 1;;        
    esac
done

if [[ -z "${_OUTPUT_SUMMARY_DESC}" ]]; then
  if [[ -z "${_INPUT_FILE}" ]] || [[ -z "${_OUTPUT_FILE}" ]]; then
    usage
    exit 1
  fi
  if [[ ! -f "${_INPUT_FILE}" ]]; then
    echo "Input openapi file not found: "${_INPUT_FILE}
    usage
    exit 1
  fi
  echo "Generate adapted api in file ${_OUTPUT_FILE}"
else
  echo "Generate properties structure for api operations in file ${_OUTPUT_SUMMARY_DESC}"
  _GEN_SD_ONLY=true
fi

#------------------------------------------------------
createSnippetInfo() {
  _input=$1
  _descr=$2
  _output=$3
  cat ${_input} | jq --arg param "$_descr" '.info + {description: $param}' > ${_output}
}

updateInfo() {
  _input=$1
  _info=$2
  _output=$3
  cat ${_input} | jq --arg param "$_info" '. + {info: $param}' > ${_output}
}

createSnippetPath() {
  _input=$1
  _summary=$2
  _descr=$3
  _output=$4
  _FILE_TMP="/tmp/wxo-openapi-$USER-$RANDOM"
  cat ${_input} | jq --arg param "$_summary" '.paths + {summary: $param}' > ${_FILE_TMP}
  cat ${_FILE_TMP} | jq --arg param "$_descr" '. + {description: $param}' > ${_output}
  rm ${_FILE_TMP}
}

updateSnippetPaths() {
  _FILE_IN=$1
  _FILE_IN_PATHS=$2
  _FILE_TMP_SNIPPET_PATHS="/tmp/wxo-openapi-sp-$USER-$RANDOM"

  echo "{" > ${_FILE_TMP_SNIPPET_PATHS}
  _paths=()
  _line=$(cat ${_FILE_IN_PATHS} | jq '. | to_entries[] | select(.key | startswith("/"))' | jq .key | sed 's/"//g')
  for i in $_line; do _paths+=($i) ; done
  _totPaths=${#_paths[*]}
  _idx=0
  for _path in "${_paths[@]}"
  do
    _tmpName="${_path///}"

    _sum=$(echo "${_TEXT_SUMM_DES}" | grep "$_tmpName.summary" | sed 's/.*summary=//g')
    _des=$(echo "${_TEXT_SUMM_DES}" | grep "$_tmpName.description" | sed 's/.*description=//g')
    _ints=$(echo "${_TEXT_SUMM_DES}" | grep "$_tmpName.intents" | sed 's/.*intents=//g')

    if [[ -z "$_des" ]]; then
      _DESCRIPTION="Description for $_tmpName"
    else
      _DESCRIPTION="$_des"
    fi
    
    if [[ -z "$_sum" ]]; then
      _SUMMARY="Summary for $_tmpName"
    else
      _SUMMARY="$_sum"
    fi

    if [[ -z "$_ints" ]]; then
      _INTENTS="run $_tmpName"
    else
      _INTENTS=$(echo "$_ints" | sed 's/,[ \t]*/,/g' | sed 's/^[ \t]*//g' | sed 's/[ \t]*$//g')
    fi

    _FILE_TMP_SNIPPET_ITEM="/tmp/wxo-openapi-sp-$_tmpName-$USER-$RANDOM"
    cat ${_FILE_IN_PATHS} | sed 's#"'$_path'#"'$_tmpName'#g' \
     | jq .$_tmpName.post | jq --arg param "${_PREFIX} ${_SUMMARY}" '. + {summary: $param}' \
     | jq --arg param "${_PREFIX} ${_DESCRIPTION}" '. + {description: $param}' \
     | jq --arg param "${_INTENTS}" '. + {"x-ibm-nl-intent-examples": ($param|split(","))}' > ${_FILE_TMP_SNIPPET_ITEM}

    echo '"'$_path'" : {
        "post" :' >> ${_FILE_TMP_SNIPPET_PATHS}
    cat ${_FILE_TMP_SNIPPET_ITEM} >> ${_FILE_TMP_SNIPPET_PATHS}
    rm ${_FILE_TMP_SNIPPET_ITEM}
    echo "}" >> ${_FILE_TMP_SNIPPET_PATHS}
    ((_idx=$_idx+1))
    if [[ $_idx -lt $_totPaths ]]; then
      echo "," >> ${_FILE_TMP_SNIPPET_PATHS}
    fi
  done
  echo "}" >> ${_FILE_TMP_SNIPPET_PATHS}
  _PATH_UPDATED=$(cat ${_FILE_TMP_SNIPPET_PATHS})

  rm ${_FILE_TMP_SNIPPET_PATHS}

  _FILE_TMP_1=_tmp1.json
  _FILE_TMP_2=_tmp_wxo-service.json
  cat ${_FILE_IN} | jq --arg param {} '. + {paths: $param}' > ${_FILE_TMP_1}
  cat ${_FILE_TMP_1} | jq --arg param "${_PATH_UPDATED}" '. + {paths: $param}' > ${_FILE_TMP_2}
  cat ${_FILE_TMP_2} | sed 's/\\n//g' | sed 's/\\"/"/g' | sed 's/"{/{/g' | sed 's/}"/}/g' | jq . > ${_OUTPUT_FILE}
  rm ${_FILE_TMP_2}
  rm ${_FILE_TMP_1}

}

updateSecurity() {
  _OK=0
  if [[ "${_SECURITY}" = "all" ]]; then
    echo "Security authentication modes untouched."
  else
    if [[ "${_SECURITY}" = "basic" ]]; then
      echo "Security authentication mode: basic"
      _OK=1
    else
      if [[ "${_SECURITY}" = "zen" ]]; then
        echo "Security authentication mode: zen"
        _OK=2
      else
        echo "Security authentication mode unknown: ${_SECURITY}"
      fi
    fi
  fi

  if [[ $_OK -gt 0 ]]; then
    _KEY="basic_auth"
    if [[ $_OK -eq 2 ]]; then
      _KEY="zen_api_key"
    fi
    _FILE_SEC_SCHEMA="/tmp/wxo-openapi-secschema-$USER-$RANDOM"
    _FILE_UPD_SCHEMA="/tmp/wxo-openapi-upd-secschema-$USER-$RANDOM"

    cat ${_OUTPUT_FILE} | jq .components.securitySchemes.$_KEY > ${_FILE_SEC_SCHEMA}
    _snippetSchema=$(cat ${_FILE_SEC_SCHEMA})
    _snippetSchema='{"'$_KEY'" : '$_snippetSchema"}"

    cat ${_OUTPUT_FILE} | jq --arg param "$_snippetSchema" '.components + {securitySchemes: $param}' > ${_FILE_UPD_SCHEMA}
    _snippetComponents=$(cat ${_FILE_UPD_SCHEMA} | sed 's/\\n//g' | sed 's/\\"/"/g' | sed 's/"{/{/g' | sed 's/}"/}/g')

    cat ${_OUTPUT_FILE} | jq --arg param "$_snippetComponents" '. + {components: $param}' > ${_FILE_UPD_SCHEMA}
    cat ${_FILE_UPD_SCHEMA} | sed 's/\\n//g' | sed 's/\\"/"/g' | sed 's/"{/{/g' | sed 's/}"/}/g' | jq . > ${_OUTPUT_FILE}

    rm ${_FILE_SEC_SCHEMA}
    rm ${_FILE_UPD_SCHEMA}
  fi
}

#------------------------------------------------------
adaptOpenapi() {

  if [[ ! -z "${_INPUT_SUMMARY_DESC}" ]]; then
    _TEXT_SUMM_DES=$(cat ${_INPUT_SUMMARY_DESC})
  fi

  _FILE_INFO="/tmp/wxo-openapi-$USER-$RANDOM"
  _FILE_TMP_PATHS="/tmp/wxo-temp-pat-$USER-$RANDOM.json"
  _FILE_TMP_OUT="/tmp/wxo-temp-out-$USER-$RANDOM.json"

  _des=$(echo "${_TEXT_SUMM_DES}" | grep "openapi.description" | sed 's/openapi.description=//g' | sed 's/^[ \t]*//g' | sed 's/[ \t]*$//g')
  if [[ -z "$_des" ]]; then
    _DESCRIPTION="n/a"
  else
    _DESCRIPTION="$_des"
  fi

  createSnippetInfo ${_INPUT_FILE} "${_DESCRIPTION}" "${_FILE_INFO}"
  _INFO=$(cat ${_FILE_INFO})

  updateInfo ${_INPUT_FILE} "${_INFO}" "${_FILE_INFO}"
  cat ${_FILE_INFO} | sed 's/\\n//g' | sed 's/\\"/"/g' | sed 's/"{/{/g' | sed 's/}"/}/g' > ${_FILE_TMP_OUT}

  createSnippetPath ${_FILE_TMP_OUT} "${_PREFIX} ${_SUMMARY}" "${_PREFIX} ${_DESCRIPTION}" ${_FILE_TMP_PATHS}

  updateSnippetPaths ${_FILE_TMP_OUT} ${_FILE_TMP_PATHS}

  if [[ ! -z "${_SECURITY}" ]]; then
    updateSecurity
  fi

  rm ${_FILE_TMP_OUT}
  rm ${_FILE_TMP_PATHS}
  rm ${_FILE_INFO}
}

#------------------------------------------------------
generateSummaryAndDescription() {
  _buff=$(cat ${_INPUT_FILE} | jq .paths | jq '. | to_entries[] | select(.key | startswith("/"))' | jq .key | sed 's/"//g')

  _paths=()
  for i in $_buff; do _paths+=($i) ; done
  _totPaths=${#_paths[*]}
  _idx=0
  echo "#==============================================================" > ${_OUTPUT_SUMMARY_DESC}
  echo "# Summaries and descriptions for file ${_INPUT_FILE}" >> ${_OUTPUT_SUMMARY_DESC}
  echo "# The summary text is part of skill name in watsonx Orchestrate" >> ${_OUTPUT_SUMMARY_DESC}
  echo "# For 'intents' values add a comma separated list of phrases" >> ${_OUTPUT_SUMMARY_DESC}
  echo "" >> ${_OUTPUT_SUMMARY_DESC}
  echo "" >> ${_OUTPUT_SUMMARY_DESC}
  echo "openapi.description=" >> ${_OUTPUT_SUMMARY_DESC}
  echo "" >> ${_OUTPUT_SUMMARY_DESC}

  for _path in "${_paths[@]}"
  do
    _tmpName="${_path///}"
    echo "# $_tmpName" >> ${_OUTPUT_SUMMARY_DESC}
    echo "$_tmpName.summary=" >> ${_OUTPUT_SUMMARY_DESC}
    echo "$_tmpName.description=" >> ${_OUTPUT_SUMMARY_DESC}
    echo "$_tmpName.intents=" >> ${_OUTPUT_SUMMARY_DESC}
    echo "" >> ${_OUTPUT_SUMMARY_DESC}
  done
}

#======================================================
# MAIN
#======================================================

if [[ "${_GEN_SD_ONLY}" = "true" ]]; then
  generateSummaryAndDescription
else
  adaptOpenapi
fi