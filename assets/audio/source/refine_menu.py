from pathlib import Path
import json,shutil
import generate_audio as g
root=Path(__file__).resolve().parent
journal=root/'generation.json'
records=json.loads(journal.read_text(encoding='utf-8'))
old=[r for r in records if r['name']=='menu']
(root/'menu_candidate1.json').write_text(json.dumps(old,indent=2),encoding='utf-8')
shutil.copy2(root/'menu_raw.wav',root/'menu_candidate1_raw.wav')
journal.write_text(json.dumps([r for r in records if r['name']!='menu'],indent=2),encoding='utf-8')
g.JOBS=[('menu','music',64,169103,'TrackType: Music, continuous instrumental 8-bit chiptune game menu loop, warm cheerful retro arcade, two soft pulse wave melody channels playing catchy interwoven musical phrases, constant flowing arpeggio accompaniment, rounded triangle bass walking through a repeating major key chord progression, gentle steady noise channel drums and hi hats, 108 BPM, full continuous arrangement from beginning to end, consistent rhythm and energy, no pauses, no breaks, no silence, mellow treble, authentic sound chip timbre, no vocals, no acoustic instruments, no piano, no guitar, original tune')]
g.main()
