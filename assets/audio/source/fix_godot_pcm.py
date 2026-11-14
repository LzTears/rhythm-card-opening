"""Preserve PCM24 masters and encode classic WAV PCM16 for Godot compatibility."""
from pathlib import Path
import subprocess,json,struct,hashlib,re
import soundfile as sf
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
FFMPEG='D:/AI/MuseTalk/tools/ffmpeg.exe'
manifest_path=ROOT/'manifest.json'
m=json.loads(manifest_path.read_text(encoding='utf-8'))
for rec in m['assets']:
    if rec['kind']!='sfx': continue
    p=ROOT/rec['file']; master=ROOT/'source'/(rec['name']+'_master_pcm24.wav')
    if not master.exists(): master.write_bytes(p.read_bytes())
    subprocess.run([FFMPEG,'-hide_banner','-nostdin','-y','-i',str(master),'-ar','48000','-ac','2','-c:a','pcm_s16le',str(p)],check=True,capture_output=True)
    data=p.read_bytes(); off=12; fmt=None
    while off+8<=len(data):
        tag=data[off:off+4]; size=struct.unpack_from('<I',data,off+4)[0]
        if tag==b'fmt ': fmt=struct.unpack_from('<HHIIHH',data,off+8); break
        off+=8+size+(size%2)
    assert fmt and fmt[0]==1 and fmt[1]==2 and fmt[2]==48000 and fmt[5]==16,fmt
    y,rate=sf.read(p,always_2d=True); peak=np.max(np.abs(y)); rms=np.sqrt(np.mean(y*y))
    proc=subprocess.run([FFMPEG,'-hide_banner','-nostdin','-i',str(p),'-af','loudnorm=I=-22:TP=-2:LRA=11:print_format=json','-f','null','-'],capture_output=True,text=True,encoding='utf-8',errors='replace',check=True)
    l=json.loads(re.findall(r'\{[^{}]+\}',proc.stderr,re.S)[-1])
    rec['technical'].update(sample_rate=rate,channels=y.shape[1],bits_per_sample=16,wav_format_tag=1,duration_seconds=round(len(y)/rate,6),sample_peak_dbfs=round(float(20*np.log10(peak)),3),rms_dbfs=round(float(20*np.log10(rms)),3),integrated_lufs=None if l['input_i']=='-inf' else float(l['input_i']),true_peak_dbtp=float(l['input_tp']),non_silent_sample_fraction_minus60db=round(float(np.mean(np.max(np.abs(y),axis=1)>.001)),6),finite=bool(np.isfinite(y).all()),clipped_samples=int(np.sum(np.abs(y)>=1)),boundary_jump_dbfs=round(float(20*np.log10(max(float(np.max(np.abs(y[0]-y[-1]))),1e-12))),3),sha256=hashlib.sha256(data).hexdigest())
    rec['processing']+=' Compatibility fix 2026-11-09: preserve previous stereo PCM24 master in source/'+master.name+'; encode final stereo 48kHz signed PCM16 WAV; inspect RIFF fmt chunk to require WAVE_FORMAT_PCM tag 1 and 16 bits. No regeneration or musical changes.'
    rec['preserved_pcm24_master']='source/'+master.name
    print(p.name,'fmt=',fmt,'peak=',rec['technical']['sample_peak_dbfs'],'sha256=',rec['technical']['sha256'])
manifest_path.write_text(json.dumps(m,ensure_ascii=False,indent=2),encoding='utf-8')
