#!/bin/bash

usage() {
	echo '
This script is used for cleaning up Elasticsearch indices.
Please update your Elasticsearch credentials in this script

Usage: ./cleanup.sh {o} {url} {index} {days}

Example: 
  ./cleanup.sh -d http://localhost:9200 .management-beats 
  ./cleanup.sh -r http://localhost:9200 chat 15

Options:
  -d | --delete     Delete an entire index
  -r | --retain     Query an index back in time, output logs?? 
'
}

log() {
	local level=$1
	local data=$2
	echo -e '["'$level'"]  "'$data'"\n'
}

if [ $# -lt 3 ]; then
	log 'ERROR' 'Must provide at least three arguments'
	usage && exit -1
fi

user=elastic
pass=changeme

option=$1
esURL=$2
indexName=$3
secondsSinceEpoch=$(date +%s)
curlArgs=(-o /dev/null -s -w "%{http_code}\n" -u $user:$pass -I)

if [[ $option =~ ^(-d|--delete|-r|--retain)$ ]]; then
	case "$option" in
	"-d" | "--delete")
		if [ $# -gt 3 ]; then
			log 'INFO' 'Provided too many args... Ignoring "'$4'"'
		fi
		responseCode=$(curl ${curlArgs[@]} -X HEAD "$esURL/$indexName")
		case $responseCode in
		200)
			responseCode=$(curl ${curlArgs[@]} -X DELETE "$esURL/$indexName")
			if [ $responseCode -eq 200 ]; then
				log 'INFO' 'Index ("'$indexName'") has been deleted'
			fi
			;;
		401)
			log 'ERROR' 'Unauthorized request, please adjust the credentials in this script'
			exit -1
			;;
		404)
			log 'ERROR' 'Index ("'$indexName'") does not exist'
			exit -1
			;;
		*)
			log 'ERROR' 'Uh oh, not sure what happened: "'$responseCode'"'
			;;
		esac
		;;
	"-r" | "--retain")
		if [ $# -lt 4 ]; then
			log 'ERROR' 'Expecting four parameter; missing days to retain'
			usage && exit -1
		fi
		days=$4
		pre_date=$(date -u +'%Y-%m-%dT%H:%M:%S.%3NZ' -d "-$days days")
		post_date=$(date -u +'%Y-%m-%dT%H:%M:%S.%3NZ')
		responseCode=$(curl ${curlArgs[@]} -X HEAD "$esURL/$indexName")
		case $responseCode in
		200)
			# TODO: check amount of hits so we get everything or doc count?
			log 'INFO' 'Retaining time...'
			res=$(
				curl -f -X GET -s -u $user:$pass -H "Content-Type: application/json" \
					-d '{"query":{"range":{"@timestamp":{"gt":'\"${pre_date}\"',"lt":'\"${post_date}\"'}}}}' \
					"$esURL/$indexName/_search?size=10000"
			)
			if [[ ! $res ]]; then
				log 'ERROR' 'Query by date failed'
				exit -1
			fi
			# TODO: feature: have the ability to push to s3?
			echo $res | jq '.hits.hits | .[]' >>"$indexName.$post_date.json"
			log 'INFO' 'Written all query hits to "'$indexName.$post_date.json'"'
			log 'INFO' 'Deleting all results by the same query'
			res=$(
				curl -f -X POST -s -u $user:$pass -H "Content-Type: application/json" \
					-d '{"query":{"range":{"@timestamp":{"gt":'\"${pre_date}\"',"lt":'\"${post_date}\"'}}}}' \
					"$esURL/$indexName/_delete_by_query"
			)
			if [[ ! $res ]]; then
				log 'ERROR' 'Delete By Query by date failed'
				exit -1
			fi
			log 'INFO' "Deleted $(echo $res | jq '.deleted') hits"
			exit 0
			;;
		401)
			log 'ERROR' 'Unauthorized request, please adjust the credentials in this script'
			exit -1
			;;
		404)
			log 'ERROR' 'Index ("'$indexName'") does not exist'
			exit -1
			;;
		*)
			log 'ERROR' 'Uh oh, not sure what happened: HTTP "'$responseCode'"'
			exit -1
			;;
		esac
		;;
	*)
		log 'ERROR' '"'$option'" is invalid'
		usage && exit -1
		;;
	esac
else
	usage && exit -1
fi
