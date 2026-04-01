import os
import subprocess
import json
import sys

# Force UTF-8 to prevent cp1252 Rich console crashes
os.environ['PYTHONIOENCODING'] = 'utf-8'

configs = {
    'Seated': 'outputs/unnamed/splatfacto/2026-03-07_195535/config.yml',
    'Standing': 'outputs/unnamed/splatfacto/2026-03-20_132014/config.yml',
    'Reclining': 'outputs/unnamed/splatfacto/2026-03-20_221535/config.yml',
    'All_Merged': 'outputs/unnamed/splatfacto/2026-03-27_173343/config.yml'
}
results = {}

print("====================================")
print("  Evaluating Splatfacto Models ")
print("====================================\n")

for name, cfg in configs.items():
    print(f"--> [1] Starting ns-eval for {name} statue...", flush=True)
    try:
        # Run ns-eval directly and stream standard output to terminal
        subprocess.run(
            [sys.executable, '-m', 'nerfstudio.scripts.eval', '--load-config', cfg, '--output-path', f'eval_{name}.json'],
            check=True
        )
        
        # Read the generated metric file
        with open(f'eval_{name}.json', 'r', encoding='utf-8') as f:
            data = json.load(f)
            metrics = data.get('results', {})
            results[name] = metrics
            
            psnr = metrics.get('psnr', 0.0)
            ssim = metrics.get('ssim', 0.0)
            lpips = metrics.get('lpips', 0.0)
            print(f"✅ {name} finished | PSNR: {psnr:.2f} | SSIM: {ssim:.4f} | LPIPS: {lpips:.4f}\n", flush=True)
            
    except Exception as e:
        print(f"❌ {name} failed: {e}\n", flush=True)

# Write out everything to an aggregated report
with open('all_metrics_report.json', 'w', encoding='utf-8') as f:
    json.dump(results, f, indent=4)

print("Evaluation pipeline fully complete! Results saved to all_metrics_report.json")
