"""Generate the authorized stronger combat batch with existing offline local models.

Run once; recorded jobs are resumed rather than regenerated. Menu is untouched.
"""
from pathlib import Path
import json, shutil, time
from gradio_client import Client

ROOT = Path(__file__).resolve().parents[1]
JOURNAL = ROOT / 'source' / 'combat05_generation.json'
JOBS = [
    ('battle', 'music', 64, 169951, 'TrackType: Music, instrumental original retro arcade action battle chiptune, urgent intense relentless driving 152 BPM four on the floor electronic kick and sharp short crunchy chip snare, tightly syncopated triangle and distorted pulse bass riff, dangerous dark minor sixteenth note arpeggios, two square pulse channels with short memorable aggressive answering motifs, high energy game action and escalating tension, punchy controlled low end, clean midrange, restrained high frequencies, consistent propulsive drum groove throughout, repeating eight bar structure, seamless looping background with space for impact sound effects, no vocals, no speech, no acoustic instruments, no orchestra, no ambient intro, no breakdown, no fade out, no white noise wash'),
    ('charge', 'sfx', 2, 169952, 'TrackType: SFX, single retro arcade heavy hammer power windup, short accelerating dark pulse wave pitch rise over pulsing low triangle bass, tight ratchet clicks increasing tension and one tiny digital fizz, strong focused compact charging sound, clean dry isolated vintage game chip effect, no music, no voice, no long noise'),
    ('impact', 'sfx', 2, 169953, 'TrackType: SFX, single extremely punchy retro arcade heavy hammer hit, immediate deep low frequency triangle pitch drop thump and hard short crunchy digital crack together, weighty low bass body decays rapidly, tiny plastic clack at attack, satisfying strong impact with clear attack and short tail, rounded controlled treble, dry isolated game effect, no music, no voice, no ringing, no long distortion or noise'),
    ('flip', 'sfx', 2, 169954, 'TrackType: SFX, single retro arcade toy card foil packet bursting open, brief crisp layered plastic paper tear and digital crunchy crack followed by tiny descending square pulse flick, tight ripping transient with a short clean dry tail, satisfying physical break sound, isolated game effect, no music, no voice, no long noisy wash, no explosion'),
    ('collect', 'sfx', 2, 169955, 'TrackType: SFX, single retro arcade gold coin reward pickup, three very fast crisp ascending bright square pulse chimes with tiny glassy coin clink and warm triangle harmony, compact sparkling satisfying reward with short clean decay, well separated clear high notes without piercing hiss, dry isolated vintage console game effect, no voice, no background music'),
]

def main():
    archive = ROOT / 'source' / 'history' / '2026-11-09-chiptune-before-combat05'
    if not archive.exists():
        archive.mkdir(parents=True)
        for folder in ('music', 'sfx'):
            shutil.copytree(ROOT / folder, archive / folder)
        for name in ('manifest.json', 'README.md'):
            shutil.copy2(ROOT / name, archive / name)
    records = json.loads(JOURNAL.read_text(encoding='utf-8')) if JOURNAL.exists() else []
    client = Client('http://127.0.0.1:7860')
    for name, kind, duration, seed, prompt in JOBS:
        if any(r['name'] == name for r in records):
            continue
        print('GENERATING ' + name, flush=True)
        start = time.time()
        path, message = client.predict(prompt=prompt, duration=duration, steps=24, seed=seed, api_name='/generate_' + kind)
        dest = ROOT / 'source' / ('combat05_' + name + '_raw.wav')
        shutil.copy2(path, dest)
        record = dict(name=name, kind=kind, model='stabilityai/stable-audio-3-small-' + kind, prompt=prompt, duration_requested=duration, steps=24, cfg_scale=1.0, seed=seed, source=str(dest), elapsed_seconds=round(time.time() - start, 2), generated_at=time.strftime('%Y-%m-%dT%H:%M:%S%z'), backend_message=message)
        records.append(record)
        JOURNAL.write_text(json.dumps(records, ensure_ascii=False, indent=2), encoding='utf-8')
        print('DONE ' + name + ' ' + str(record['elapsed_seconds']) + 's', flush=True)

if __name__ == '__main__':
    main()
