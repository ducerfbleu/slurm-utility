#!/bin/bash

# process_string_to_array(): function to process a string and return results in an array

process_string_to_array() {

    local input_string="$1"
    
    # extract the first field to node_global_name global variable
    node_global_name=$(echo "$input_string" | cut -d'-' -f1)
    # [grep] extract content within []; [sed] remove brackets
    local content=$(echo "$input_string" | grep -o '\[.*\]' | sed 's/[][]//g')
    
    # set comma as IFS; read parts into a temporary array
    IFS=',' read -ra temp_parts <<< "$content"
    
    # read though temp_parts array, then output to global variable "extracted_nodes" 
    readarray -t extracted_nodes < <(

      for part in "${temp_parts[@]}"; do
        process_item "$part"
      done

    )
}

# process_item(): function to process a single item (number or range)
process_item() {
    local item="$1"
    item=$(echo "$item" | xargs)

    if [[ "$item" == *"-"* ]]; then
        # when input is range, e.g., 011-016
        local start=$(echo "$item" | cut -d'-' -f1)
        local end=$(echo "$item" | cut -d'-' -f2)
        local padding_width=${#start}

        seq -w "$start" "$end" | while read num; do
            printf "$node_global_name-%0*d\n" "$padding_width" "$((10#$num))"
        done

    else
        # when input is single number, e.g., 015
        local number="$item"
        local padding_width=${#number} # Get the original padding width

        printf "$node_global_name-%0*d\n" "$padding_width" "$((10#$number))"
    fi
}

parse_tres_string() {
    local tres_str="$1"
    local -n resources_array="$2" # Use nameref

    # extract the part after the first '='
    local data_part=$(echo "$tres_str" | cut -d'=' -f2-)

    # split by comma and populate to array
    IFS=',' read -ra pairs <<< "$data_part"
    for pair in "${pairs[@]}"; do
        IFS='=' read -r key value <<< "$pair"
        # save key-value in each element
        resources_array["$key"]="$value"
    done
}

# convert_to_mb(): function to convert memory string (e.g., "448G", "1T", "123M", "1024B") to Megabytes (integer)
# $1: Memory string with unit
# return value: The value in MB as an integer (printed to stdout)
convert_to_mb() {
    local mem_str="$1"
    local num_part=""
    local unit_part=""
    local value_mb=""

    # Bash regex matching to extract number and unit
    # ^([0-9]+)    -> captures the number (e.g., "448", "1")
    # ([MGTBmgbt])?$ -> captures the unit (e.g., "G", "T", "M", "B") case-insensitively
    if [[ "$mem_str" =~ ^([0-9]+)([MGTBmgbt])?$ ]]; then
        num_part="${BASH_REMATCH[1]}"
        unit_part="${BASH_REMATCH[2]}" # this will be empty if no unit 
        unit_part=$(echo "$unit_part" | tr '[:lower:]' '[:upper:]') # convert unit to uppercase
    else
        # invalid format: print a warning and return 0 MB
        echo "Warning: Invalid memory format for conversion: '$mem_str'. Returning 0 MB." >&2
        echo "0"
        return 1 # Indicate an error
    fi

    # default unit to M if not specified (e.g., if input was "123" without "M")
    if [[ -z "$unit_part" ]]; then
        unit_part="M"
    fi

    case "$unit_part" in
        "M")
            value_mb="$num_part"
            ;;
        "G")
            value_mb=$(( num_part * 1024 ))
            ;;
        "T")
            value_mb=$(( num_part * 1024 * 1024 )) # 1 TB = 1024 * 1024 MB
            ;;
        "B") # Bytes to MB. Integer division truncates; less than 1MB becomes 0MB.
            value_mb=$(( num_part / (1024 * 1024) ))
            ;;
        *) # in case of unexpected units
            echo "Warning: Unrecognized memory unit '$unit_part' in '$mem_str'. Returning '$num_part' as MB." >&2
            value_mb="$num_part"
            ;;
    esac
    echo "$value_mb"
}

# format_memory_mb(): function to convert memory from MB to human-readable GB or TB
# $1: memory value in Megabytes (M); output from convert_to_mb()
# use floating point with bc, two decimal points 
format_memory_mb() {
    local input_mb_str="$1"
    local mb="$1"
    local gb=$(echo "scale=2; $mb / 1024" | bc)
    local tb=$(echo "scale=2; $mb / (1024 *1024)" | bc)

    if (( $(echo "$tb >= 1.0" | bc) )); then
	# if 1 TB or more, show in TB
	echo "${tb} TB"
elif (( $(echo "$gb >= 1.0" | bc) )); then
        # if 1 GB or more, show in GB
        echo "${gb} GB"
    else
        # Otherwise, show in MB
        echo "${mb} MB"
    fi
}

# generate_usage_report(): function to generate the usage report line from scontrol
# $1: The CfgTRES field in scontrol show node
# $2: The AllocTRES string in scontrol show node
generate_usage_report() {
    local cfg_string="$1"
    local alloc_string="$2"
    local node_name="$3"
    local node_state="$4"

    # local arrays 
    declare -A local_cfg_resources
    declare -A local_alloc_resources

    # parse the input strings into the local arrays
    parse_tres_string "$cfg_string" local_cfg_resources
    parse_tres_string "$alloc_string" local_alloc_resources

    # find gpu key 
    # locate "gres/gpu:" and save gpu string as key
    local gpu_key=""
    for key in "${!local_cfg_resources[@]}"; do
        if [[ "$key" == "gres/gpu:"* ]]; then
            gpu_key="$key"
            break # assume only one GPU type is present
        fi
    done

    # init output string
    local output_string="| status=[$node_state] | node=[$node_name] |"

    # get CPU alloc info
    local cpu_used="${local_alloc_resources['cpu']}"
    local cpu_total="${local_cfg_resources['cpu']}"
    # if CPU data doesn't exist in local_alloc_resources, assign zero as default
    if [[ -n "$cpu_used" && -n "$cpu_total" ]]; then
         output_string+=" cpu=[${cpu_used}/${cpu_total}] |"
    else 
         output_string+=" cpu=[0/${cpu_total}] |"    
    fi

    # get GPU alloc info (gpu_key)
    # check if a GPU key exists and then the same with above
    if [[ -n "$gpu_key" ]]; then
        local gpu_used="${local_alloc_resources[$gpu_key]}"
        local gpu_total="${local_cfg_resources[$gpu_key]}"
        if [[ -n "$gpu_used" && -n "$gpu_total" ]]; then
             output_string+=" ${gpu_key}=[${gpu_used}/${gpu_total}] |"
	else
	     output_string+=" ${gpu_key}=[0/${gpu_total}] |"
        fi
    fi
    # get memory info 
    local mem_used="${local_alloc_resources['mem']}"
    local mem_total="${local_cfg_resources['mem']}"
    # Check if Memory data is present in both input strings
    if [[ -n "$mem_used" && -n "$mem_total" ]]; then
	# memory formatting feat. format_memory_mb()
	local used_mb=${mem_used%M} # remove alphabet
        local total_mb=${mem_total%M} 
	local used_mb_num=$(convert_to_mb "$mem_used")
	local formatted_used_mem=$(format_memory_mb "$(( $used_mb_num))")
	local formatted_total_mem=$(format_memory_mb "$total_mb")
	output_string+=" mem=[${formatted_used_mem}/${formatted_total_mem}] |"
    else
        local total_mb=${mem_total%M}
        local formatted_total_mem=$(format_memory_mb "$total_mb")
        output_string+=" mem=[0/${formatted_total_mem}] |"
    fi

    # Print the final constructed output string
    echo "$output_string"
}

#node_pattern="$1"
PARTITIONS=$(sinfo -s | grep gpu | awk '{print $1}')

echo "************************** GPU Usage Dashboard *************************"
echo "************************************************************************"
for PARTITION in $PARTITIONS; do
	echo " ======================== ** $PARTITION USAGE ** ============================================="
	TOT_AVAIL_NODES=$(sinfo -p $PARTITION|  awk '{print $6}')
	TOT_NODE_INFO=$(sinfo -p $PARTITION -h -o "%N %t")
	
	while read -r AVAIL_NODES NODE_STATE; do
		if [[ $AVAIL_NODES == *[* ]]; then
			process_string_to_array "$AVAIL_NODES"
			for FOCAL_NODE in "${extracted_nodes[@]}"; do
				#echo $FOCAL_NODE
				TRES_CFG=$(scontrol show node $FOCAL_NODE | grep CfgTRES)	
				TRES_ALLOC=$(scontrol show node $FOCAL_NODE | grep AllocTRES)
				generate_usage_report "$TRES_CFG" "$TRES_ALLOC" "$FOCAL_NODE" "$NODE_STATE"
			done
		else
			SINGLE_NODE=${AVAIL_NODES}
			#echo "<$node_num>"
			TRES_CFG=$(scontrol show node $SINGLE_NODE | grep CfgTRES)
			TRES_ALLOC=$(scontrol show node $SINGLE_NODE | grep AllocTRES)
			generate_usage_report "$TRES_CFG" "$TRES_ALLOC" "$SINGLE_NODE" "$NODE_STATE"
		fi
	done <<< "$TOT_NODE_INFO"
done
