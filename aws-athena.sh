#!/bin/bash

COMMAND=$1;
TARGET=$2;
TARGET2=$3;

help() {
    echo
    echo $0 ... aws athena wrapper command
    echo
    echo "$0 query [query string] ... execution and get result the query"
	echo "$0 file  [.sql file] ... execution and get result from the .sql file"
	echo "$0 diff [Athena base database_name.table_name] [Athena compare target database_name.table_name] Compare tables first and second argument"
    echo
    exit 1
}

get_query_results() {
	local sql_query=$1

		# クエリ実行の試行とエラーハンドリング
		execution_response=$(aws athena start-query-execution --query-string "$sql_query" --output json 2>&1)
		
		if echo "$execution_response" | grep -q "InvalidRequestException"; then
			echo "Error starting query execution: $execution_response"
			exit 1
		fi

		# クエリ実行IDの抽出
		execution_id=$(echo "$execution_response" | jq -r '.QueryExecutionId')
		echo "Query Execution ID: $execution_id"


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
if [ "$COMMAND" != "query" ] && [ "$COMMAND" != "file" ] && [ "$COMMAND" != "diff" ]; then
	echo "COMMAND is required as 1st arg: query/file/diff";
	help;
fi

# queryコマンドの場合、次の引数にクエリがあるか
if [ "$COMMAND" = "query" ]; then
	if [ "$TARGET" = "" ]; then
		echo "query requires second arg: query sentence";
		help;
	else

		get_query_results "$TARGET"
	fi
fi

# fileコマンドの場合、次の引数に.sqlファイルが指定されているか
if [ "$COMMAND" = "file" ]; then
	if [[ "$TARGET" != *.sql ]]; then
		echo "file requires second arg: .sql file";
		help;
	else
		
		# SQLファイルからクエリを読み取る
		sql_query=$(cat "$TARGET")

		get_query_results "$sql_query"
	fi
fi

# diffコマンドの場合、次と次の引数に入力があるか
if [ "$COMMAND" = "diff" ]; then
	if [ "$TARGET" = "" ] || [ "$TARGET2" = "" ]; then
		echo "diff requires second and third arg: Athena database_name.table_name"
		# ここもうちょいエラーハンドリング欲しいかも
		help;
	else
		IFS='.' read -r -a metadata <<< "$TARGET"
		# テーブルのスキーマ情報を読み出す
		get_query_results "SELECT * FROM information_schema.columns WHERE table_schema = '${metadata[0]}' AND table_name = '${metadata[1]}'"
	fi
fi
