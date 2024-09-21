#!/bin/bash

COMMAND=$1;
QUERY=$2;


help() {
    echo
    echo $0 ... aws athena wrapper command
    echo
    echo "$0 query [query string] ... execution and get result the query"
	echo "$0 file  [.sql file] ... execution and get result from the .sql file"
    echo
    exit 1
}

get_query_results() {
	local execution_id=$1

	# クエリ実行結果がSUCCEEDEDになったら結果を表示
	while true; do
		execution_result=$(aws athena get-query-execution --query-execution-id "$execution_id" --output json)
		status=$(echo $execution_result | jq -r '.QueryExecution.Status.State')
		if [ "$status" = "SUCCEEDED" ]; then
			echo "Query succeeded. Fetching results..."
			result=$(aws athena get-query-results --query-execution-id "$execution_id" --output json)
			header=$(echo "$result" | jq -r '.ResultSet.ResultSetMetadata.ColumnInfo | map(.Label) | @tsv' | paste -sd '\t')
			data=$(echo "$result" | jq -r '.ResultSet.Rows[1:][] | .Data | map(.VarCharValue) | @tsv')

			output="$header\n$data"
			echo -e "$output" | column -s $'\t' -t
			break
		elif [ "$status" = "FAILED" ]; then
			echo "Query failed."
			echo "(echo $execution_result | jq '.QueryExecution.Status.StateChangeReason')"
			break
		elif [ "$status" = "CANCELLED" ]; then
			echo "Query was cancelled."
			break
		else
			echo "Query is still running. Retrying in 1 second..."
			sleep 1
		fi
	done

}


# コマンドがサポートしている文字列で打たれているか
if [ "$COMMAND" != "query" ] && [ "$COMMAND" != "file" ]; then
	echo "COMMAND is required as 1st arg: query/file";
	help;
fi

# queryコマンドの場合、次の引数にクエリがあるか
if [ "$COMMAND" = "query" ]; then
	if [ "$QUERY" = "" ]; then
		echo "query requires second arg: query sentence";
		help;
	else

		# クエリ実行の試行とエラーハンドリング
		execution_response=$(aws athena start-query-execution --query-string "$QUERY" --output json 2>&1)
		
		if echo "$execution_response" | grep -q "InvalidRequestException"; then
			echo "Error starting query execution: $execution_response"
			exit 1
		fi

		# クエリ実行IDの抽出
		execution_id=$(echo "$execution_response" | jq -r '.QueryExecutionId')
		echo "Query Execution ID: $execution_id"

		get_query_results "$execution_id"
	fi
fi

# fileコマンドの場合、次の引数に.sqlファイルが指定されているか
if [ "$COMMAND" = "file" ]; then
	if [[ "$QUERY" != *.sql ]]; then
		echo "file requires second arg: .sql file";
		help;
	else
		
		# SQLファイルからクエリを読み取る
		sql_query=$(cat "$QUERY")
		execution_response=$(aws athena start-query-execution --query-string "$sql_query" --output json 2>&1)

		if echo "$execution_response" | grep -q "InvalidRequestException"; then
			echo "Error starting query execution: $execution_response"
			exit 1
		fi

		# クエリ実行IDの抽出
		execution_id=$(echo "$execution_response" | jq -r '.QueryExecutionId')
		echo "Query Execution ID: $execution_id"

		get_query_results "$execution_id"
	fi
fi
