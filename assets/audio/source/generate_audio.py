"""Generate original evaluation assets through the existing local Small Audio API."""
from pathlib import Path
import json, shutil, time
from gradio_client import Client

ROOT = Path(__file__).resolve().parents[1]
JOBS = [
 ('menu','music',64,160911,'TrackType: Music, instrumental cozy nostalgic tabletop toy game menu loop, warm mellow acoustic nylon guitar, soft felt piano, gentle marimba, brushed shaker, rounded upright bass, relaxed playful melody, sunny wooden school desk afternoon, intimate dry clean studio sound, 90 BPM, simple steady repeating four bar harmony, seamless background underscore, no vocals, no speech, no dramatic ending'),
 ('battle','music',64,160912,'TrackType: Music, instrumental playful nostalgic tabletop toy card battle game background loop, warm wooden marimba and muted pizzicato strings, plucky acoustic guitar, soft bouncy upright bass, small hand percussion, woodblocks and light shaker, buoyant steady pulse, catchy restrained melody, energetic cheerful concentration, 112 BPM, repeating four bar harmony, clean dry mix with space for game sound effects, no vocals, no speech, no dramatic ending'),
 ('ui_click','sfx',2,160921,'TrackType: SFX, a single small plastic toy button gently clicked, soft satisfying wooden tick and tiny spring tap, warm rounded short transient, isolated close dry recording, silence after, no music, no voice'),
 ('charge','sfx',3,160922,'TrackType: SFX, a small wooden toy mallet being pulled back on a soft spring, short rising wooden ratchet tension and soft airy swish, cute tactile mechanical windup, dry isolated game sound, no music, no voice'),
 ('swing','sfx',2,160923,'TrackType: SFX, a single small toy mallet quick swing through air, short soft airy whoosh ending crisply, playful restrained close dry sound, no impact, no music, no voice'),
 ('impact','sfx',2,160924,'TrackType: SFX, single satisfying toy wooden mallet strikes a thin plastic disk on a wooden desk, firm warm low wooden knock with sharp light plastic clack, tactile punchy small tabletop impact, short dry resonance, no music, no voice'),
 ('flip','sfx',2,160925,'TrackType: SFX, a single thin plastic toy card flipping over and landing lightly on a wooden table, quick papery plastic flutter then tiny crisp tap, delicate short close dry foley, no music, no voice'),
 ('collect','sfx',2,160926,'TrackType: SFX, a short cheerful toy game pickup notification, three delicate ascending rounded marimba and glass bell notes, warm small sparkling sound, very brief clean decay, no background music, no voice'),
 ('result','sfx',4,160927,'TrackType: SFX, short cheerful toy game victory reward stinger, warm marimba and pizzicato three note ascending flourish, tiny wooden percussion and soft final bell, friendly modest accomplishment, clean brief tail, no voice, no background music'),
 ('upgrade','sfx',3,160928,'TrackType: SFX, short magical toy card upgrade sound, delicate wooden chimes rising into a warm soft shimmering bell, satisfying bright miniature flourish, isolated clean dry game notification, no voice, no background music'),
]

def main():
    c=Client('http://127.0.0.1:7860')
    records=[]
    journal=ROOT/'source'/'generation.json'
    if journal.exists(): records=json.loads(journal.read_text(encoding='utf-8'))
    for name,kind,duration,seed,prompt in JOBS:
        if any(r['name']==name for r in records): continue
        print(f'GENERATING {name} {kind} {duration}s',flush=True)
        start=time.time()
        path,message=c.predict(prompt=prompt,duration=duration,steps=16,seed=seed,api_name='/generate_'+kind)
        dest=ROOT/'source'/(name+'_raw.wav')
        shutil.copy2(path,dest)
        record=dict(name=name,kind=kind,model='stabilityai/stable-audio-3-small-'+kind,prompt=prompt,duration_requested=duration,steps=16,cfg_scale=1.0,seed=seed,source=str(dest),elapsed_seconds=round(time.time()-start,2),generated_at=time.strftime('%Y-%m-%dT%H:%M:%S%z'))
        records.append(record)
        journal.write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8')
        print('DONE '+name+' '+str(record['elapsed_seconds'])+'s',flush=True)

if __name__=='__main__': main()
