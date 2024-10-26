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
	echo "$0 vimdiff [Athena base database_name.table_name] [Athena compare target database_name.table_name] Compare tables first and second argument"
    echo
    exit 1
}

# クエリから結果を出力する
get_query_results() {
    local sql_query=$1
    local result

    # クエリ実行の試行とエラーハンドリング
    execution_response=$(aws athena start-query-execution --query-string "$sql_query" --output json 2>&1)

    if echo "$execution_response" | grep -q "InvalidRequestException"; then
        echo "Error starting query execution: $execution_response" >&2
        return 1
    fi

    # クエリ実行IDの抽出
    execution_id=$(echo "$execution_response" | jq -r '.QueryExecutionId')
    echo "Query Execution ID: $execution_id"

    # クエリ実行結果がSUCCEEDEDになったら結果を表示
    while true; do
        execution_result=$(aws athena get-query-execution --query-execution-id "$execution_id" --output json)
        status=$(echo "$execution_result" | jq -r '.QueryExecution.Status.State')
        if [ "$status" = "SUCCEEDED" ]; then
            echo "Query succeeded. Fetching results..."
            result=$(aws athena get-query-results --query-execution-id "$execution_id" --output json)
            header=$(echo "$result" | jq -r '.ResultSet.ResultSetMetadata.ColumnInfo | map(.Label) | @tsv' | paste -sd '\t')
            data=$(echo "$result" | jq -r '.ResultSet.Rows[1:][] | .Data | map(.VarCharValue) | @tsv')
            output=$(echo -e "$header\n$data")
            echo "$output"
            return 0
        elif [ "$status" = "FAILED" ]; then
            echo "Query failed." >&2
            echo "$(echo "$execution_result" | jq '.QueryExecution.Status.StateChangeReason')" >&2
            return 1
        elif [ "$status" = "CANCELLED" ]; then
            echo "Query was cancelled." >&2
            return 1
        else
            sleep 1
        fi
    done
}

# information_schemaからクエリを作る
query_builder() {
	local information_schema=$1

	# data_typeが以下条件に該当するものを抜き出す
	filtered_schema=$(awk -F'\t' '$8 ~/^(tinyint|smallint|integer|bigint|real|double|decimal.*)$/' <<< "${information_schema}")

	# 集計種類の数
	local agg_phase=7
	# 行数x集計種類数でforを回してクエリを作る
	agg_query=$(awk -F'\t' -v agg_phase="$agg_phase" '
	BEGIN {
		print "select column_name, agg_type, result from ("
	}
	{
		for (j = 1; j<= agg_phase; j++){
			# 一番最初だけUNION ALLつけない
			if (NR == 1 && j == 1){
				print "select '\''" $4 "'\'' as column_name, '\''1. count'\'' as agg_type, (select count(" $4 ") from " $1 "." $2 "." $3 ") as result"
			} else if (j == 1){
				print "union all select '\''" $4 "'\'' as column_name, '\''1. count'\'' as agg_type, (select count(" $4 ") from " $1 "." $2 "." $3 ") as result"
			} else if (j == 2){
				print "union all select '\''" $4 "'\'' as column_name, '\''2. count_distinct'\'' as agg_type, (select count(distinct " $4 ") from " $1 "." $2 "." $3 ") as result"
			} else if (j == 3){
				print "union all select '\''" $4 "'\'' as column_name, '\''3. mean'\'' as agg_type, (select avg(" $4 ") from " $1 "." $2 "." $3 ") as result"

			} else if (j == 4){
		print "union all select '\''" $4 "'\'' as column_name, '\''4. std'\'' as agg_type, (select stddev(" $4 ") from " $1 "." $2 "." $3 ") as result"

			} else if (j == 5){
		print "union all select '\''" $4 "'\'' as column_name, '\''5. min'\'' as agg_type, (select min(" $4 ") from " $1 "." $2 "." $3 ") as result"

			} else if (j == 6){
		print "union all select '\''" $4 "'\'' as column_name, '\''6. median'\'' as agg_type, (select approx_percentile(" $4 ", 0.5) from " $1 "." $2 "." $3 ") as result"
			} else if (j == 7){
		print "union all select '\''" $4 "'\'' as column_name, '\''7. max'\'' as agg_type, (select max(" $4 ") from " $1 "." $2 "." $3 ") as result"

			} else {
				# 特に何もしない
			}
		}
	}
	END {
		print")"
	}
	' <<< "$filtered_schema")
	# ピボットする
	pivot_query=$(awk -F'\t' -v agg_query="$agg_query" '
	BEGIN {
		print "select agg_type"
	}
	{
		print ", kv['\''" $4 "'\''] as " $4 ""
	}
	END {
		print "from (select agg_type, map_agg(column_name, result) as kv from(" agg_query ") group by agg_type order by agg_type)"
	}
	' <<< "$filtered_schema")
	echo "$pivot_query"
	return 0
}

# コマンドがサポートしている文字列で打たれているか
if [ "$COMMAND" != "query" ] && [ "$COMMAND" != "file" ] && [ "$COMMAND" != "vimdiff" ]; then
	echo "COMMAND is required as 1st arg: query/file/vimdiff";
	help;
fi

# queryコマンドの場合、次の引数にクエリがあるか
if [ "$COMMAND" = "query" ]; then
	if [ "$TARGET" = "" ]; then
		echo "Error: query requires second arg: query sentence";
		help;
	else

		result=$(get_query_results "$TARGET")
		echo "$result" | column -s $'\t' -t
	fi
fi

# fileコマンドの場合、次の引数に.sqlファイルが指定されているか
if [ "$COMMAND" = "file" ]; then
	if [[ "$TARGET" != *.sql ]]; then
		echo "Error: file requires second arg: .sql file";
		help;
	else
		
		# SQLファイルからクエリを読み取る
		sql_query=$(cat "$TARGET")

		result=$(get_query_results "$sql_query")
		echo "$result" | column -s $'\t' -t
	fi
fi

# vimdiffコマンドの場合、次と次の引数に入力があるか
if [ "$COMMAND" = "vimdiff" ]; then
	if [ "$TARGET" = "" ] || [ "$TARGET2" = "" ]; then
		echo "Error: vimdiff requires second and third arg: Athena database_name.table_name"
		help;
	elif [[ "$TARGET" != *.* ]] || [[ "$TARGET2" != *.* ]]; then
		echo "Error: Arguments must be in the format 'database_name.table_name' and contain dot (.)"
		help;
	else
		base_result=$(mktemp)
		target_result=$(mktemp)
		trap 'rm -f "$base_result" "$target_result"' EXIT
		IFS='.' read -r -a base_metadata <<< "$TARGET"
		IFS='.' read -r -a target_metadata <<< "$TARGET2"
        # テーブルのスキーマ情報を読み出す 存在しないテーブルの場合でもクエリは成功する
		base_schema=$(get_query_results "SELECT * FROM information_schema.columns WHERE table_schema = '${base_metadata[0]}' AND table_name = '${base_metadata[1]}'" | tail -n +3)
		target_schema=$(get_query_results "SELECT * FROM information_schema.columns WHERE table_schema = '${target_metadata[0]}' AND table_name = '${target_metadata[1]}'" | tail -n +3)

        # スキーマ情報から集計用クエリを作る
        base_query=$(query_builder "$base_schema")
        target_query=$(query_builder "$target_schema")

        # 集計結果を取得する
        if ! get_query_results "$base_query" > "$base_result"; then
            echo "Failed on the table provided as the second argument."
            exit 1
        fi

        if ! get_query_results "$target_query" > "$target_result"; then
            echo "Failed on the table provided as the third argument."
            exit 1
        fi

        # 結果を整形してvimdiff
        column -s $'\t' -t "$base_result" | tail -n +3 > base_result.tsv
        column -s $'\t' -t "$target_result" | tail -n +3 > target_result.tsv
        vimdiff base_result.tsv target_result.tsv
        
	fi
fi

