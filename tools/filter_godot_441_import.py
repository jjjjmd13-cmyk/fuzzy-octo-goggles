"""Keep Godot 4.4.1's known GLTF thumbnail-only dummy renderer warning out of CI failures.
Only the exact two-line block during GLTF Saving is filtered; preserve a raw log.
Upstream: https://github.com/godotengine/godot/issues/108994 (fixed for 4.5 by #109116).
Asset parse, shader, script and any other texture error remain fatal.
"""
from pathlib import Path
import re,sys

def filter_log(text: str, version: str) -> tuple[str, int]:
    if not version.startswith('4.4.1.'):
        return text, 0
    lines=text.splitlines(keepends=True);result=[];count=0;i=0;gltf=False
    while i<len(lines):
        line=lines[i]
        if re.search(r'reimport: step \d+: .*\.gl(?:b|tf)\s*$',line):gltf=True
        elif re.search(r'reimport: step \d+: ',line):gltf=False
        if (gltf and line.strip()=='ERROR: Parameter "t" is null.' and i>0 and i+2<len(lines)
            and lines[i-1].strip().endswith('Saving...')
            and lines[i+1].strip()=='at: texture_2d_get (servers/rendering/dummy/storage/texture_storage.h:107)'
            and lines[i+2].strip()=='import: end'):
            i+=2;count+=1;continue
        result.append(line);i+=1
    return ''.join(result),count

if __name__=='__main__':
    path=Path(sys.argv[1]);text=path.read_text();cleaned,count=filter_log(text,sys.argv[2])
    if count:
        path.with_name('import.raw.log').write_text(text)
        path.write_text(cleaned)
        print(f'Godot 4.4.1 GLTF thumbnail diagnostic: {count} (raw log: {path.with_name("import.raw.log")})')
