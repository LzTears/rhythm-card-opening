"""Archive the warm acoustic batch, then generate the requested retro arcade replacement."""
from pathlib import Path
import shutil
import generate_audio as g
ROOT=Path(__file__).resolve().parents[1]
archive=ROOT/'source'/'history'/'2026-11-09-warm-acoustic'
if not archive.exists():
    archive.mkdir(parents=True)
    for folder in ('music','sfx'):
        shutil.copytree(ROOT/folder,archive/folder)
    for name in ('manifest.json','README.md'):
        shutil.copy2(ROOT/name,archive/name)
    (archive/'source').mkdir()
    for p in (ROOT/'source').iterdir():
        if p.is_file() and p.name!='chiptune_generate.py': shutil.copy2(p,archive/'source'/p.name)
    (ROOT/'source'/'generation.json').write_text('[]',encoding='utf-8')
g.JOBS=[
 ('menu','music',64,169101,'TrackType: Music, original retro 8-bit chiptune arcade game menu music, cheerful warm nostalgic pixel toy world, melodic two square wave pulse channels trading a memorable tune and soft countermelody, flowing fast arpeggios, rounded triangle wave bass, tiny crunchy noise channel drum groove, 96 BPM, repeating four bar chord progression with playful variations, clear balanced mellow high frequencies, authentic vintage game console sound chip, instrumental, no vocals, no acoustic instruments, no piano, no guitar, no lo-fi recording noise, no cinematic orchestra, seamless looping underscore'),
 ('battle','music',64,169102,'TrackType: Music, original energetic retro 8-bit arcade chiptune battle music for a pixel toy card game, bouncy syncopated square pulse wave lead melody and answering countermelody, rhythmic sixteenth note arpeggios, warm triangle bassline, punchy crunchy noise channel snare and kick, 128 BPM, bright upbeat determined arcade groove, varied repeating harmonic progression, authentic vintage console sound chip with clear restrained treble, instrumental, no vocals, no acoustic instruments, no guitar, no piano, no lo-fi ambience, no orchestra, seamless loop with space for game sound effects'),
 ('ui_click','sfx',2,169111,'TrackType: SFX, single retro 8-bit arcade menu selection, two very quick soft square pulse notes stepping upward, tiny warm low triangle click layer, short crisp digital game console sound chip, dry isolated, no voice, no music'),
 ('charge','sfx',3,169112,'TrackType: SFX, retro 8-bit arcade power charging up, accelerating rising square wave arpeggio with soft triangle low pulse and tiny noise fizz, warm playful vintage game sound chip, layered evolving short windup ending cleanly, isolated, no voice, no background music'),
 ('swing','sfx',2,169113,'TrackType: SFX, single retro 8-bit arcade mallet swing, very short falling filtered digital noise sweep with a descending square pulse chirp, crunchy soft vintage console sound chip, dry isolated, no voice, no music'),
 ('impact','sfx',2,169114,'TrackType: SFX, single punchy retro 8-bit arcade toy hammer impact, fast deep triangle wave pitch drop, crunchy short noise burst and tiny square wave clack layered together, rounded satisfying powerful hit without piercing treble, vintage console sound chip, dry isolated, no voice, no background music'),
 ('flip','sfx',2,169115,'TrackType: SFX, single retro 8-bit arcade card flipping, quick up then down square pulse warble and short delicate noise tick, warm crisp playful vintage console sound chip, very short dry isolated effect, no voice, no music'),
 ('collect','sfx',2,169116,'TrackType: SFX, retro 8-bit arcade pickup reward, three fast ascending square pulse arpeggio notes with warm triangle harmony and tiny sparkling digital trill, satisfying cheerful vintage game sound chip, short clean dry decay, isolated, no voice, no background music'),
 ('result','sfx',4,169117,'TrackType: SFX, short retro 8-bit arcade victory fanfare, joyful square pulse melody harmonized with second pulse voice, rolling triangle bass and small noise drum flourish, six note ascending celebratory phrase and final warm major chord, vintage game console sound chip, crisp short clean ending, isolated, no voice, no background music'),
 ('upgrade','sfx',3,169118,'TrackType: SFX, short retro 8-bit arcade level up notification, cascading ascending square pulse arpeggio layered with triangle bass rise and tiny noise sparkle, warm bright final consonant digital chord, original vintage console sound chip, clean isolated short ending, no voice, no background music'),
]
g.main()
