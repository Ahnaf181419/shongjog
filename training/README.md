# LoRA Fine-Tune Training Guide

This directory contains the supervised fine-tuning (SFT) dataset and
instructions for training a LoRA adapter on Gemma 4 E2B.

## Files

- `sft_dataset.jsonl` — supervised fine-tuning examples. Format:
  `{"query": "...", "context": "...", "ideal_answer": "..."}`.
  Currently 6 examples (scaffold). Expand to 150-400 before training.
- `lora_finetune.ipynb` — Google Colab notebook (to be created).

## Training Pipeline

1. **Expand the dataset** to 150-400 examples covering:
   - All corpus domains (ORS, snakebite, drowning, bleeding, fever, etc.)
   - Hard negatives: myth queries ("কেটে ফেলা উচিত?") → "না, এটি ভুল"
   - Out-of-scope queries → "আমি নিশ্চিত নই, ৯৯৯ কল করুন"
   - Consistent output shape: numbered steps → warning signs → call 999

2. **Train LoRA in Google Colab:**
   - Base model: Gemma 4 E2B (from Kaggle Models or HuggingFace)
   - LoRA rank: 16-32, alpha: 32
   - Target modules: attention + MLP projections
   - Epochs: 3-5
   - Hardware: T4 (free tier) or A100 (1 hour)

3. **Export adapter weights:**
   - Save as `.task` (MediaPipe format) or safetensors
   - Push to device via adb: `adb push adapter.task /sdcard/Download/`

4. **Load on-device:**
   ```dart
   // In Settings → Fine-tuned model toggle:
   modelManager.setLoraAdapter('/path/to/adapter.task');
   ```

5. **Re-run eval:**
   ```bash
   python3 eval/run_eval.py --report finetuned
   ```
   Compare `eval/results/base_report.md` vs `eval/results/finetuned_report.md`.

## Dataset Format

Each line is a JSON object:

```json
{
  "query": "Bangla emergency query",
  "context": "Retrieved chunks from KB (can be empty)",
  "ideal_answer": "Grounded Bangla answer with numbered steps + warnings"
}
```

## Rules

- All answers in Bangla only (no English drift)
- Numbered steps for procedures (১. ২. ৩.)
- Warning signs clearly separated ("সতর্কতা: ...")
- Myths corrected explicitly ("না, এটি ভুল")
- Out-of-scope queries get safe refusal ("আমি নিশ্চিত নই, ৯৯৯ কল করুন")
- Never fabricate dosages not in the corpus
