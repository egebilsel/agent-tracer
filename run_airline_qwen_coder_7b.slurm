#!/bin/bash
#SBATCH --nodes=1
#SBATCH -J air_qwen_coder_7b
#SBATCH --chdir=/dl_scratch2/ege/ege/repos/agent-tracer
#SBATCH --nodelist=adep1
#SBATCH --gres=gpu:1
#SBATCH --output=/home/ege/ege/uncertainty/tracer_slurms/results/agent_tracer_vllm-%j.out
#SBATCH --error=/home/ege/ege/uncertainty/tracer_slurms/results/agent_tracer_vllm-%j.err
#SBATCH --time=1-00:00:00

# 1. Environment ve Cache Ayarları
source ~/miniconda3/etc/profile.d/conda.sh
# Kendi conda ortamınızı girin (diğer dosyalarınızdaki gibi matu-uq veya tau2 ortamı olabilir)
conda activate /dl_scratch2/ege/ege/envs/agent-tracer

export HF_HOME=/dl_scratch2/ege/hf_cache
export HUGGINGFACE_HUB_CACHE=$HF_HOME/hub
export TRANSFORMERS_CACHE=$HF_HOME/transformers

MODEL_NAME="Qwen/Qwen2.5-Coder-7B-Instruct"
PORT=8000

echo "=== vLLM Sunucusu Başlatılıyor ==="
# Arka planda vLLM OpenAI API sunucusunu başlatıyoruz (HuggingFace'den modeli indirecek/kullanacak)
# tau2'nin içindeki bazı hardcoded değerlendiricilerin çökmemesi için modeli gpt-4.1 ve gpt-4o-mini olarak da isimlendiriyoruz
python -m vllm.entrypoints.openai.api_server \
    --model $MODEL_NAME \
    --served-model-name $MODEL_NAME gpt-4.1 gpt-4o-mini \
    --port $PORT \
    --gpu-memory-utilization 0.9 \
    --max-model-len 4096 \
    --enable-auto-tool-choice \
    --tool-call-parser hermes &

VLLM_PID=$!

# Sunucunun ayağa kalkması ve modeli GPU'ya yüklemesi modelin boyutuna göre uzun sürebilir.
echo "vLLM sunucusunun ayağa kalkması bekleniyor..."
# vLLM '/v1/models' endpointine yanıt verene kadar her 5 saniyede bir kontrol et
while ! curl -s http://localhost:${PORT}/v1/models > /dev/null; do
    echo "Hala bekleniyor..."
    sleep 5
done
echo "vLLM sunucusu başarıyla ayağa kalktı ve istek almaya hazır!"

# 2. LiteLLM & Agent Tracer (tau2) Ayarları
echo "=== Agent Tracer Çalıştırılıyor ==="
# LiteLLM'in vLLM'in açtığı portu görmesini sağlıyoruz
export OPENAI_API_BASE="http://localhost:${PORT}/v1"
export OPENAI_API_KEY="dummy-key" # LiteLLM'i kandırmak için boş bir string

# tau2'yi OpenAI-uyumlu serverımıza yönlendiriyoruz. 
# Modeli verirken "openai/" prefixi kullanmamız LiteLLM'in API_BASE'e gitmesini sağlar.
export TAU2_DATA_DIR=/home/ege/ege/uncertainty/tracer_slurms/data

tau2 run \
  --agent-llm "openai/${MODEL_NAME}" \
  --user-llm "openai/${MODEL_NAME}" \
  --domain airline \
  --max-steps 50 \
  --num-trials 1 \
  --calculate-uncertainty

# 3. Temizlik
echo "=== vLLM Sunucusu Kapatılıyor ==="
kill $VLLM_PID
echo "Süreç tamamlandı."
