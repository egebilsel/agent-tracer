import os
import re

models = [
    "andrewzh2/Absolute_Zero_Reasoner-Base-7b",
    "andrewzh/Absolute_Zero_Reasoner-Coder-14b",
    "andrewzh/Absolute_Zero_Reasoner-Coder-3b",
    "andrewzh/Absolute_Zero_Reasoner-Coder-7b",
    "Qwen/Qwen2.5-7B-Instruct",
    "Qwen/Qwen2.5-Coder-14B-Instruct",
    "Qwen/Qwen2.5-Coder-3B-Instruct",
    "Qwen/Qwen2.5-Coder-7B-Instruct"
]

template_path = "/Users/tarikegebilsel/Desktop/Dev/mit/exps/uncertainty/agent-tracer/run_vllm_agent.slurm"
with open(template_path, "r") as f:
    template = f.read()

# Replace mock with airline
template = template.replace("--domain mock", "--domain airline")

for model in models:
    name = model.split("/")[-1].lower()
    
    if "absolute_zero" in name:
        prefix = "az"
        suffix = name.replace("absolute_zero_reasoner-", "").replace("-", "_")
    elif "qwen" in name:
        prefix = "qwen"
        suffix = name.replace("qwen2.5-", "").replace("-instruct", "").replace("-", "_")
    else:
        prefix = "model"
        suffix = name.replace("-", "_")
        
    short_name = f"{prefix}_{suffix}"
    file_name = f"run_airline_{short_name}.slurm"
    
    # modify MODEL_NAME
    content = re.sub(r'MODEL_NAME=".*?"', f'MODEL_NAME="{model}"', template)
    
    # modify job name
    content = re.sub(r'#SBATCH -J .*', f'#SBATCH -J air_{short_name}', content)
    
    # Write the new slurm file to the same directory
    out_path = os.path.join(os.path.dirname(template_path), file_name)
    with open(out_path, "w") as f:
        f.write(content)
        
    print(f"Generated {file_name} for model {model}")

print("\nAll 8 airline SLURM files have been generated successfully!")
