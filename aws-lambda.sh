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
	LIST_RESULT=$(aws lambda list-functions | jq -r '.Functions[] | .FunctionName')
	echo "$LIST_RESULT"
# invokeコマンド
else
	TIMESTAMP=$(date +%Y%m%d_%H%M%S)
	RESPONSE_FILE_NAME="response_${TIMESTAMP}.json"
	PAYLOAD_JSON=$(echo "$PAYLOAD" | jq -c .)
	INVOKE_RESULT=$(aws lambda invoke --function-name "$FUNCTION_NAME" --payload "$PAYLOAD_JSON" --cli-binary-format raw-in-base64-out --cli-read-timeout 0 "$RESPONSE_FILE_NAME")
	echo "AWS CLI Output:"
	echo "$INVOKE_RESULT" | jq .
	echo
	echo "Lambda Response:"
	jq '.' "$RESPONSE_FILE_NAME"

	rm "$RESPONSE_FILE_NAME"
fi

