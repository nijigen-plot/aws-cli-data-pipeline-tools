#!/bin/bash

COMMAND=$1;
QUERY=$2;

help() {
    echo
    echo $0 ... aws athena wrapper command
    echo
    echo "$0 query [query string] ... execution and get result the query"
    echo
    exit 1
}

# コマンドがサポートしている文字列で打たれているか
if [ "$COMMAND" != "query" ]; then
	echo "COMMAND is required as 1st arg: query";
	help;
fi

# queryコマンドの場合、次の引数にクエリがあるか
if [ "$COMMAND" = "query" ]; then
	if [ "$QUERY" = "" ]; then
		echo "query requires second arg: query sentence";
		help;
	else

        # クエリ実行の試行とエラーハンドリング
        EXECUTION_RESPONSE=$(aws athena start-query-execution --query-string "$QUERY" --output json 2>&1)
        
        if echo "$EXECUTION_RESPONSE" | grep -q "InvalidRequestException"; then
            echo "Error starting query execution: $EXECUTION_RESPONSE"
            exit 1
        fi

        # クエリ実行IDの抽出
        EXECUTIONID=$(echo "$EXECUTION_RESPONSE" | jq -r '.QueryExecutionId')
        echo "Query Execution ID: $EXECUTIONID"


		# クエリ実行結果がSUCCEEDEDになったら結果を表示
		while true; do
			EXECUTIONRESULT=$(aws athena get-query-execution --query-execution-id "$EXECUTIONID" --output json)
			STATUS=$(echo $EXECUTIONRESULT | jq -r '.QueryExecution.Status.State')
			if [ "$STATUS" = "SUCCEEDED" ]; then
				echo "Query succeeded. Fetching results..."
				RESULT=$(aws athena get-query-results --query-execution-id "$EXECUTIONID" --output json)
				HEADER=$(echo "$RESULT" | jq -r '.ResultSet.ResultSetMetadata.ColumnInfo | map(.Label) | @tsv' | paste -sd '\t')
				DATA=$(echo "$RESULT" | jq -r '.ResultSet.Rows[1:][] | .Data | map(.VarCharValue) | @tsv')

				OUTPUT="$HEADER\n$DATA"
				echo -e "$OUTPUT" | column -s $'\t' -t
				break
			elif [ "$STATUS" = "FAILED" ]; then
				echo "Query failed."
				echo "(echo $EXECUTIONRESULT | jq '.QueryExecution.Status.StateChangeReason')"
				break
			elif [ "$STATUS" = "CANCELLED" ]; then
				echo "Query was cancelled."
				break
			else
				echo "Query is still running. Retrying in 1 second..."
				sleep 1
			fi
		done		
	fi
fi
