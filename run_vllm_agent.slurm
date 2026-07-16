#!/bin/bash
#SBATCH --nodes=1
#SBATCH -J agent_tracer_vllm
#SBATCH --chdir=/dl_scratch2/ege/ege/repos/agent-tracer
#SBATCH --nodelist=romer3
#SBATCH --gres=gpu:1
#SBATCH --output=/dl_scratch2/ege/ege/repos/agent-tracer/results/agent_tracer_vllm-%j.out
#SBATCH --error=/dl_scratch2/ege/ege/repos/agent-tracer/results/agent_tracer_vllm-%j.err
#SBATCH --time=1-00:00:00

# 1. Environment ve Cache Ayarları
source ~/miniconda3/etc/profile.d/conda.sh
# Kendi conda ortamınızı girin (diğer dosyalarınızdaki gibi matu-uq veya tau2 ortamı olabilir)
conda activate /dl_scratch2/ege/ege/envs/matu-uq/

export HF_HOME=/dl_scratch2/ege/hf_cache
export HUGGINGFACE_HUB_CACHE=$HF_HOME/hub
export TRANSFORMERS_CACHE=$HF_HOME/transformers

MODEL_NAME="Qwen/Qwen2.5-Coder-3B-Instruct"
PORT=8000

echo "=== vLLM Sunucusu Başlatılıyor ==="
# Arka planda vLLM OpenAI API sunucusunu başlatıyoruz (HuggingFace'den modeli indirecek/kullanacak)
python -m vllm.entrypoints.openai.api_server \
    --model $MODEL_NAME \
    --port $PORT \
    --gpu-memory-utilization 0.9 \
    --max-model-len 4096 &

VLLM_PID=$!

# Sunucunun ayağa kalkması ve modeli GPU'ya yüklemesi için biraz süre tanıyoruz
echo "vLLM sunucusunun ayağa kalkması bekleniyor (yaklaşık 60 sn)..."
sleep 60

# 2. LiteLLM & Agent Tracer (tau2) Ayarları
echo "=== Agent Tracer Çalıştırılıyor ==="
# LiteLLM'in vLLM'in açtığı portu görmesini sağlıyoruz
export OPENAI_API_BASE="http://localhost:${PORT}/v1"
export OPENAI_API_KEY="dummy-key" # LiteLLM'i kandırmak için boş bir string

# tau2'yi OpenAI-uyumlu serverımıza yönlendiriyoruz. 
# Modeli verirken "openai/" prefixi kullanmamız LiteLLM'in API_BASE'e gitmesini sağlar.
tau2 run \
  --agent-model "openai/${MODEL_NAME}" \
  --domain mock \
  --max-steps 50 \
  --num-trials 1

# 3. Temizlik
echo "=== vLLM Sunucusu Kapatılıyor ==="
kill $VLLM_PID
echo "Süreç tamamlandı."
