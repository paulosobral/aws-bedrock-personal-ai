#!/usr/bin/env bash

REGION="us-east-1"

declare -A REGION_LOCATIONS=(
  ["us-east-1"]="US East (N. Virginia)"
  ["us-west-2"]="US West (Oregon)"
  ["eu-west-1"]="Europe (Ireland)"
  ["eu-central-1"]="Europe (Frankfurt)"
  ["ap-southeast-1"]="Asia Pacific (Singapore)"
  ["ap-northeast-1"]="Asia Pacific (Tokyo)"
)

declare -A PROVIDER_MAP=(
  ["anthropic"]="Anthropic"
  ["amazon"]="Amazon"
  ["meta"]="Meta"
  ["mistral"]="Mistral AI"
  ["ai21"]="AI21 Labs"
  ["cohere"]="Cohere"
  ["stability"]="Stability AI"
)

declare -A PROVIDER_PRICE_CACHE

CACHE_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.pricing_cache.json"
[ -f "$CACHE_FILE" ] || echo '{}' > "$CACHE_FILE"

echo "=============================================="
echo "   Relatório de Uso e Custo dos Modelos Bedrock"
echo "=============================================="
echo ""

# Descobrir o primeiro dia do mês atual
MONTH_START=$(date +%Y-%m-01T00:00:00)

# Agora
NOW=$(date +%Y-%m-%dT%H:%M:%S)

echo "Janela solicitada: $MONTH_START → $NOW"
echo ""

normalize() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | tr -d ' .:_-'
}

# Descobre provider e slug do modelo a partir do ModelId do CloudWatch
# (ex.: "us.anthropic.claude-3-sonnet-20240229-v1:0" -> provider=anthropic, slug=claude-3-sonnet)
extract_provider() {
  local model_id="$1" first_part
  first_part="${model_id%%.*}"
  case "$first_part" in
    us|eu|apac|global) echo "${model_id#*.}" | cut -d. -f1 ;;
    *) echo "$first_part" ;;
  esac
}

extract_slug() {
  local model_id="$1" first_part slug
  first_part="${model_id%%.*}"
  case "$first_part" in
    us|eu|apac|global) slug="${model_id#*.*.}" ;;
    *) slug="${model_id#*.}" ;;
  esac
  echo "$slug" | sed -E 's/:[0-9]+$//; s/-v[0-9]+$//; s/-[0-9]{8}$//'
}

# Busca (com cache) a tabela de preços on-demand da AWS Pricing API para um provider.
# A Pricing API só existe em us-east-1/ap-south-1, independente da região do Bedrock.
get_provider_pricing_json() {
  local provider_display="$1"
  if [ -n "${PROVIDER_PRICE_CACHE[$provider_display]+x}" ]; then
    echo "${PROVIDER_PRICE_CACHE[$provider_display]}"
    return
  fi

  local filters=(Type=TERM_MATCH,Field=provider,Value="$provider_display" Type=TERM_MATCH,Field=feature,Value="On-demand Inference")
  local location="${REGION_LOCATIONS[$REGION]}"
  if [ -n "$location" ]; then
    filters+=(Type=TERM_MATCH,Field=location,Value="$location")
  fi

  local json
  json=$(aws pricing get-products --service-code AmazonBedrock --filters "${filters[@]}" --region us-east-1 --output json 2>/dev/null)
  PROVIDER_PRICE_CACHE[$provider_display]="$json"
  echo "$json"
}

# Tenta achar preço (USD por 1M tokens) na AWS Pricing API para um modelo + direção (input/output)
get_api_price() {
  local model_id="$1" direction="$2" direction_label provider slug normalized_slug json
  [ "$direction" = "input" ] && direction_label="Input tokens" || direction_label="Output tokens"

  provider=$(extract_provider "$model_id")
  local provider_display="${PROVIDER_MAP[$provider]:-}"
  [ -z "$provider_display" ] && return 1

  slug=$(extract_slug "$model_id")
  normalized_slug=$(normalize "$slug")

  json=$(get_provider_pricing_json "$provider_display")
  [ -z "$json" ] && return 1

  local model_name price unit norm_model
  while IFS=$'\t' read -r model_name price unit; do
    [ -z "$model_name" ] && continue
    norm_model=$(normalize "$model_name")
    if [[ "$normalized_slug" == *"$norm_model"* || "$norm_model" == *"$normalized_slug"* ]]; then
      case "$unit" in
        "1K tokens") awk -v p="$price" 'BEGIN{printf "%.10f", p*1000}' ;;
        *) echo "$price" ;;
      esac
      return 0
    fi
  done <<< "$(echo "$json" | jq -r --arg dir "$direction_label" '
    .PriceList[]
    | fromjson
    | select(.product.attributes.inferenceType == $dir)
    | [.product.attributes.model,
       ([.terms.OnDemand[].priceDimensions[].pricePerUnit.USD][0]),
       ([.terms.OnDemand[].priceDimensions[].unit][0])]
    | @tsv
  ' 2>/dev/null)"

  return 1
}

# Cache local de preços informados manualmente (persiste entre execuções)
get_cached_price() {
  local model_id="$1" direction="$2"
  jq -r --arg m "$model_id" --arg d "$direction" '.[$m][$d] // empty' "$CACHE_FILE" 2>/dev/null
}

set_cached_price() {
  local model_id="$1" direction="$2" price="$3" now tmp
  now=$(date +%Y-%m-%dT%H:%M:%S)
  tmp=$(mktemp)
  jq --arg m "$model_id" --arg d "$direction" --arg p "$price" --arg u "$now" \
    '.[$m] = ((.[$m] // {}) + {($d): $p, "updated_at": $u})' "$CACHE_FILE" > "$tmp" && mv "$tmp" "$CACHE_FILE"
}

# Fallback: pergunta o preço ao usuário quando a Pricing API não cobre o modelo
# (comum em modelos vendidos via AWS Marketplace, como Claude atuais)
# Preço informado é salvo em cache local e reusado nas próximas execuções.
prompt_price() {
  local model_id="$1" direction="$2" label value
  [ "$direction" = "input" ] && label="entrada (input)" || label="saída (output)"
  read -r -p "Preço não encontrado na AWS Pricing API para '$model_id' ($label). Informe USD por 1M tokens: " value
  value="${value:-0}"
  set_cached_price "$model_id" "$direction" "$value"
  echo "$value"
}

# ============================
# 1) LISTAR MODELOS USADOS
# ============================
echo "Descobrindo modelos usados no período..."

MODEL_IDS=$(aws cloudwatch list-metrics \
  --namespace AWS/Bedrock \
  --metric-name InputTokenCount \
  --region $REGION \
  --output json \
  | jq -r '.Metrics[].Dimensions[] | select(.Name=="ModelId") | .Value' \
  | sort -u)

if [ -z "$MODEL_IDS" ]; then
  echo "Nenhum modelo encontrado no período."
  exit 0
fi

echo "Modelos encontrados:"
echo "$MODEL_IDS"
echo ""

TOTAL_MONTH_COST="0"

# ============================
# LOOP POR MODELO
# ============================
for MODEL_ID in $MODEL_IDS; do
  echo "=============================================="
  echo "Modelo: $MODEL_ID"
  echo "=============================================="

  # ============================
  # 2) DESCOBRIR JANELA REAL DO CLOUDWATCH
  # ============================
  FIRST_DP=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/Bedrock \
    --metric-name InputTokenCount \
    --dimensions Name=ModelId,Value=$MODEL_ID \
    --statistics Sum \
    --start-time "$MONTH_START" \
    --end-time "$NOW" \
    --period 3600 \
    --region $REGION \
    --output json \
    | jq -r '.Datapoints | sort_by(.Timestamp) | .[0].Timestamp // empty')

  LAST_DP=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/Bedrock \
    --metric-name InputTokenCount \
    --dimensions Name=ModelId,Value=$MODEL_ID \
    --statistics Sum \
    --start-time "$MONTH_START" \
    --end-time "$NOW" \
    --period 3600 \
    --region $REGION \
    --output json \
    | jq -r '.Datapoints | sort_by(.Timestamp) | .[-1].Timestamp // empty')

  if [ -z "$FIRST_DP" ]; then
    echo "Nenhum datapoint encontrado para este modelo."
    echo ""
    continue
  fi

  echo "Janela real de métricas:"
  echo "Início: $FIRST_DP"
  echo "Fim:    $LAST_DP"
  echo ""

  # ============================
  # 3) PEGAR TOKENS DE ENTRADA
  # ============================
  INPUT_TOKENS=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/Bedrock \
    --metric-name InputTokenCount \
    --dimensions Name=ModelId,Value=$MODEL_ID \
    --statistics Sum \
    --start-time "$MONTH_START" \
    --end-time "$NOW" \
    --period 3600 \
    --region $REGION \
    --output json \
    | jq -r '.Datapoints | map(.Sum) | add // 0')

  # ============================
  # 4) PEGAR TOKENS DE SAÍDA
  # ============================
  OUTPUT_TOKENS=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/Bedrock \
    --metric-name OutputTokenCount \
    --dimensions Name=ModelId,Value=$MODEL_ID \
    --statistics Sum \
    --start-time "$MONTH_START" \
    --end-time "$NOW" \
    --period 3600 \
    --region $REGION \
    --output json \
    | jq -r '.Datapoints | map(.Sum) | add // 0')

  echo "Tokens de entrada: $INPUT_TOKENS"
  echo "Tokens de saída:  $OUTPUT_TOKENS"
  echo ""

  # ============================
  # 5) PEGAR PREÇO DO MODELO (cache -> API -> prompt manual)
  # ============================
  INPUT_PRICE=$(get_cached_price "$MODEL_ID" input)
  if [ -z "$INPUT_PRICE" ]; then
    INPUT_PRICE=$(get_api_price "$MODEL_ID" input)
  fi
  if [ -z "$INPUT_PRICE" ]; then
    INPUT_PRICE=$(prompt_price "$MODEL_ID" input)
  fi

  OUTPUT_PRICE=$(get_cached_price "$MODEL_ID" output)
  if [ -z "$OUTPUT_PRICE" ]; then
    OUTPUT_PRICE=$(get_api_price "$MODEL_ID" output)
  fi
  if [ -z "$OUTPUT_PRICE" ]; then
    OUTPUT_PRICE=$(prompt_price "$MODEL_ID" output)
  fi

  echo "Preço por 1M tokens (input):  $INPUT_PRICE USD"
  echo "Preço por 1M tokens (output): $OUTPUT_PRICE USD"
  echo ""

  # ============================
  # 6) CALCULAR CUSTO
  # ============================
  COST_INPUT=$(awk -v t="$INPUT_TOKENS" -v p="$INPUT_PRICE" 'BEGIN{printf "%.6f", (t*p)/1000000}')
  COST_OUTPUT=$(awk -v t="$OUTPUT_TOKENS" -v p="$OUTPUT_PRICE" 'BEGIN{printf "%.6f", (t*p)/1000000}')
  TOTAL_COST=$(awk -v a="$COST_INPUT" -v b="$COST_OUTPUT" 'BEGIN{printf "%.6f", a+b}')

  printf "Custo input:   %.6f USD\n" "$COST_INPUT"
  printf "Custo output:  %.6f USD\n" "$COST_OUTPUT"
  printf "CUSTO TOTAL:   %.6f USD\n" "$TOTAL_COST"
  echo ""

  TOTAL_MONTH_COST=$(awk -v a="$TOTAL_MONTH_COST" -v b="$TOTAL_COST" 'BEGIN{printf "%.6f", a+b}')
done

echo "=============================================="
printf "CUSTO TOTAL DO MÊS (todos os modelos): %.6f USD\n" "$TOTAL_MONTH_COST"
echo "=============================================="
