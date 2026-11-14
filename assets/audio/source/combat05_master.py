"""Master the retained combat05 source recipe; keep the current menu unchanged."""
from pathlib import Path
import hashlib, json, struct
import numpy as np
import soundfile as sf
from master_audio import run, loudness

ROOT = Path(__file__).resolve().parents[1]
TRIMS = {'charge': (0, 1.32, -10), 'impact': (.205, .90, -5), 'flip': (.495, .735, -9), 'collect': (0, .70, -11)}

def stats(path):
    y, rate = sf.read(path, always_2d=True)
    loud = loudness(path)
    peak = float(np.max(np.abs(y)))
    assert np.isfinite(y).all() and 0 < peak < 1
    windows = [float(np.sqrt(np.mean(w*w))) for w in np.array_split(y, max(1, int(len(y)/rate)))]
    out = dict(sample_rate=rate, channels=y.shape[1], duration_seconds=round(len(y)/rate, 6), sample_peak_dbfs=round(20*np.log10(peak), 3), rms_dbfs=round(20*np.log10(np.sqrt(np.mean(y*y))), 3), integrated_lufs=None if loud['input_i']=='-inf' else float(loud['input_i']), true_peak_dbtp=float(loud['input_tp']), non_silent_sample_fraction_minus60db=round(float(np.mean(np.max(np.abs(y),axis=1)>.001)), 6), finite=True, clipped_samples=int(np.sum(np.abs(y)>=1)), boundary_jump_dbfs=round(20*np.log10(max(float(np.max(np.abs(y[0]-y[-1]))),1e-12)), 3), minimum_one_second_window_rms_dbfs=round(20*np.log10(max(min(windows),1e-12)),3), sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    if path.suffix == '.wav':
        data=path.read_bytes(); off=12; fmt=None
        while off+8<=len(data):
            tag=data[off:off+4]; size=struct.unpack_from('<I',data,off+4)[0]
            if tag==b'fmt ': fmt=struct.unpack_from('<HHIIHH',data,off+8); break
            off+=8+size+(size%2)
        assert fmt and fmt[0]==1 and fmt[1]==2 and fmt[2]==48000 and fmt[5]==16
        out.update(bits_per_sample=16, wav_format_tag=1)
    return out

def main():
    manifest=json.loads((ROOT/'manifest.json').read_text(encoding='utf-8'))
    records=json.loads((ROOT/'source/combat05_generation.json').read_text(encoding='utf-8'))
    menu_hash=hashlib.sha256((ROOT/'music/menu.ogg').read_bytes()).hexdigest()
    for rec in records:
        name=rec['name']; x,sr=sf.read(rec['source'],always_2d=True)
        x-=x.mean(axis=0,keepdims=True)
        if name=='battle':
            # Confirmed by 32-beat low-band envelope autocorrelation: 152.003 BPM.
            # 36 bars maintain musical phase; end blends to the matching preroll.
            start=round(4*60/152*sr); count=round(144*60/152*sr)
            n=round(.025*sr); preroll=x[start-n:start].copy()
            x=x[start:start+count].copy(); t=np.linspace(0,1,n)[:,None]
            x[-n:]=x[-n:]*(1-t)+preroll*t
            processing='36 bars / 144 beats at 152 BPM from bar 2 (1.578947s); 25ms phase-matched preroll splice; 8ms edge ramps; DC removal; 8kHz lowpass; two-pass -20 LUFS / -2dBTP; 48kHz Vorbis q6. No speed change.'
        else:
            start,end,peakdb=TRIMS[name]; x=x[round(start*sr):round(end*sr)].copy()
            x*=10**(peakdb/20)/np.max(np.abs(x))
            n=min(round(.025*sr),len(x)//4); x[-n:]*=np.linspace(1,0,n)[:,None]
            processing=f'New model output selected {start}-{end}s; isolate primary attack (omit generated secondary/leading hits); DC removal; 2ms entrance/25ms exit; peak target {peakdb}dBFS; 6.5kHz lowpass; 48kHz stereo classic PCM16. No speed change.'
        n=round((.008 if name=='battle' else .002)*sr); x[:n]*=np.linspace(0,1,n)[:,None]
        if name=='battle': x[-n:]*=np.linspace(1,0,n)[:,None]
        edited=ROOT/'source'/f'combat05_{name}_edited.wav'; sf.write(edited,x,sr,subtype='PCM_24')
        final=ROOT/('music' if name=='battle' else 'sfx')/(name+('.ogg' if name=='battle' else '.wav'))
        if name=='battle':
            filtered=ROOT/'source/combat05_battle_lowpass.wav'
            run(['-y','-i',str(edited),'-af','lowpass=f=8000','-c:a','pcm_s24le',str(filtered)])
            l=loudness(filtered)
            filt=f"loudnorm=I=-20:TP=-2:LRA=11:measured_I={l['input_i']}:measured_TP={l['input_tp']}:measured_LRA={l['input_lra']}:measured_thresh={l['input_thresh']}:offset={l['target_offset']}:linear=true"
            run(['-y','-i',str(filtered),'-af',filt,'-ar','48000','-c:a','libvorbis','-q:a','6',str(final)])
        else:
            run(['-y','-i',str(edited),'-af','lowpass=f=6500','-ar','48000','-ac','2','-c:a','pcm_s16le',str(final)])
        out=dict(rec, file=str(final.relative_to(ROOT)).replace('\\','/'), processing=processing, technical=stats(final), loop=name=='battle', subjective_listening='Agent cannot directly audition audio in this runtime; objective signal checks passed; subjective style/vocals/click perception unverified.')
        if name=='battle': out.update(target_bpm=152, measured_low_band_autocorrelation_bpm=152.003, loop_bars=36)
        manifest['assets']=[out if r['name']==name else r for r in manifest['assets']]
        print(name,json.dumps(out['technical']),flush=True)
    assert hashlib.sha256((ROOT/'music/menu.ogg').read_bytes()).hexdigest()==menu_hash
    for entry in manifest['assets']:
        entry['technical'] = stats(ROOT / entry['file'])
    manifest['style']='Retro pixel arcade / chip-electronic combat05: new 152 BPM driving battle and focused heavy impact, packet tear, coin reward; independent menu retained.'
    (ROOT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    report=dict(recipe='combat05', status='passed', processed=[r['name'] for r in records], menu_unchanged=True, menu_sha256=menu_hash, subjective_audition=False, limitation='Signal checks only; not a subjective listening approval.', assets=[dict(name=r['name'],**r['technical']) for r in manifest['assets']])
    print(json.dumps(report,ensure_ascii=False),flush=True)

if __name__=='__main__': main()
