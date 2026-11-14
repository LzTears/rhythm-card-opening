"""Non-generative editing, mastering and objective checks of local model outputs."""
from pathlib import Path
import json, subprocess, hashlib, re, struct
import numpy as np
import soundfile as sf

ROOT=Path(__file__).resolve().parents[1]
FFMPEG='D:/AI/MuseTalk/tools/ffmpeg.exe'
TRIMS={'ui_click':(0,.30,-11),'charge':(.02,1.5,-12),'swing':(0,.42,-12),'impact':(0,.45,-7),'flip':(0,.64,-12),'collect':(0,.95,-13),'result':(0,3.65,-11),'upgrade':(.01,2.15,-12)}

def run(args):
    p=subprocess.run([FFMPEG,'-hide_banner','-nostdin',*args],capture_output=True,text=True,encoding='utf-8',errors='replace')
    if p.returncode: raise RuntimeError(p.stderr[-3000:])
    return p.stderr

def loudness(path):
    report=run(['-i',str(path),'-af','loudnorm=I=-22:TP=-2:LRA=11:print_format=json','-f','null','-'])
    return json.loads(re.findall(r'\{[^{}]+\}',report,re.S)[-1])

def main():
    records=json.loads((ROOT/'source'/'generation.json').read_text(encoding='utf-8'))
    manifest={'project':'圆卡旋风','style':'Retro pixel arcade / 8-bit chiptune requested 2026-11-09; new generation replaces warm acoustic batch archived under source/history/2026-11-09-warm-acoustic','purpose':'Original local-generated evaluation asset batch; subjective listening acceptance pending','generation_backend':'Existing localhost:7860 Gradio API; offline cached Small-Music / Small-SFX, no paid API','license_status':'Model terms were previously accepted on this machine per local installation notes; current commercial rights and training provenance have not been independently verified. No commercial license claim.','technical_verification':'All final assets decoded, finite/non-silent checked; WAV RIFF fmt inspected for tag1/16bit; loudness and sample boundaries measured. Technical checks do not establish subjective audio quality.','assets':[]}
    for rec in records:
        name=rec['name']; x,sr=sf.read(rec['source'],dtype='float64',always_2d=True)
        assert np.isfinite(x).all() and np.max(np.abs(x))>1e-5
        x-=x.mean(axis=0,keepdims=True)
        if rec['kind']=='music':
            # Exclude the generated opening/end; overlap the tail into the head.
            x=x[int(2*sr):int(62*sr)]
            n=int(2*sr); t=np.linspace(0,1,n)[:,None]
            mixed=x[-n:]*(1-t)+x[:n]*t
            x=np.concatenate([x[n:-n],mixed])
            # Pulse timbres can still cross the wrap on a steep edge. An 8ms
            # boundary ramp suppresses that edge without a perceptible pause.
            edge=int(.008*sr)
            x[:edge]*=np.linspace(0,1,edge)[:,None]
            x[-edge:]*=np.linspace(1,0,edge)[:,None]
            processing='Keep generated 2–62s; 2s linear wrap overlap, resulting 58s loop; 8ms endpoint ramps suppress pulse-wave wrap clicks; DC removal; 7.5kHz lowpass; two-pass -22 LUFS/-2dBTP music normalization; Vorbis q6.'
        else:
            start,end,peakdb=TRIMS[name]
            x=x[int(start*sr):int(end*sr)]
            fadein=min(int(.002*sr),len(x)//4); fadeout=min(int(.04*sr),len(x)//4)
            x[:fadein]*=np.linspace(0,1,fadein)[:,None]
            x[-fadeout:]*=np.linspace(1,0,fadeout)[:,None]
            x*=10**(peakdb/20)/np.max(np.abs(x))
            processing=f'Select source {start}–{end}s, DC removal, 2ms entrance/40ms exit fades, sample peak normalize {peakdb}dBFS, 6kHz lowpass, resample to 48kHz classic PCM16 WAV format tag1.'
        edit=ROOT/'source'/(name+'_edited.wav'); sf.write(edit,x,sr,subtype='PCM_24')
        final=ROOT/('music' if rec['kind']=='music' else 'sfx')/(name+('.ogg' if rec['kind']=='music' else '.wav'))
        if rec['kind']=='music':
            filtered=ROOT/'source'/(name+'_lowpass.wav')
            run(['-y','-i',str(edit),'-af','lowpass=f=7500','-c:a','pcm_s24le',str(filtered)])
            l=loudness(filtered)
            filt=f"loudnorm=I=-22:TP=-2:LRA=11:measured_I={l['input_i']}:measured_TP={l['input_tp']}:measured_LRA={l['input_lra']}:measured_thresh={l['input_thresh']}:offset={l['target_offset']}:linear=true"
            run(['-y','-i',str(filtered),'-af',filt,'-ar','48000','-c:a','libvorbis','-q:a','6',str(final)])
        else:
            run(['-y','-i',str(edit),'-af','lowpass=f=6000','-ar','48000','-ac','2','-c:a','pcm_s16le',str(final)])
            data=final.read_bytes(); off=12; fmt=None
            while off+8<=len(data):
                tag=data[off:off+4]; size=struct.unpack_from('<I',data,off+4)[0]
                if tag==b'fmt ': fmt=struct.unpack_from('<HHIIHH',data,off+8); break
                off+=8+size+(size%2)
            assert fmt and fmt[0]==1 and fmt[1]==2 and fmt[2]==48000 and fmt[5]==16,fmt
        y,rate=sf.read(final,always_2d=True); loud=loudness(final)
        peak=float(np.max(np.abs(y))); rms=float(np.sqrt(np.mean(y*y)))
        assert np.isfinite(y).all() and peak<1 and rms>1e-5
        stats=dict(sample_rate=rate,channels=y.shape[1],duration_seconds=round(len(y)/rate,6),sample_peak_dbfs=round(20*np.log10(peak),3),rms_dbfs=round(20*np.log10(rms),3),integrated_lufs=None if loud['input_i']=='-inf' else float(loud['input_i']),true_peak_dbtp=float(loud['input_tp']),non_silent_sample_fraction_minus60db=round(float(np.mean(np.max(np.abs(y),axis=1)>.001)),6),finite=True,clipped_samples=int(np.sum(np.abs(y)>=1)),boundary_jump_dbfs=round(20*np.log10(max(float(np.max(np.abs(y[0]-y[-1]))),1e-12)),3),sha256=hashlib.sha256(final.read_bytes()).hexdigest())
        if rec['kind']=='sfx': stats.update(bits_per_sample=16,wav_format_tag=1)
        out=dict(rec); out.update(file=str(final.relative_to(ROOT)).replace('\\','/'),processing=processing,technical=stats,loop=rec['kind']=='music',subjective_listening='Not auditioned by agent; user evaluation required')
        manifest['assets'].append(out)
        print(name,json.dumps(stats),flush=True)
    (ROOT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')

if __name__=='__main__': main()
