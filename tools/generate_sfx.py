"""
ControllerTT 高保真枪械与命中音效生成器
使用 Python 标准库合成 44.1kHz 16-bit PCM WAV 音频文件。
无任何外部依赖，可重复构建。
"""
import math
import os
import random
import struct
import wave

SAMPLE_RATE = 44100


def clamp(val, low=-1.0, high=1.0):
    return max(low, min(high, val))


def write_wav(filename: str, samples: list[float]):
    os.makedirs(os.path.dirname(os.path.abspath(filename)), exist_ok=True)
    with wave.open(filename, "w") as wf:
        wf.setnchannels(1)  # Mono
        wf.setsampwidth(2)  # 16-bit PCM
        wf.setframerate(SAMPLE_RATE)
        
        # 归一化峰值至 0.95 防止削波
        peak = max(abs(s) for s in samples) if samples else 1.0
        scale = 0.95 / peak if peak > 0.95 else 0.95
        
        raw_bytes = bytearray()
        for s in samples:
            val = int(clamp(s * scale) * 32767.0)
            raw_bytes.extend(struct.pack("<h", val))
        wf.writeframes(raw_bytes)
    print(f"Generated: {filename} ({len(samples)} samples, {len(samples)/SAMPLE_RATE:.2f}s)")


def gen_m4_fire() -> list[float]:
    """M4 突击步枪全自动射击声：清脆枪口爆裂 + 机械枪栓抽壳复进撞击"""
    duration = 0.22
    total_samples = int(SAMPLE_RATE * duration)
    samples = [0.0] * total_samples
    
    rnd = random.Random(42)
    
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        
        # 1. 枪口初速爆裂 (0 ~ 0.05s)
        env_blast = math.exp(-t * 60.0)
        noise = (rnd.random() * 2.0 - 1.0) * env_blast * 1.5
        
        # 2. 枪膛主频谐振 (180Hz 快速衰减至 90Hz)
        freq = 180.0 * math.exp(-t * 25.0) + 90.0
        punch = math.sin(2.0 * math.pi * freq * t) * math.exp(-t * 35.0) * 1.2
        
        # 3. 机械机匣与撞针金属瞬态 (在 0.02s 达到峰值)
        t_bolt = max(0.0, t - 0.015)
        bolt_env = math.exp(-t_bolt * 70.0) * (1.0 if t >= 0.015 else 0.0)
        bolt = math.sin(2.0 * math.pi * 1850.0 * t_bolt) * bolt_env * 0.45
        bolt += math.sin(2.0 * math.pi * 3200.0 * t_bolt) * bolt_env * 0.25
        
        # 4. 空气残响衰减尾音
        tail_env = math.exp(-t * 18.0) * 0.2
        tail = (rnd.random() * 2.0 - 1.0) * tail_env
        
        s = noise + punch + bolt + tail
        samples[i] = s
        
    return samples


def gen_deagle_fire() -> list[float]:
    """沙漠之鹰 .50 AE 重炮开火声：震撼重低音超压 + 沉重滑套复进金属碰撞"""
    duration = 0.42
    total_samples = int(SAMPLE_RATE * duration)
    samples = [0.0] * total_samples
    
    rnd = random.Random(1337)
    
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        
        # 1. 大口径高压初击波 (0 ~ 0.04s 剧烈非线性爆炸)
        env_blast = math.exp(-t * 40.0)
        noise = (rnd.random() * 2.0 - 1.0)
        # 简单的双极低通平滑
        noise = math.copysign(abs(noise) ** 0.8, noise) * env_blast * 2.0
        
        # 2. Sub-bass 低音重炮震感 (从 120Hz 跌落至 45Hz)
        freq = 120.0 * math.exp(-t * 15.0) + 45.0
        sub_bass = math.sin(2.0 * math.pi * freq * t) * math.exp(-t * 14.0) * 1.8
        
        # 3. 沉重滑套后坐碰撞 (0.025s) 与复进闭锁 (0.12s)
        # 第一次冲击（抛壳）
        t_slide1 = max(0.0, t - 0.025)
        slide1_env = math.exp(-t_slide1 * 45.0) * (1.0 if t >= 0.025 else 0.0)
        slide1 = (math.sin(2.0 * math.pi * 880.0 * t_slide1) + 0.5 * math.sin(2.0 * math.pi * 1420.0 * t_slide1)) * slide1_env * 0.6
        
        # 第二次撞击（闭锁复位）
        t_slide2 = max(0.0, t - 0.12)
        slide2_env = math.exp(-t_slide2 * 55.0) * (1.0 if t >= 0.12 else 0.0)
        slide2 = (math.sin(2.0 * math.pi * 1100.0 * t_slide2) + 0.3 * (rnd.random() * 2 - 1)) * slide2_env * 0.4
        
        # 4. 靶场开阔空间残响
        tail = math.sin(2.0 * math.pi * 60.0 * t) * math.exp(-t * 8.0) * 0.35
        
        s = noise + sub_bass + slide1 + slide2 + tail
        samples[i] = s
        
    return samples


def gen_hit() -> list[float]:
    """电竞级命中音效：高穿透力水晶金属清脆'叮'声 (Hitmarker 爽感反馈)"""
    duration = 0.14
    total_samples = int(SAMPLE_RATE * duration)
    samples = [0.0] * total_samples
    
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        
        # 极短触发起音 (0.001s attack)
        attack = min(1.0, t / 0.001)
        decay = math.exp(-t * 32.0)
        env = attack * decay
        
        # 复合泛音晶体铃音 (2600Hz 主音 + 5200Hz 纯二倍频 + 7800Hz 超高频微光)
        tone1 = math.sin(2.0 * math.pi * 2600.0 * t) * 0.7
        tone2 = math.sin(2.0 * math.pi * 5200.0 * t) * 0.35
        tone3 = math.sin(2.0 * math.pi * 7800.0 * t) * 0.15
        
        samples[i] = (tone1 + tone2 + tone3) * env
        
    return samples


def gen_kill() -> list[float]:
    """靶机击毁确认音效：上行和弦金属爆碎确认感"""
    duration = 0.28
    total_samples = int(SAMPLE_RATE * duration)
    samples = [0.0] * total_samples
    
    rnd = random.Random(77)
    
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        
        # 前段 1400Hz 铺垫，中段升至 2200Hz 胜利正反馈
        attack = min(1.0, t / 0.002)
        env = attack * math.exp(-t * 16.0)
        
        freq = 1400.0 if t < 0.05 else 2200.0
        tone = math.sin(2.0 * math.pi * freq * t) * 0.65
        tone_harm = math.sin(2.0 * math.pi * freq * 1.5 * t) * 0.3
        
        # 靶机碎裂微颗粒声
        shatter = (rnd.random() * 2.0 - 1.0) * math.exp(-t * 40.0) * 0.25
        
        samples[i] = (tone + tone_harm + shatter) * env
        
    return samples


def gen_ads() -> list[float]:
    """开镜战术战术握持微移动音效"""
    duration = 0.12
    total_samples = int(SAMPLE_RATE * duration)
    samples = [0.0] * total_samples
    
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        env = math.sin(math.pi * (t / duration)) ** 2
        freq = 300.0 + 500.0 * (t / duration)
        tone = math.sin(2.0 * math.pi * freq * t) * 0.15
        samples[i] = tone * env
        
    return samples


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out_dir = os.path.join(root, "assets", "audio")
    os.makedirs(out_dir, exist_ok=True)
    
    write_wav(os.path.join(out_dir, "sfx_m4_fire.wav"), gen_m4_fire())
    write_wav(os.path.join(out_dir, "sfx_deagle_fire.wav"), gen_deagle_fire())
    write_wav(os.path.join(out_dir, "sfx_hit.wav"), gen_hit())
    write_wav(os.path.join(out_dir, "sfx_kill.wav"), gen_kill())
    write_wav(os.path.join(out_dir, "sfx_ads.wav"), gen_ads())
    print("All audio sound effects synthesized successfully!")


if __name__ == "__main__":
    main()
