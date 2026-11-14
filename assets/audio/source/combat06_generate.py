"""Small-SFX combat feedback batch. Resume journal; preserve combat05 masters."""
from pathlib import Path
import json, shutil, time
from gradio_client import Client

ROOT = Path(__file__).resolve().parents[1]
JOURNAL = ROOT/'source/combat06_generation.json'
JOBS = [
('hit', 169961, 'single compact hard plastic card packet hit, immediate dry woody crack with tightly layered retro arcade noise click and low mid knock, one non destructive strike, very short snappy transient and no tail, game sound effect, no voice no music no reverb'),
('impact', 169962, 'single powerful retro arcade heavy impact, immediate tight bass slam and sharp crunchy plastic snap striking together, strong low mid body with compressed punch, one heavy hit and rapidly decaying low triangle pitch drop, dry close upfront toy scale game sound effect, clean rounded treble, no music no voice no repeating hits no reverb'),
('flip', 169963, 'single card booster foil packet explosively ripping open, forceful sharp papery plastic crunch tear and snap, crunchy layered burst with tiny bright retro digital flick at end, clear physical destructive break with short dry decay, isolated game sound effect, no voice no music no reverb no long hiss'),
('collect', 169964, 'single retro arcade gold coin pickup, two quick clear ascending square pulse chimes with warm lower harmony and tiny coin clink, immediate bright readable rewarding attack and very short clean ending, compact game pickup effect, no music no voice no reverb no long shimmering tail'),
('harvest', 169965, 'short triumphant arcade jackpot accent, one forceful low drum smack layered with bright three note ascending major chord stinger, crunchy pulse chip brass and warm triangle bass, explosive rewarding multi reward harvest, bold full warm consonant final chord decays quickly, compact half second isolated game effect, no speech no vocals no background music no reverb'),
('rare', 169966, 'short legendary gold item discovery game stinger, clear bright rising three note major arpeggio then rich warm shimmering major chord, retro arcade square pulse and delicate bell layered with low triangle harmonic support, luxurious golden reveal, compact one second with crisp clean ending, no speech no voice no background music no long reverb'),
('ancient', 169967, 'short ancient mythic item discovery game stinger, majestic low resonant digital gong attack followed by brilliant wide ascending four note chip arpeggio resolving into rich suspended to major luminous chord, warm triangle bass foundation and sparkling high bell accent, distinct powerful rare treasure reveal, compact one second dry clean ending, no speech no voice no background music no long reverb'),
]

def main():
    archive=ROOT/'source/history/2026-11-09-combat05-before-combat06'
    if not archive.exists():
        archive.mkdir(parents=True)
        shutil.copytree(ROOT/'sfx',archive/'sfx')
        for f in ('manifest.json','README.md'):
            shutil.copy2(ROOT/f,archive/f)
    records=json.loads(JOURNAL.read_text(encoding='utf-8')) if JOURNAL.exists() else []
    client=Client('http://127.0.0.1:7860')
    for name,seed,prompt in JOBS:
        if any(r['name']==name for r in records): continue
        prompt='TrackType: SFX, '+prompt
        print('GENERATING '+name,flush=True); started=time.time()
        path,message=client.predict(prompt=prompt,duration=2,steps=32,seed=seed,api_name='/generate_sfx')
        dest=ROOT/'source'/f'combat06_{name}_raw.wav'; shutil.copy2(path,dest)
        records.append(dict(name=name,kind='sfx',model='stabilityai/stable-audio-3-small-sfx',prompt=prompt,duration_requested=2,steps=32,cfg_scale=1.0,seed=seed,source=str(dest),elapsed_seconds=round(time.time()-started,2),generated_at=time.strftime('%Y-%m-%dT%H:%M:%S%z'),backend_message=message))
        JOURNAL.write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8')
        print('DONE '+name,flush=True)

if __name__=='__main__': main()
