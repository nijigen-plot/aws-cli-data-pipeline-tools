#!/bin/bash

COMMAND=$1;
FUNCTION_NAME=$2;
PAYLOAD=$3;

help() {
    echo
    echo $0 ... aws lambda wrapper command
    echo
    echo "$0 list ... list lambda functions"
    echo "$0 invoke [lambda function name] [json format payload] ... invoke lambda function"
	echo
    exit 1
}

# コマンドがサポートしている文字列で打たれているか
if [ "$COMMAND" != "list" ] && [ "$COMMAND" != "invoke" ]; then
	echo "COMMAND is required as 1st arg: list/invoke";
	help;
fi

# invokeコマンドの場合、次の引数にLambda関数名とPayloadがあるか
if [ "$COMMAND" = "invoke" ]; then
	if [ "$FUNCTION_NAME" = "" ]; then
		echo "invoke requires second arg: lambda function name"	
		help;
	elif [ "$PAYLOAD" = "" ]; then
		echo "invoke requires third arg: lambda payload json"
		help;
	elif ! echo "$PAYLOAD" | jq empty >/dev/null 2>&1; then
		echo "third arg json format invalid"
		exit 1
	fi
fi

# listコマンド
if [ "$COMMAND" = "list" ]; then
	list_result=$(aws lambda list-functions | jq -r '.Functions[] | .FunctionName')
	echo "$list_result"
# invokeコマンド
else
	timestamp=$(date +%Y%m%d_%H%M%S)
	response_file_name="response_${timestamp}.json"
	payload_json=$(echo "$PAYLOAD" | jq -c .)
	invoke_result=$(aws lambda invoke --function-name "$FUNCTION_NAME" --payload "$payload_json" --cli-binary-format raw-in-base64-out --cli-read-timeout 0 "$response_file_name")
	echo "AWS CLI Output:"
	echo "$invoke_result" | jq .
	echo
	echo "Lambda Response:"
	jq '.' "$response_file_name"

	rm "$response_file_name"
fi

