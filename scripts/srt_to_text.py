import re, sys

def srt_to_text(path):
    text = open(path, encoding='utf-8').read()
    blocks = re.split(r'\n\n+', text.strip())
    last_lines = []
    for b in blocks:
        lines = b.split('\n')
        # drop index line and timestamp line
        content = [l for l in lines[1:] if '-->' not in l]
        content = [l.strip() for l in content if l.strip()]
        if content:
            last_lines.append(content[-1])
    # dedupe consecutive duplicates
    out = []
    for l in last_lines:
        if not out or out[-1] != l:
            out.append(l)
    plain = ' '.join(out)
    plain = re.sub(r'\s+', ' ', plain)
    return plain

if __name__ == '__main__':
    print(srt_to_text(sys.argv[1]))
