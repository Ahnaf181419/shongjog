#!/usr/bin/env python3
"""
Shongjog LoRA Fine-Tune Script for Gemma 4 E2B

Trains a LoRA adapter on the SFT dataset to improve Bangla emergency
triage responses. Designed for Google Colab (T4 free tier or A100).

Usage in Colab:
    !pip install peft transformers datasets torch
    !python lora_finetune.py --epochs 5 --batch_size 2

The script:
1. Loads Gemma 4 E2B base model
2. Applies LoRA (rank 16, alpha 32)
3. Trains on sft_dataset.jsonl
4. Exports adapter weights

Adapter can then be loaded on-device via:
    modelManager.setLoraAdapter('/path/to/adapter.task')
"""

import argparse
import json
import os
from pathlib import Path

def build_training_script():
    """Return the Colab notebook content as a Python script string."""
    return '''
# ─── Shongjog LoRA Fine-Tune (Google Colab) ───────────────────────────
# Run in Google Colab with T4 GPU (free tier) or A100.
#
# Setup cell:
#   !pip install peft transformers datasets accelerate bitsandbytes

import torch
from datasets import Dataset
from transformers import (
    AutoModelForCausalLM,
    AutoTokenizer,
    TrainingArguments,
    Trainer,
)
from peft import LoraConfig, get_peft_model, TaskType

# ─── Config ───────────────────────────────────────────────────────────
MODEL_NAME = "google/gemma-4-e2b-it"  # Replace with actual model path
DATA_PATH = "training/sft_dataset.jsonl"
OUTPUT_DIR = "./shongjog-lora-adapter"
LORA_RANK = 16
LORA_ALPHA = 32
LORA_DROPOUT = 0.05
MAX_LENGTH = 1024
BATCH_SIZE = 2
EPOCHS = 5
LEARNING_RATE = 2e-4

# ─── Load Dataset ─────────────────────────────────────────────────────
def load_sft_dataset(path):
    """Load JSONL file into a HuggingFace Dataset."""
    examples = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            entry = json.loads(line.strip())
            # Format as instruction → response
            text = f"<start_of_turn>user\\n{entry['query']}\\n\\n"
            if entry.get("context"):
                text += f"Context: {entry['context']}\\n\\n"
            text += f"<end_of_turn>\\n<start_of_turn>model\\n{entry['ideal_answer']}<end_of_turn>"
            examples.append({"text": text})
    return Dataset.from_list(examples)

dataset = load_sft_dataset(DATA_PATH)
print(f"Loaded {len(dataset)} training examples")

# ─── Load Model + Tokenizer ───────────────────────────────────────────
tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
if tokenizer.pad_token is None:
    tokenizer.pad_token = tokenizer.eos_token

model = AutoModelForCausalLM.from_pretrained(
    MODEL_NAME,
    torch_dtype=torch.float16,
    device_map="auto",
)

# ─── Apply LoRA ───────────────────────────────────────────────────────
lora_config = LoraConfig(
    task_type=TaskType.CAUSAL_LM,
    r=LORA_RANK,
    lora_alpha=LORA_ALPHA,
    lora_dropout=LORA_DROPOUT,
    target_modules=[
        "q_proj", "k_proj", "v_proj", "o_proj",
        "gate_proj", "up_proj", "down_proj",
    ],
)

model = get_peft_model(model, lora_config)
model.print_trainable_parameters()

# ─── Tokenize ─────────────────────────────────────────────────────────
def tokenize_function(examples):
    tokenized = tokenizer(
        examples["text"],
        truncation=True,
        max_length=MAX_LENGTH,
        padding="max_length",
    )
    tokenized["labels"] = tokenized["input_ids"].copy()
    return tokenized

tokenized_dataset = dataset.map(tokenize_function, batched=True)

# ─── Train ────────────────────────────────────────────────────────────
training_args = TrainingArguments(
    output_dir=OUTPUT_DIR,
    num_train_epochs=EPOCHS,
    per_device_train_batch_size=BATCH_SIZE,
    gradient_accumulation_steps=4,
    warmup_steps=20,
    logging_steps=10,
    learning_rate=LEARNING_RATE,
    fp16=True,
    save_strategy="epoch",
    save_total_limit=2,
    report_to="none",
)

trainer = Trainer(
    model=model,
    args=training_args,
    train_dataset=tokenized_dataset,
    tokenizer=tokenizer,
)

print("Starting training...")
trainer.train()

# ─── Export Adapter ───────────────────────────────────────────────────
model.save_pretrained(OUTPUT_DIR)
tokenizer.save_pretrained(OUTPUT_DIR)
print(f"Adapter saved to {OUTPUT_DIR}")
print("\\nTo use on-device:")
print("  1. Convert adapter to .task format (if needed)")
print("  2. Push to device via adb push")
print("  3. Load via modelManager.setLoraAdapter(path)")
'''


def main():
    parser = argparse.ArgumentParser(description="Generate Shongjog LoRA training script")
    parser.add_argument("--output", default="training/lora_finetune.py",
                       help="Output Python file path")
    args = parser.parse_args()

    script = build_training_script()
    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(script, encoding="utf-8")
    print(f"Training script written to {out_path}")
    print(f"Run in Google Colab with T4 GPU")


if __name__ == "__main__":
    main()
