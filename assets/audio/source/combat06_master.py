"""Reproducible combat06 mastering and media checks; no BGM edits."""
from pathlib import Path
import json, hashlib
import numpy as np
import soundfile as sf
from master_audio import run
from combat05_master import stats

ROOT=Path(__file__).resolve().parents[1]
# Source selections isolate the primary physical transient or compact harmonic phrase.
TRIMS={'hit':(0,.12,-9,1.2),'impact':(0,.36,-5,1.7),'flip':(.743,.956,-7,1.5),'collect':(0,.45,-10,1.0),'harvest':(0,.65,-6,1.2),'rare':(0,1.1,-8,1.0),'ancient':(0,1.3,-7,1.0)}

def main():
    records=json.loads((ROOT/'source/combat06_generation.json').read_text(encoding='utf-8'))
    manifest=json.loads((ROOT/'manifest.json').read_text(encoding='utf-8'))
    for rec in records:
        name=rec['name']; start,end,peakdb,drive=TRIMS[name]
        x,sr=sf.read(rec['source'],always_2d=True)
        x=x[round(start*sr):round(end*sr)].copy(); x-=x.mean(axis=0,keepdims=True)
        x/=max(np.max(abs(x)),1e-12)
        x=np.tanh(x*drive)/np.tanh(drive)
        # Physical transients retain a 1ms attack; longer cues retain 2ms.
        n=round((.001 if name in ('hit','impact','flip') else .002)*sr)
        x[:n]*=np.linspace(0,1,n)[:,None]
        n=round((.015 if name in ('hit','impact','flip') else .035)*sr)
        x[-n:]*=np.linspace(1,0,n)[:,None]
        edit=ROOT/'source'/f'combat06_{name}_edited.wav'; sf.write(edit,x,sr,subtype='PCM_24')
        filtered=ROOT/'source'/f'combat06_{name}_filtered.wav'
        run(['-y','-i',str(edit),'-af','highpass=f=40,lowpass=f=7600','-ar','48000','-ac','2','-c:a','pcm_s24le',str(filtered)])
        y,sr=sf.read(filtered,always_2d=True)
        y*=10**(peakdb/20)/np.max(abs(y))
        # Zero final sample suppresses edge jumps after the filter/resampler.
        y[0]=0; y[-1]=0
        final=ROOT/'sfx'/f'{name}.wav'; sf.write(final,y,sr,subtype='PCM_16')
        technical=stats(final)
        processing=f'New Small-SFX source selection {start}-{end}s; DC removal; normalized tanh transient density drive {drive}; 1-2ms onset/15-35ms tail fades; 40Hz highpass/7.6kHz lowpass; post-filter peak {peakdb}dBFS; zero endpoints; 48kHz stereo classic PCM16. No pitch or speed change.'
        out=dict(rec,source_sha256=hashlib.sha256(Path(rec['source']).read_bytes()).hexdigest(),file=f'sfx/{name}.wav',processing=processing,technical=technical,loop=False,subjective_listening='Not directly auditioned: runtime has no audio perception path; prompt/timbre/chord quality awaits user listening.')
        manifest['assets']=[r for r in manifest['assets'] if r['name']!=name]+[out]
        print(name,json.dumps(technical),flush=True)
    checks=0; measured=[]
    for rec in manifest['assets']:
        m=stats(ROOT/rec['file']); checks+=1
        assert m['sha256']==rec['technical']['sha256']; checks+=1
        assert m['finite'] and m['clipped_samples']==0 and m['sample_peak_dbfs']<0; checks+=1
        assert m['rms_dbfs']>-55; checks+=1
        if rec['kind']=='sfx':
            assert m['wav_format_tag']==1 and m['bits_per_sample']==16 and m['sample_rate']==48000; checks+=1
        if rec['name'] in TRIMS:
            assert abs(m['duration_seconds']-(TRIMS[rec['name']][1]-TRIMS[rec['name']][0]))<.001; checks+=1
        measured.append(dict(name=rec['name'],**m))
    report=dict(recipe='combat06',status='passed',checks=checks,processed=[r['name'] for r in records],preserved=sorted(r['name'] for r in manifest['assets'] if r['name'] not in TRIMS),subjective_audition=False,limitation='Current signal/provenance checks only; no direct subjective listening, timbre or chord approval.',assets=measured)
    manifest['style']='Retro arcade combat06 feedback: new compact impact/crack/packet burst/pickup and distinct harvest/legendary/ancient harmonic accents. Combat05 152BPM battle unchanged.'
    (ROOT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(report,ensure_ascii=False),flush=True)

if __name__=='__main__': main()
